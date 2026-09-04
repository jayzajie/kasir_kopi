import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/cart_item.dart';
import '../models/accounting.dart';
import '../models/product.dart';

const _initialInventory = [
  ['Biji Kopi', 4000.0, 'gram', 2000.0],
  ['Susu Full Cream', 8000.0, 'ml', 2000.0],
  ['Sirup Vanilla', 2000.0, 'ml', 500.0],
  ['Gula Aren', 1000.0, 'gram', 300.0],
  ['Cup 12oz', 15.0, 'pcs', 50.0],
  ['Tutup Cup', 10.0, 'pcs', 30.0],
];

class AppDatabase {
  late final Database db;

  Future<void> initialize({bool inMemory = false}) async {
    final desktop =
        inMemory ||
        (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.linux));
    if (desktop) sqfliteFfiInit();
    final factory = inMemory
        ? databaseFactoryFfiNoIsolate
        : desktop
        ? databaseFactoryFfi
        : sqflite.databaseFactory;
    final path = inMemory
        ? inMemoryDatabasePath
        : p.join(await factory.getDatabasesPath(), 'kopi_kita.db');
    db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN cost INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE sale_items ADD COLUMN unit_cost INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      // Versi sebelumnya hanya berisi produk contoh bawaan.
      await database.update('sale_items', {'product_id': null});
      await database.delete('products');
    }
    if (oldVersion < 4) {
      await database.execute(
        "ALTER TABLE products ADD COLUMN addon_name TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        'ALTER TABLE products ADD COLUMN addon_price INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 5) {
      await database.execute(
        "ALTER TABLE products ADD COLUMN ice_option TEXT NOT NULL DEFAULT 'Normal Ice'",
      );
      await database.execute(
        "ALTER TABLE products ADD COLUMN sugar_option TEXT NOT NULL DEFAULT 'Normal Sugar'",
      );
      await database.execute('ALTER TABLE products ADD COLUMN image BLOB');
      await database.execute(
        "ALTER TABLE products ADD COLUMN addons_json TEXT NOT NULL DEFAULT '[]'",
      );
      for (final row in await database.query('products')) {
        final name = row['addon_name'] as String;
        if (name.isNotEmpty) {
          await database.update(
            'products',
            {
              'addons_json': jsonEncode([
                {'name': name, 'price': row['addon_price']},
              ]),
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }
    if (oldVersion < 6) {
      await database.execute(
        'ALTER TABLE inventory ADD COLUMN purchase_price INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE inventory ADD COLUMN package_quantity REAL NOT NULL DEFAULT 1',
      );
      await _createAccountingTables(database);
    }
    if (oldVersion < 7) {
      await database.execute('''CREATE TABLE stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');
      await database.rawUpdate(
        '''UPDATE recipes SET quantity = quantity * 1000
        WHERE ingredient_name IN (SELECT name FROM inventory WHERE unit IN ('kg', 'L'))''',
      );
      await database.rawUpdate('''UPDATE inventory SET
        quantity = quantity * 1000,
        minimum = minimum * 1000,
        package_quantity = package_quantity * 1000,
        unit = CASE unit WHEN 'kg' THEN 'gram' WHEN 'L' THEN 'ml' ELSE unit END
        WHERE unit IN ('kg', 'L')''');
    }
  }

  Future<void> close() => db.close();

  Future<void> _create(Database database, int version) async {
    final batch = database.batch()
      ..execute('''CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL CHECK(price >= 0),
        cost INTEGER NOT NULL DEFAULT 0 CHECK(cost >= 0),
        category TEXT NOT NULL,
        available INTEGER NOT NULL DEFAULT 1,
        addon_name TEXT NOT NULL DEFAULT '',
        addon_price INTEGER NOT NULL DEFAULT 0 CHECK(addon_price >= 0),
        ice_option TEXT NOT NULL DEFAULT 'Normal Ice',
        sugar_option TEXT NOT NULL DEFAULT 'Normal Sugar',
        image BLOB,
        addons_json TEXT NOT NULL DEFAULT '[]'
      )''')
      ..execute('''CREATE TABLE inventory(
        name TEXT PRIMARY KEY,
        quantity REAL NOT NULL CHECK(quantity >= 0),
        unit TEXT NOT NULL,
        minimum REAL NOT NULL DEFAULT 0,
        purchase_price INTEGER NOT NULL DEFAULT 0 CHECK(purchase_price >= 0),
        package_quantity REAL NOT NULL DEFAULT 1 CHECK(package_quantity > 0)
      )''')
      ..execute('''CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_number TEXT NOT NULL UNIQUE,
        customer_name TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        total INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )''')
      ..execute('''CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price INTEGER NOT NULL,
        unit_cost INTEGER NOT NULL DEFAULT 0,
        extra INTEGER NOT NULL DEFAULT 0,
        options TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT ''
      )''')
      ..execute('''CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''')
      ..execute('''CREATE TABLE recipes(
        product_id INTEGER NOT NULL,
        ingredient_name TEXT NOT NULL,
        quantity REAL NOT NULL CHECK(quantity > 0),
        PRIMARY KEY(product_id, ingredient_name)
      )''')
      ..execute('''CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK(amount > 0),
        created_at TEXT NOT NULL
      )''')
      ..execute('''CREATE TABLE stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ingredient_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )''');

    for (final row in _initialInventory) {
      batch.insert('inventory', {
        'name': row[0],
        'quantity': row[1],
        'unit': row[2],
        'minimum': row[3],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _createAccountingTables(Database database) async {
    await database.execute('''CREATE TABLE recipes(
      product_id INTEGER NOT NULL,
      ingredient_name TEXT NOT NULL,
      quantity REAL NOT NULL CHECK(quantity > 0),
      PRIMARY KEY(product_id, ingredient_name)
    )''');
    await database.execute('''CREATE TABLE expenses(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      category TEXT NOT NULL,
      description TEXT NOT NULL,
      amount INTEGER NOT NULL CHECK(amount > 0),
      created_at TEXT NOT NULL
    )''');
  }

  Future<List<Product>> products() async => (await db.query(
    'products',
    orderBy: 'name',
  )).map(Product.fromMap).toList();

  Future<int> addProduct(Product product) => db.insert('products', {
    'name': product.name,
    'price': product.price,
    'cost': product.cost,
    'category': product.category,
    'available': product.available ? 1 : 0,
    'ice_option': product.iceOption,
    'sugar_option': product.sugarOption,
    'image': product.image,
    'addons_json': product.addonsJson,
  });

  Future<void> updateProduct(Product product) => db.update(
    'products',
    {
      'name': product.name,
      'price': product.price,
      'cost': product.cost,
      'category': product.category,
      'available': product.available ? 1 : 0,
      'ice_option': product.iceOption,
      'sugar_option': product.sugarOption,
      'image': product.image,
      'addons_json': product.addonsJson,
    },
    where: 'id = ?',
    whereArgs: [product.id],
  );

  Future<void> deleteProduct(int id) async {
    await db.update(
      'sale_items',
      {'product_id': null},
      where: 'product_id = ?',
      whereArgs: [id],
    );
    await db.delete('recipes', where: 'product_id = ?', whereArgs: [id]);
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reset() => db.transaction((txn) async {
    await txn.delete('sale_items');
    await txn.delete('sales');
    await txn.delete('products');
    await txn.delete('recipes');
    await txn.delete('expenses');
    await txn.delete('stock_movements');
    await txn.delete('inventory');
    await txn.delete('settings');
    await txn.delete('sqlite_sequence');
    for (final row in _initialInventory) {
      await txn.insert('inventory', {
        'name': row[0],
        'quantity': row[1],
        'unit': row[2],
        'minimum': row[3],
      });
    }
  });

  Future<Map<String, double>> inventory() async => {
    for (final row in await db.query('inventory', orderBy: 'name'))
      row['name'] as String: (row['quantity'] as num).toDouble(),
  };

  Future<List<IngredientCost>> ingredients() async => (await db.query(
    'inventory',
    orderBy: 'name',
  )).map(IngredientCost.fromMap).toList();

  Future<void> saveIngredient(IngredientCost ingredient) async {
    final values = {
      'unit': ingredient.unit,
      'minimum': ingredient.minimum,
      'purchase_price': ingredient.purchasePrice,
      'package_quantity': ingredient.packageQuantity,
    };
    final updated = await db.update(
      'inventory',
      values,
      where: 'name = ?',
      whereArgs: [ingredient.name],
    );
    if (updated == 0) {
      await db.insert('inventory', {
        'name': ingredient.name,
        'quantity': 0.0,
        'minimum': ingredient.minimum,
        ...values,
      });
    }
    await _recalculateRecipeCosts(db, ingredient.name);
  }

  Future<List<RecipeLine>> recipe(int productId) async => (await db.rawQuery(
    '''
    SELECT r.ingredient_name, r.quantity, i.unit,
      ROUND(r.quantity * i.purchase_price / i.package_quantity) cost
    FROM recipes r JOIN inventory i ON i.name = r.ingredient_name
    WHERE r.product_id = ? ORDER BY r.ingredient_name
    ''',
    [productId],
  )).map(RecipeLine.fromMap).toList();

  Future<int> saveRecipe(int productId, Map<String, double> quantities) =>
      db.transaction((txn) async {
        await txn.delete(
          'recipes',
          where: 'product_id = ?',
          whereArgs: [productId],
        );
        for (final entry in quantities.entries.where(
          (entry) => entry.value > 0,
        )) {
          await txn.insert('recipes', {
            'product_id': productId,
            'ingredient_name': entry.key,
            'quantity': entry.value,
          });
        }
        final rows = await txn.rawQuery(
          '''SELECT COALESCE(ROUND(SUM(r.quantity * i.purchase_price /
             i.package_quantity)), 0) cost
             FROM recipes r JOIN inventory i ON i.name = r.ingredient_name
             WHERE r.product_id = ?''',
          [productId],
        );
        final cost = (rows.first['cost'] as num).round();
        await txn.update(
          'products',
          {'cost': cost},
          where: 'id = ?',
          whereArgs: [productId],
        );
        return cost;
      });

  Future<List<ExpenseRecord>> expenses() async => (await db.query(
    'expenses',
    orderBy: 'created_at DESC',
  )).map(ExpenseRecord.fromMap).toList();

  Future<void> addExpense(String category, String description, int amount) =>
      db.insert('expenses', {
        'category': category,
        'description': description,
        'amount': amount,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<void> deleteExpense(int id) =>
      db.delete('expenses', where: 'id = ?', whereArgs: [id]);

  Future<void> addPurchase({
    required String name,
    required double packages,
    required double packageQuantity,
    required int packagePrice,
  }) => db.transaction((txn) async {
    final amount = packages * packageQuantity;
    await txn.rawUpdate(
      '''UPDATE inventory SET quantity = quantity + ?,
         purchase_price = ?, package_quantity = ? WHERE name = ?''',
      [amount, packagePrice, packageQuantity, name],
    );
    await txn.insert('expenses', {
      'category': 'Bahan',
      'description': 'Pembelian $name',
      'amount': (packages * packagePrice).round(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await _recordMovement(txn, name, 'Pembelian', amount, 'Stok masuk');
    await _recalculateRecipeCosts(txn, name);
  });

  Future<void> _recalculateRecipeCosts(
    DatabaseExecutor executor,
    String ingredientName,
  ) => executor.rawUpdate(
    '''UPDATE products SET cost = (
      SELECT COALESCE(ROUND(SUM(r.quantity * i.purchase_price / i.package_quantity)), 0)
      FROM recipes r JOIN inventory i ON i.name = r.ingredient_name
      WHERE r.product_id = products.id
    ) WHERE id IN (
      SELECT product_id FROM recipes WHERE ingredient_name = ?
    )''',
    [ingredientName],
  );

  Future<void> adjustStock({
    required String name,
    required double change,
    required String reason,
  }) => db.transaction((txn) async {
    await _changeStock(txn, name, change, 'Penyesuaian', reason);
  });

  Future<void> stocktake(String name, double actual) =>
      db.transaction((txn) async {
        final row = (await txn.query(
          'inventory',
          columns: ['quantity'],
          where: 'name = ?',
          whereArgs: [name],
        )).single;
        final current = (row['quantity'] as num).toDouble();
        await _changeStock(
          txn,
          name,
          actual - current,
          'Stok opname',
          'Stok fisik ${actual.toStringAsFixed(2)}',
        );
      });

  Future<List<StockMovement>> stockMovements(String name) async =>
      (await db.query(
        'stock_movements',
        where: 'ingredient_name = ?',
        whereArgs: [name],
        orderBy: 'created_at DESC',
        limit: 30,
      )).map(StockMovement.fromMap).toList();

  Future<List<SaleLine>> saleItems(int saleId) async => (await db.query(
    'sale_items',
    where: 'sale_id = ?',
    whereArgs: [saleId],
    orderBy: 'id',
  )).map(SaleLine.fromMap).toList();

  Future<void> setProductAvailability(int id, bool available) => db.update(
    'products',
    {'available': available ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> saveSale({
    required String transactionNumber,
    required String customerName,
    required String paymentMethod,
    required DateTime createdAt,
    required List<CartItem> items,
  }) async {
    await db.transaction((txn) async {
      final total = items.fold<int>(0, (sum, item) => sum + item.total);
      final saleId = await txn.insert('sales', {
        'transaction_number': transactionNumber,
        'customer_name': customerName,
        'payment_method': paymentMethod,
        'total': total,
        'created_at': createdAt.toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.qty,
          'unit_price': item.product.price,
          'unit_cost': item.product.cost,
          'extra': item.extra,
          'options': item.options,
          'note': item.note,
        });
        final recipe = await txn.query(
          'recipes',
          where: 'product_id = ?',
          whereArgs: [item.product.id],
        );
        for (final line in recipe) {
          await _changeStock(
            txn,
            line['ingredient_name'] as String,
            -(line['quantity'] as num).toDouble() * item.qty,
            'Penjualan',
            transactionNumber,
          );
        }
      }
    });
  }

  Future<void> _changeStock(
    Transaction txn,
    String name,
    double requested,
    String type,
    String reason,
  ) async {
    final row = (await txn.query(
      'inventory',
      columns: ['quantity'],
      where: 'name = ?',
      whereArgs: [name],
    )).single;
    final current = (row['quantity'] as num).toDouble();
    final change = requested < -current ? -current : requested;
    if (change == 0) return;
    await txn.rawUpdate(
      'UPDATE inventory SET quantity = quantity + ? WHERE name = ?',
      [change, name],
    );
    await _recordMovement(txn, name, type, change, reason);
  }

  Future<void> _recordMovement(
    Transaction txn,
    String name,
    String type,
    double quantity,
    String reason,
  ) => txn.insert('stock_movements', {
    'ingredient_name': name,
    'type': type,
    'quantity': quantity,
    'reason': reason,
    'created_at': DateTime.now().toIso8601String(),
  });

  Future<List<Map<String, Object?>>> recentSales() =>
      db.query('sales', orderBy: 'created_at DESC', limit: 30);

  Future<void> updateSaleStatus(int id, int status) =>
      db.update('sales', {'status': status}, where: 'id = ?', whereArgs: [id]);

  Future<Map<String, Object?>> todaySummary() async {
    final start = DateTime.now();
    final day = DateTime(start.year, start.month, start.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) revenue, COUNT(*) transactions FROM sales WHERE created_at >= ?',
      [day],
    );
    final profit = await db.rawQuery(
      '''
      SELECT COALESCE(SUM((si.unit_price + si.extra - si.unit_cost) * si.quantity), 0) profit
      FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.created_at >= ?
    ''',
      [day],
    );
    final expense = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) total FROM expenses WHERE created_at >= ?',
      [day],
    );
    final grossProfit = (profit.first['profit'] as num).round();
    final expenses = (expense.first['total'] as num).round();
    return {
      ...rows.first,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'profit': grossProfit - expenses,
    };
  }

  Future<Map<String, int>> topProducts() async => {
    for (final row in await db.rawQuery('''
          SELECT product_name, SUM(quantity) quantity
          FROM sale_items GROUP BY product_name
          ORDER BY quantity DESC LIMIT 5
        '''))
      row['product_name'] as String: (row['quantity'] as num).round(),
  };

  Future<List<double>> weeklyRevenue() async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final rows = await db.rawQuery(
      '''
      SELECT SUBSTR(created_at, 1, 10) day, SUM(total) total
      FROM sales WHERE created_at >= ? GROUP BY day
    ''',
      [start.toIso8601String()],
    );
    final values = {
      for (final row in rows)
        row['day'] as String: (row['total'] as num).toDouble(),
    };
    return List.generate(7, (index) {
      final day = start
          .add(Duration(days: index))
          .toIso8601String()
          .substring(0, 10);
      return values[day] ?? 0;
    });
  }
}

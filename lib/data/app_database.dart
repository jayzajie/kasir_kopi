import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

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
        version: 2,
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
        available INTEGER NOT NULL DEFAULT 1
      )''')
      ..execute('''CREATE TABLE inventory(
        name TEXT PRIMARY KEY,
        quantity REAL NOT NULL CHECK(quantity >= 0),
        unit TEXT NOT NULL,
        minimum REAL NOT NULL DEFAULT 0
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
      )''');

    for (final row in const [
      ['Es Latte', 28000, 'Kopi', 6800],
      ['Cappuccino', 32000, 'Kopi', 7200],
      ['Americano', 24000, 'Kopi', 4500],
      ['Caramel Latte', 34000, 'Kopi', 8200],
      ['Matcha Latte', 30000, 'Non Kopi', 8500],
      ['Croissant', 20000, 'Makanan', 10000],
    ]) {
      batch.insert('products', {
        'name': row[0],
        'price': row[1],
        'category': row[2],
        'cost': row[3],
      });
    }
    for (final row in const [
      ['Biji Kopi', 4.0, 'kg', 2.0],
      ['Susu Full Cream', 8.0, 'L', 10.0],
      ['Sirup Vanilla', 2.0, 'L', 3.0],
      ['Gula Aren', 1.0, 'kg', 2.0],
      ['Cup 12oz', 15.0, 'pcs', 50.0],
      ['Tutup Cup', 10.0, 'pcs', 30.0],
    ]) {
      batch.insert('inventory', {
        'name': row[0],
        'quantity': row[1],
        'unit': row[2],
        'minimum': row[3],
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Product>> products() async => (await db.query(
    'products',
    orderBy: 'name',
  )).map(Product.fromMap).toList();

  Future<Map<String, double>> inventory() async => {
    for (final row in await db.query('inventory', orderBy: 'name'))
      row['name'] as String: (row['quantity'] as num).toDouble(),
  };

  Future<void> setProductAvailability(int id, bool available) => db.update(
    'products',
    {'available': available ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  Future<void> addStock(String name, double amount) => db.rawUpdate(
    'UPDATE inventory SET quantity = quantity + ? WHERE name = ?',
    [amount, name],
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
      }
      final drinks = items
          .where((item) => item.product.category == 'Kopi')
          .fold<int>(0, (sum, item) => sum + item.qty);
      final cups = items.fold<int>(0, (sum, item) => sum + item.qty);
      await _reduce(txn, 'Biji Kopi', drinks * .018);
      await _reduce(txn, 'Susu Full Cream', drinks * .15);
      await _reduce(txn, 'Cup 12oz', cups.toDouble());
    });
  }

  Future<void> _reduce(Transaction txn, String name, double amount) =>
      txn.rawUpdate(
        'UPDATE inventory SET quantity = MAX(0, quantity - ?) WHERE name = ?',
        [amount, name],
      );

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
    return {...rows.first, 'profit': profit.first['profit']};
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

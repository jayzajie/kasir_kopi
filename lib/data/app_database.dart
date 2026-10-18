import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/cart_item.dart';
import '../models/accounting.dart';
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
        version: 10,
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
    // Versi 2-7: migrasi lama dipertahankan agar data existing tidak rusak
    if (oldVersion < 2) {
      await database.execute(
        'ALTER TABLE products ADD COLUMN cost INTEGER NOT NULL DEFAULT 0',
      );
      await database.execute(
        'ALTER TABLE sale_items ADD COLUMN unit_cost INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
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
      // Buat tabel akuntansi lama jika belum ada (agar tidak error saat drop)
      await database.execute(
        'ALTER TABLE inventory ADD COLUMN purchase_price INTEGER NOT NULL DEFAULT 0',
      ).catchError((_) async => 0);
      await database.execute(
        'ALTER TABLE inventory ADD COLUMN package_quantity REAL NOT NULL DEFAULT 1',
      ).catchError((_) async => 0);
    }
    if (oldVersion < 7) {
      // Migrasi unit lama kg→gram, L→ml
    }
    // v8: hapus tabel yang tidak diperlukan lagi
    if (oldVersion < 8) {
      await database
          .execute('DROP TABLE IF EXISTS inventory')
          .catchError((_) async => 0);
      await database
          .execute('DROP TABLE IF EXISTS recipes')
          .catchError((_) async => 0);
      await database
          .execute('DROP TABLE IF EXISTS expenses')
          .catchError((_) async => 0);
      await database
          .execute('DROP TABLE IF EXISTS stock_movements')
          .catchError((_) async => 0);
    }
    // v9: tambah kolom syrups_json ke products
    if (oldVersion < 9) {
      await database.execute(
        "ALTER TABLE products ADD COLUMN syrups_json TEXT NOT NULL DEFAULT '[]'",
      ).catchError((_) async => 0);
    }
    // v10: tambah kolom daily_number ke sales
    if (oldVersion < 10) {
      await database.execute(
        'ALTER TABLE sales ADD COLUMN daily_number INTEGER NOT NULL DEFAULT 0',
      ).catchError((_) async => 0);
    }
  }

  Future<void> close() => db.close();

  Future<void> _create(Database database, int version) async {
    await database.execute('''CREATE TABLE products(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price INTEGER NOT NULL CHECK(price >= 0),
      category TEXT NOT NULL,
      available INTEGER NOT NULL DEFAULT 1,
      addon_name TEXT NOT NULL DEFAULT '',
      addon_price INTEGER NOT NULL DEFAULT 0 CHECK(addon_price >= 0),
      ice_option TEXT NOT NULL DEFAULT 'Normal Ice',
      sugar_option TEXT NOT NULL DEFAULT 'Normal Sugar',
      image BLOB,
      addons_json TEXT NOT NULL DEFAULT '[]',
      syrups_json TEXT NOT NULL DEFAULT '[]'
    )''');
    await database.execute('''CREATE TABLE sales(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      transaction_number TEXT NOT NULL UNIQUE,
      customer_name TEXT NOT NULL,
      payment_method TEXT NOT NULL,
      total INTEGER NOT NULL,
      status INTEGER NOT NULL DEFAULT 0,
      daily_number INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )''');
    await database.execute('''CREATE TABLE sale_items(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
      product_id INTEGER,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price INTEGER NOT NULL,
      extra INTEGER NOT NULL DEFAULT 0,
      options TEXT NOT NULL DEFAULT '',
      note TEXT NOT NULL DEFAULT ''
    )''');
    await database.execute('''CREATE TABLE settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )''');
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Product>> products() async => (await db.query(
    'products',
    orderBy: 'name',
  )).map(Product.fromMap).toList();

  Future<int> addProduct(Product product) => db.insert('products', {
    'name': product.name,
    'price': product.price,
    'category': product.category,
    'available': product.available ? 1 : 0,
    'ice_option': product.iceOption,
    'sugar_option': product.sugarOption,
    'image': product.image,
    'addons_json': product.addonsJson,
    'syrups_json': product.syrupsJson,
  });

  Future<void> updateProduct(Product product) => db.update(
    'products',
    {
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'available': product.available ? 1 : 0,
      'ice_option': product.iceOption,
      'sugar_option': product.sugarOption,
      'image': product.image,
      'addons_json': product.addonsJson,
      'syrups_json': product.syrupsJson,
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
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setProductAvailability(int id, bool available) => db.update(
    'products',
    {'available': available ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );

  // ── Sales ─────────────────────────────────────────────────────────────────

  /// Hitung nomor urut order untuk hari ini berdasarkan waktu WITA (UTC+8).
  /// Reset setiap pergantian hari tengah malam WITA.
  Future<int> nextDailyNumber() async {
    // Waktu WITA = UTC+8
    final nowUtc = DateTime.now().toUtc();
    final nowWita = nowUtc.add(const Duration(hours: 8));
    final todayWita = DateTime.utc(nowWita.year, nowWita.month, nowWita.day);
    // Ubah balik ke UTC untuk disimpan di DB (yang pakai UTC)
    final startUtc = todayWita.subtract(const Duration(hours: 8));
    final rows = await db.rawQuery(
      'SELECT COUNT(*) cnt FROM sales WHERE created_at >= ?',
      [startUtc.toIso8601String()],
    );
    return (rows.first['cnt'] as int) + 1;
  }

  Future<int> saveSale({
    required String transactionNumber,
    required String customerName,
    required String paymentMethod,
    required DateTime createdAt,
    required List<CartItem> items,
    required int dailyNumber,
  }) async {
    return db.transaction((txn) async {
      final total = items.fold<int>(0, (sum, item) => sum + item.total);
      final saleId = await txn.insert('sales', {
        'transaction_number': transactionNumber,
        'customer_name': customerName,
        'payment_method': paymentMethod,
        'total': total,
        'daily_number': dailyNumber,
        'created_at': createdAt.toIso8601String(),
      });
      for (final item in items) {
        await txn.insert('sale_items', {
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.qty,
          'unit_price': item.product.price,
          'extra': item.extra,
          'options': item.options,
          'note': item.note,
        });
      }
      return dailyNumber;
    });
  }

  Future<List<Map<String, Object?>>> recentSales() =>
      db.query('sales', orderBy: 'created_at DESC', limit: 100);

  Future<void> updateSaleStatus(int id, int status) =>
      db.update('sales', {'status': status}, where: 'id = ?', whereArgs: [id]);

  Future<List<SaleLine>> saleItems(int saleId) async => (await db.query(
    'sale_items',
    where: 'sale_id = ?',
    whereArgs: [saleId],
    orderBy: 'id',
  )).map(SaleLine.fromMap).toList();

  // ── Dashboard summary ─────────────────────────────────────────────────────

  Future<Map<String, Object?>> todaySummary() async {
    final day = DateTime.now();
    final start = DateTime(day.year, day.month, day.day).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) revenue, COUNT(*) transactions FROM sales WHERE created_at >= ?',
      [start],
    );
    return rows.first;
  }

  Future<Map<String, Object?>> summaryForRange(
    DateTime from,
    DateTime to,
  ) async {
    final start = DateTime(from.year, from.month, from.day).toIso8601String();
    final end = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) revenue, COUNT(*) transactions FROM sales WHERE created_at >= ? AND created_at <= ?',
      [start, end],
    );
    return rows.first;
  }

  Future<List<double>> revenueForDays(DateTime startDay, int count) async {
    final rows = await db.rawQuery(
      '''
      SELECT SUBSTR(created_at, 1, 10) day, SUM(total) total
      FROM sales WHERE created_at >= ? GROUP BY day
      ''',
      [DateTime(startDay.year, startDay.month, startDay.day).toIso8601String()],
    );
    final values = {
      for (final row in rows)
        row['day'] as String: (row['total'] as num).toDouble(),
    };
    return List.generate(count, (i) {
      final day = startDay
          .add(Duration(days: i))
          .toIso8601String()
          .substring(0, 10);
      return values[day] ?? 0;
    });
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
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
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

  // ── Export ────────────────────────────────────────────────────────────────

  /// Ambil semua transaksi + item dalam rentang tanggal [from, to].
  Future<List<Map<String, Object?>>> salesForExport({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = DateTime(from.year, from.month, from.day).toIso8601String();
    final end = DateTime(
      to.year,
      to.month,
      to.day,
      23,
      59,
      59,
    ).toIso8601String();
    return db.rawQuery(
      '''
      SELECT
        s.id,
        s.transaction_number,
        s.daily_number,
        s.customer_name,
        s.payment_method,
        s.total,
        s.status,
        s.created_at,
        si.product_name,
        si.quantity,
        si.unit_price,
        si.extra,
        si.options,
        si.note
      FROM sales s
      JOIN sale_items si ON si.sale_id = s.id
      WHERE s.created_at >= ? AND s.created_at <= ?
      ORDER BY s.created_at ASC, s.id, si.id
      ''',
      [start, end],
    );
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  Future<void> reset() => db.transaction((txn) async {
    await txn.delete('sale_items');
    await txn.delete('sales');
    await txn.delete('products');
    await txn.delete('settings');
    await txn.execute("DELETE FROM sqlite_sequence WHERE name != 'settings'");
  });
}

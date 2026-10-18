import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/controllers/pos_controller.dart';
import 'package:kasir_kopi/data/app_database.dart';
import 'package:kasir_kopi/models/cart_item.dart';
import 'package:kasir_kopi/models/product.dart';

void main() {
  test('payment persists customer and sale in SQLite', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();
    expect(controller.products, isEmpty);

    await controller.addProduct(Product('Americano', 24000, 'Kopi'));
    controller.customerName = '  Budi Santoso  ';
    controller.add(CartItem(controller.products.first));

    await controller.finishPayment('Tunai');

    final time = controller.transactionTime;
    final timestamp = [
      time.day,
      time.month,
      time.year % 100,
      time.hour,
      time.minute,
    ].map((value) => value.toString().padLeft(2, '0')).join();
    expect(controller.transactionNumber, 'TRX-1$timestamp');
    expect(controller.receiptCustomerName, 'Budi Santoso');
    expect(controller.receipt, hasLength(1));
    expect(
      (await database.recentSales()).single['customer_name'],
      'Budi Santoso',
    );
    expect(controller.todayRevenue, 24000);
    expect(controller.todayTransactions, 1);

    controller.newTransaction();
    expect(controller.customerName, isEmpty);
    expect(controller.receiptCustomerName, 'Budi Santoso');
  });

  test('menu CRUD and database reset persist in SQLite', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();

    await controller.addProduct(
      Product(
        'Latte',
        28000,
        'Kopi',
        addons: const [ProductAddon('Extra Shot', 5000)],
      ),
    );
    final product = controller.products.single;
    await controller.updateProduct(
      Product(
        'Ice Latte',
        30000,
        'Kopi',
        id: product.id,
        iceOption: 'Less Ice',
        sugarOption: 'Less Sugar',
        image: Uint8List.fromList([1, 2, 3]),
        addons: const [
          ProductAddon('Whipped Cream', 6000),
          ProductAddon('Extra Shot', 5000),
        ],
      ),
    );
    final saved = (await database.products()).single;
    expect(saved.name, 'Ice Latte');
    expect(saved.iceOption, 'Less Ice');
    expect(saved.sugarOption, 'Less Sugar');
    expect(saved.image, [1, 2, 3]);
    expect(saved.addons, hasLength(2));
    expect(saved.addons.first.name, 'Whipped Cream');
    expect(saved.addons.last.price, 5000);

    await controller.deleteProduct(product);
    expect(await database.products(), isEmpty);

    await controller.resetDatabase();
    expect(controller.products, isEmpty);
    expect(controller.orders, isEmpty);
  });

  test('availability toggle reflects in product list', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();

    await controller.addProduct(Product('Cappuccino', 26000, 'Kopi'));
    final product = controller.products.single;
    expect(product.available, isTrue);

    await controller.setAvailability(product, false);
    expect(product.available, isFalse);
    final fromDb = (await database.products()).single;
    expect(fromDb.available, isFalse);
  });

  test('export query returns rows for date range', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();

    await controller.addProduct(Product('Espresso', 18000, 'Kopi'));
    controller.add(CartItem(controller.products.first));
    await controller.finishPayment('QRIS');

    final now = DateTime.now();
    final rows = await controller.salesForExport(
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day),
    );
    expect(rows, isNotEmpty);
    expect(rows.first['product_name'], 'Espresso');
  });
}

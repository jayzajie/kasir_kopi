import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/controllers/pos_controller.dart';
import 'package:kasir_kopi/data/app_database.dart';
import 'package:kasir_kopi/models/cart_item.dart';
import 'package:kasir_kopi/models/accounting.dart';
import 'package:kasir_kopi/models/product.dart';

void main() {
  test('payment persists customer, sale, and stock in SQLite', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();
    expect(controller.products, isEmpty);
    await controller.addProduct(
      Product('Americano', 24000, 'Kopi', cost: 4500),
    );
    await controller.saveIngredient(
      const IngredientCost(
        name: 'Cup 12oz',
        unit: 'pcs',
        purchasePrice: 4500,
        packageQuantity: 1,
      ),
    );
    await controller.saveRecipe(controller.products.first, {'Cup 12oz': 1});
    controller.customerName = '  Budi Santoso  ';
    controller.add(CartItem(controller.products.first));

    await controller.finishPayment('Tunai');

    expect(controller.receiptCustomerName, 'Budi Santoso');
    expect(controller.receipt, hasLength(1));
    expect(
      (await database.recentSales()).single['customer_name'],
      'Budi Santoso',
    );
    expect(controller.stock['Cup 12oz'], 14);
    expect(controller.todayRevenue, 24000);
    expect(controller.todayProfit, 19500);
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
        cost: 7000,
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
        cost: 7500,
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
    expect(controller.stock['Cup 12oz'], 15);
  });

  test('recipe calculates HPP and expenses reduce net profit', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();
    await controller.addProduct(Product('Kopi Susu', 24000, 'Kopi'));
    final product = controller.products.single;

    await controller.saveIngredient(
      const IngredientCost(
        name: 'Biji Kopi',
        unit: 'kg',
        purchasePrice: 120000,
        packageQuantity: 1000,
      ),
    );
    await controller.saveIngredient(
      const IngredientCost(
        name: 'Susu Full Cream',
        unit: 'L',
        purchasePrice: 20000,
        packageQuantity: 1000,
      ),
    );
    await controller.saveIngredient(
      const IngredientCost(
        name: 'Cup 12oz',
        unit: 'pcs',
        purchasePrice: 50000,
        packageQuantity: 50,
      ),
    );
    await controller.saveRecipe(product, {
      'Biji Kopi': 18,
      'Susu Full Cream': 150,
      'Cup 12oz': 1,
    });

    expect(product.cost, 6160);
    expect((await controller.recipe(product)).map((line) => line.cost), [
      2160,
      1000,
      3000,
    ]);
    await controller.addExpense('Listrik', 'Token listrik', 10000);
    controller.add(CartItem(product));
    await controller.finishPayment('Tunai');
    expect(controller.todayExpense, 10000);
    expect(controller.todayProfit, 7840);
    expect(controller.stock['Biji Kopi'], 3982);
    expect(
      (await controller.stockMovements('Biji Kopi')).single.type,
      'Penjualan',
    );
  });

  test(
    'purchase, adjustment, and stocktake leave an inventory ledger',
    () async {
      final database = AppDatabase();
      await database.initialize(inMemory: true);
      addTearDown(database.close);
      final controller = PosController(database);
      await controller.load();
      await controller.addProduct(Product('Espresso', 18000, 'Kopi'));
      final espresso = controller.products.single;
      await controller.saveIngredient(
        const IngredientCost(
          name: 'Biji Kopi',
          unit: 'gram',
          purchasePrice: 120000,
          packageQuantity: 1000,
        ),
      );
      await controller.saveRecipe(espresso, {'Biji Kopi': 18});

      await controller.addPurchase(
        name: 'Biji Kopi',
        packages: 2,
        packageQuantity: 1000,
        packagePrice: 150000,
      );
      await controller.adjustStock(
        name: 'Biji Kopi',
        change: -100,
        reason: 'Rusak/tumpah',
      );
      await controller.stocktake('Biji Kopi', 5800);

      expect(controller.stock['Biji Kopi'], 5800);
      expect(espresso.cost, 2700);
      expect((await controller.expenses()).single.amount, 300000);
      final movements = await controller.stockMovements('Biji Kopi');
      expect(movements.map((item) => item.type), [
        'Stok opname',
        'Penyesuaian',
        'Pembelian',
      ]);
      expect(movements.map((item) => item.quantity), [-100, -100, 2000]);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/controllers/pos_controller.dart';
import 'package:kasir_kopi/data/app_database.dart';
import 'package:kasir_kopi/models/cart_item.dart';

void main() {
  test('payment persists customer, sale, and stock in SQLite', () async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    final controller = PosController(database);
    await controller.load();
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
}

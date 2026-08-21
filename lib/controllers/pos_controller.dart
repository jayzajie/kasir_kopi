import '../data/app_database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

class OrderRecord {
  OrderRecord.fromMap(Map<String, Object?> map)
    : id = map['id'] as int,
      number = map['transaction_number'] as String,
      customer = map['customer_name'] as String,
      total = map['total'] as int,
      status = map['status'] as int,
      createdAt = DateTime.parse(map['created_at'] as String);

  final int id, total;
  final String number, customer;
  final DateTime createdAt;
  int status;
}

class PosController {
  PosController(this.database);

  final AppDatabase database;
  List<Product> products = [];
  final cart = <CartItem>[];
  Map<String, double> stock = {};
  List<OrderRecord> orders = [];
  Map<String, int> topProducts = {};
  List<double> weeklyRevenue = List.filled(7, 0);
  int todayRevenue = 0;
  int todayTransactions = 0;
  int todayProfit = 0;
  List<CartItem> receipt = [];
  String payment = 'Tunai';
  String transactionNumber = '';
  String customerName = '';
  String receiptCustomerName = 'Pelanggan';
  DateTime transactionTime = DateTime.now();

  int get total => cart.fold(0, (sum, item) => sum + item.total);

  Future<void> load() async {
    products = await database.products();
    await refreshBusinessData();
  }

  Future<void> refreshBusinessData() async {
    stock = await database.inventory();
    orders = (await database.recentSales()).map(OrderRecord.fromMap).toList();
    final summary = await database.todaySummary();
    todayRevenue = (summary['revenue'] as num).round();
    todayTransactions = (summary['transactions'] as num).round();
    todayProfit = (summary['profit'] as num).round();
    topProducts = await database.topProducts();
    weeklyRevenue = await database.weeklyRevenue();
  }

  void add(CartItem item) => cart.add(item);

  Future<void> restock(String item) async {
    await database.addStock(item, 10);
    stock = await database.inventory();
  }

  Future<void> setAvailability(Product product, bool available) async {
    await database.setProductAvailability(product.id, available);
    product.available = available;
  }

  Future<void> advanceOrder(int index) async {
    final order = orders[index];
    order.status = (order.status + 1).clamp(0, 3);
    await database.updateSaleStatus(order.id, order.status);
  }

  Future<void> finishPayment(String method) async {
    payment = method;
    receiptCustomerName = customerName.trim().isEmpty
        ? 'Pelanggan'
        : customerName.trim();
    transactionTime = DateTime.now();
    transactionNumber = 'TRX-${transactionTime.millisecondsSinceEpoch}';
    receipt = cart.map((item) => item.copy()).toList();
    await database.saveSale(
      transactionNumber: transactionNumber,
      customerName: receiptCustomerName,
      paymentMethod: payment,
      createdAt: transactionTime,
      items: receipt,
    );
    await refreshBusinessData();
  }

  void newTransaction() {
    cart.clear();
    customerName = '';
  }
}

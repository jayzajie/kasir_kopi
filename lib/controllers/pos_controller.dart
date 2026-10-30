import '../data/app_database.dart';
import '../models/cart_item.dart';
import '../models/accounting.dart';
import '../models/product.dart';
import '../models/receipt_settings.dart';

class OrderRecord {
  OrderRecord.fromMap(Map<String, Object?> map)
    : id = map['id'] as int,
      number = map['transaction_number'] as String,
      dailyNumber = (map['daily_number'] as int?) ?? 0,
      customer = map['customer_name'] as String,
      paymentMethod = map['payment_method'] as String,
      orderType = (map['order_type'] as String?) ?? 'Dine In',
      total = map['total'] as int,
      status = map['status'] as int,
      createdAt = DateTime.parse(map['created_at'] as String);

  final int id, total, dailyNumber;
  final String number, customer, paymentMethod, orderType;
  final DateTime createdAt;
  int status;
}

class PosController {
  PosController(this.database);

  final AppDatabase database;
  List<Product> products = [];
  final cart = <CartItem>[];
  List<OrderRecord> orders = [];
  Map<String, int> topProducts = {};
  List<double> weeklyRevenue = List.filled(7, 0);
  int todayRevenue = 0;
  int todayTransactions = 0;
  List<CartItem> receipt = [];
  String payment = 'Tunai';
  String transactionNumber = '';
  int receiptDailyNumber = 0;
  String customerName = '';
  String receiptCustomerName = 'Pelanggan';
  String orderType = 'Dine In';
  String receiptOrderType = 'Dine In';
  DateTime transactionTime = DateTime.now();

  int get total => cart.fold(0, (sum, item) => sum + item.total);

  Future<void> load() async {
    products = await database.products();
    await ReceiptSettings.load(database);
    await refreshData();
  }

  Future<void> refreshData() async {
    orders = (await database.recentSales()).map(OrderRecord.fromMap).toList();
    final summary = await database.todaySummary();
    todayRevenue = (summary['revenue'] as num).round();
    todayTransactions = (summary['transactions'] as num).round();
    topProducts = await database.topProducts();
    weeklyRevenue = await database.weeklyRevenue();
  }

  void add(CartItem item) => cart.add(item);

  Future<void> setAvailability(Product product, bool available) async {
    await database.setProductAvailability(product.id, available);
    product.available = available;
  }

  Future<void> addProduct(Product product) async {
    final id = await database.addProduct(product);
    products.add(
      Product(
        product.name,
        product.price,
        product.category,
        id: id,
        available: product.available,
        iceOption: product.iceOption,
        sugarOption: product.sugarOption,
        image: product.image,
        addons: product.addons,
      ),
    );
    products.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> updateProduct(Product product) async {
    await database.updateProduct(product);
    final current = products.firstWhere((item) => item.id == product.id);
    current
      ..name = product.name
      ..price = product.price
      ..category = product.category
      ..available = product.available
      ..iceOption = product.iceOption
      ..sugarOption = product.sugarOption
      ..image = product.image
      ..addons = product.addons;
    products.sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> deleteProduct(Product product) async {
    await database.deleteProduct(product.id);
    products.remove(product);
    cart.removeWhere((item) => item.product.id == product.id);
  }

  Future<List<SaleLine>> saleItems(int saleId) => database.saleItems(saleId);

  Future<List<Map<String, Object?>>> salesForExport({
    required DateTime from,
    required DateTime to,
  }) => database.salesForExport(from: from, to: to);

  Future<Map<String, Object?>> summaryForRange(DateTime from, DateTime to) =>
      database.summaryForRange(from, to);

  Future<List<double>> revenueForDays(DateTime startDay, int count) =>
      database.revenueForDays(startDay, count);

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
    receiptOrderType = orderType;
    transactionTime = DateTime.now();
    receiptDailyNumber = await database.nextDailyNumber();
    final timestamp = [
      transactionTime.day,
      transactionTime.month,
      transactionTime.year % 100,
      transactionTime.hour,
      transactionTime.minute,
    ].map((value) => value.toString().padLeft(2, '0')).join();
    transactionNumber = 'TRX-$receiptDailyNumber$timestamp';
    receipt = cart.map((item) => item.copy()).toList();
    await database.saveSale(
      transactionNumber: transactionNumber,
      customerName: receiptCustomerName,
      paymentMethod: payment,
      createdAt: transactionTime,
      items: receipt,
      dailyNumber: receiptDailyNumber,
      orderType: receiptOrderType,
    );
    await refreshData();
  }

  void newTransaction() {
    cart.clear();
    customerName = '';
    orderType = 'Dine In';
  }

  Future<void> resetDatabase() async {
    await database.reset();
    products.clear();
    cart.clear();
    receipt.clear();
    customerName = '';
    receiptCustomerName = 'Pelanggan';
    orderType = 'Dine In';
    receiptOrderType = 'Dine In';
    receiptDailyNumber = 0;
    transactionNumber = '';
    await refreshData();
  }
}

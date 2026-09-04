import '../data/app_database.dart';
import '../models/cart_item.dart';
import '../models/accounting.dart';
import '../models/product.dart';

class OrderRecord {
  OrderRecord.fromMap(Map<String, Object?> map)
    : id = map['id'] as int,
      number = map['transaction_number'] as String,
      customer = map['customer_name'] as String,
      paymentMethod = map['payment_method'] as String,
      total = map['total'] as int,
      status = map['status'] as int,
      createdAt = DateTime.parse(map['created_at'] as String);

  final int id, total;
  final String number, customer, paymentMethod;
  final DateTime createdAt;
  int status;
}

class PosController {
  PosController(this.database);

  final AppDatabase database;
  List<Product> products = [];
  final cart = <CartItem>[];
  Map<String, double> stock = {};
  List<IngredientCost> inventoryItems = [];
  List<OrderRecord> orders = [];
  Map<String, int> topProducts = {};
  List<double> weeklyRevenue = List.filled(7, 0);
  int todayRevenue = 0;
  int todayTransactions = 0;
  int todayProfit = 0;
  int todayExpense = 0;
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
    inventoryItems = await database.ingredients();
    orders = (await database.recentSales()).map(OrderRecord.fromMap).toList();
    final summary = await database.todaySummary();
    todayRevenue = (summary['revenue'] as num).round();
    todayTransactions = (summary['transactions'] as num).round();
    todayProfit = (summary['profit'] as num).round();
    todayExpense = (summary['expenses'] as num).round();
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
        cost: product.cost,
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
      ..cost = product.cost
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

  Future<List<IngredientCost>> ingredients() => database.ingredients();
  Future<List<RecipeLine>> recipe(Product product) =>
      database.recipe(product.id);

  Future<void> saveIngredient(IngredientCost ingredient) async {
    await database.saveIngredient(ingredient);
    await _refreshProductCosts();
    stock = await database.inventory();
    inventoryItems = await database.ingredients();
  }

  Future<void> saveRecipe(
    Product product,
    Map<String, double> quantities,
  ) async {
    product.cost = await database.saveRecipe(product.id, quantities);
  }

  Future<List<ExpenseRecord>> expenses() => database.expenses();

  Future<void> addExpense(
    String category,
    String description,
    int amount,
  ) async {
    await database.addExpense(category, description, amount);
    await refreshBusinessData();
  }

  Future<void> deleteExpense(int id) async {
    await database.deleteExpense(id);
    await refreshBusinessData();
  }

  Future<List<SaleLine>> saleItems(int saleId) => database.saleItems(saleId);

  Future<void> addPurchase({
    required String name,
    required double packages,
    required double packageQuantity,
    required int packagePrice,
  }) async {
    await database.addPurchase(
      name: name,
      packages: packages,
      packageQuantity: packageQuantity,
      packagePrice: packagePrice,
    );
    await _refreshProductCosts();
    await refreshBusinessData();
  }

  Future<void> _refreshProductCosts() async {
    final costs = {
      for (final item in await database.products()) item.id: item.cost,
    };
    for (final product in products) {
      product.cost = costs[product.id] ?? product.cost;
    }
  }

  Future<void> adjustStock({
    required String name,
    required double change,
    required String reason,
  }) async {
    await database.adjustStock(name: name, change: change, reason: reason);
    stock = await database.inventory();
    inventoryItems = await database.ingredients();
  }

  Future<void> stocktake(String name, double actual) async {
    await database.stocktake(name, actual);
    stock = await database.inventory();
    inventoryItems = await database.ingredients();
  }

  Future<List<StockMovement>> stockMovements(String name) =>
      database.stockMovements(name);

  Future<void> resetDatabase() async {
    await database.reset();
    products.clear();
    cart.clear();
    receipt.clear();
    customerName = '';
    receiptCustomerName = 'Pelanggan';
    transactionNumber = '';
    await refreshBusinessData();
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';

import 'controllers/pos_controller.dart';
import 'accounting_pages.dart';
import 'core/currency.dart';
import 'data/app_database.dart';
import 'models/cart_item.dart';
import 'models/product.dart';
import 'services/receipt_printer.dart';
import 'services/printer_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();
  await database.initialize();
  runApp(KopiKitaApp(database: database));
}

const brown = Color(0xff4b2a17);
const cream = Color(0xfffffbf5);
String rp(num n) => rupiah(n);

class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final formatted = rupiah(value).replaceFirst('Rp ', '');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

int parseRupiah(String value) => int.parse(value.replaceAll(RegExp(r'\D'), ''));

String formatRupiahInput(int? value) =>
    value == null ? '' : rupiah(value).replaceFirst('Rp ', '');

class KopiKitaApp extends StatelessWidget {
  const KopiKitaApp({super.key, required this.database});
  final AppDatabase database;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kopi Kita POS',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brown,
        primary: brown,
        surface: cream,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: .82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xffeadfd2)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    home: PosShell(database),
  );
}

class PosShell extends StatefulWidget {
  const PosShell(this.database, {super.key});
  final AppDatabase database;
  @override
  State<PosShell> createState() => PosShellState();
}

class PosShellState extends State<PosShell> {
  int tab = 0;
  late final PosController controller;
  bool loading = true;
  String? loadError;
  final printer = const ReceiptPrinter();
  List<Product> get products => controller.products;
  List<CartItem> get cart => controller.cart;
  Map<String, double> get stock => controller.stock;
  List<OrderRecord> get orders => controller.orders;
  List<CartItem> get receipt => controller.receipt;
  String get payment => controller.payment;
  String get trx => controller.transactionNumber;
  int get total => controller.total;

  @override
  void initState() {
    super.initState();
    controller = PosController(widget.database);
    controller
        .load()
        .then((_) {
          if (mounted) {
            setState(() => loading = false);
          }
        })
        .catchError((Object error) {
          if (mounted) {
            setState(() {
              loading = false;
              loadError = '$error';
            });
          }
        });
  }

  Future<void> add(Product p) async {
    if (!p.available) return;
    final item = p.category == 'Kopi'
        ? await Navigator.push<CartItem>(
            context,
            MaterialPageRoute(builder: (_) => CustomizePage(p)),
          )
        : CartItem(p);
    if (item != null) setState(() => controller.add(item));
  }

  Future<void> paid(String method) async {
    await controller.finishPayment(method);
  }

  Future<void> printReceipt() async {
    try {
      await printer.print(
        transactionNumber: trx,
        paymentMethod: payment,
        customerName: controller.receiptCustomerName,
        transactionTime: controller.transactionTime,
        items: receipt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dikirim ke printer.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mencetak: $error')));
      }
    }
  }

  void newTransaction(BuildContext context) {
    controller.newTransaction();
    Navigator.popUntil(context, (route) => route.isFirst);
    setState(() => tab = 1);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (loadError != null) {
      return Scaffold(
        body: Center(child: Text('Database gagal dibuka: $loadError')),
      );
    }
    final pages = [
      Dashboard(
        controller: controller,
        onReport: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportsPage(controller)),
        ),
      ),
      Cashier(
        products: products,
        cart: cart,
        onAdd: add,
        onCart: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CartPage(this)),
        ).then((_) => setState(() {})),
      ),
      Orders(orders, (i) async {
        await controller.advanceOrder(i);
        if (mounted) setState(() {});
      }),
      InventoryPage(controller, key: ValueKey(controller.stock.hashCode)),
      More(
        controller,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportsPage(controller)),
        ),
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Lainnya'),
        ],
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: brown,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 15, height: 1.35),
              ),
            ],
          ),
        ),
        const Column(
          children: [
            Icon(Icons.local_cafe_outlined, size: 42, color: brown),
            Text(
              'KOPI KITA',
              style: TextStyle(fontWeight: FontWeight.bold, color: brown),
            ),
          ],
        ),
      ],
    ),
  );
}

class ProductImage extends StatelessWidget {
  const ProductImage(this.product, {super.key, this.width, this.height});
  final Product product;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    if (product.image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          product.image!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        ),
      );
    }
    if (product.category == 'Kopi') {
      return Image.asset('assets/coffee.png', width: width, height: height);
    }
    return Icon(
      product.category == 'Makanan' ? Icons.bakery_dining : Icons.local_drink,
      size: width ?? height ?? 48,
      color: const Color(0xffb78d69),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric(this.label, this.value, this.icon, {super.key});
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: brown,
            foregroundColor: Colors.white,
            child: Icon(icon),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const Text(
            'SQLite lokal',
            style: TextStyle(fontSize: 10, color: Colors.green),
          ),
        ],
      ),
    ),
  );
}

class Dashboard extends StatelessWidget {
  const Dashboard({
    super.key,
    required this.controller,
    required this.onReport,
  });
  final PosController controller;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 20),
    children: [
      const Header(
        'Dashboard',
        'Selamat datang, Barista!\nKelola operasional coffee shop Anda.',
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
          childAspectRatio: 1.05,
          children: [
            Metric(
              'Omzet Hari Ini',
              rp(controller.todayRevenue),
              Icons.shopping_bag_outlined,
            ),
            Metric(
              'Transaksi Hari Ini',
              '${controller.todayTransactions}',
              Icons.shopping_cart_outlined,
            ),
            Metric(
              'Laba Bersih Est.',
              rp(controller.todayProfit),
              Icons.show_chart,
            ),
            Metric(
              'Pengeluaran',
              rp(controller.todayExpense),
              Icons.wallet_outlined,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: SalesChart(controller.weeklyRevenue),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: TopAndStock(controller),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: FilledButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.insights),
          label: const Text('Lihat Laporan & Analitik'),
        ),
      ),
    ],
  );
}

class SalesChart extends StatelessWidget {
  const SalesChart(this.revenue, {super.key});
  final List<double> revenue;
  @override
  Widget build(BuildContext context) {
    const days = ['H-6', 'H-5', 'H-4', 'H-3', 'H-2', 'Kemarin', 'Hari Ini'];
    final max = revenue.fold<double>(
      1,
      (value, item) => item > value ? item : value,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Omzet 7 Hari Terakhir',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 175,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  7,
                  (i) => Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          revenue[i] == 0
                              ? '0'
                              : '${(revenue[i] / 1000000).toStringAsFixed(1)} jt',
                          style: const TextStyle(fontSize: 10),
                        ),
                        Container(
                          height: 110 * revenue[i] / max,
                          width: 32,
                          decoration: const BoxDecoration(
                            color: brown,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        FittedBox(
                          child: Text(
                            days[i],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopAndStock extends StatelessWidget {
  const TopAndStock(this.controller, {super.key});
  final PosController controller;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, c) {
      final cards = [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produk Terlaris',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (controller.topProducts.isEmpty)
                  const ListTile(title: Text('Belum ada penjualan')),
                ...controller.topProducts.entries.indexed.map(
                  (e) => ListTile(
                    dense: true,
                    leading: CircleAvatar(child: Text('${e.$1 + 1}')),
                    title: Text(e.$2.key),
                    trailing: Text('${e.$2.value}'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok Menipis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (controller.inventoryItems.every(
                  (item) => item.minimum == 0 || item.quantity > item.minimum,
                ))
                  const ListTile(title: Text('Semua stok aman')),
                ...controller.inventoryItems
                    .where(
                      (item) =>
                          item.minimum > 0 && item.quantity <= item.minimum,
                    )
                    .map(
                      (item) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(item.name),
                        trailing: Text(
                          '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ];
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map(
              (e) => SizedBox(
                width: c.maxWidth > 700 ? (c.maxWidth - 10) / 2 : c.maxWidth,
                child: e,
              ),
            )
            .toList(),
      );
    },
  );
}

class Cashier extends StatefulWidget {
  const Cashier({
    super.key,
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onCart,
  });
  final List<Product> products;
  final List<CartItem> cart;
  final ValueChanged<Product> onAdd;
  final VoidCallback onCart;
  @override
  State<Cashier> createState() => _CashierState();
}

class _CashierState extends State<Cashier> {
  String category = 'Semua', query = '';
  @override
  Widget build(BuildContext context) {
    final shown = widget.products
        .where(
          (p) =>
              (category == 'Semua' || p.category == category) &&
              p.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final count = widget.cart.fold<int>(0, (s, e) => s + e.qty),
        sum = widget.cart.fold<int>(0, (s, e) => s + e.total);
    return Column(
      children: [
        const Header('Kasir', 'Pilih produk untuk ditambahkan ke keranjang.'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari produk...',
            ),
          ),
        ),
        SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            children: ['Semua', 'Kopi', 'Non Kopi', 'Makanan', 'Add-on']
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(e),
                      selected: category == e,
                      onSelected: (_) => setState(() => category = e),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    widget.products.isEmpty
                        ? 'Belum ada menu. Tambahkan dari halaman Lainnya.'
                        : 'Menu tidak ditemukan.',
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 700
                        ? 3
                        : 2,
                    childAspectRatio: .76,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (_, i) {
                    final p = shown[i];
                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => widget.onAdd(p),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: ProductImage(p, width: 90, height: 90),
                                ),
                              ),
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(child: Text(rp(p.price))),
                                  CircleAvatar(
                                    backgroundColor: brown,
                                    foregroundColor: Colors.white,
                                    child: Icon(
                                      p.available ? Icons.add : Icons.close,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (count > 0)
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xffe7d9ca)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: brown,
                  foregroundColor: Colors.white,
                  child: Text('$count'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${widget.cart.length} item\n${rp(sum)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton(
                  onPressed: widget.onCart,
                  child: const Text('Lihat Keranjang'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class Qty extends StatelessWidget {
  const Qty(this.value, this.changed, {super.key, this.zero = false});
  final int value;
  final ValueChanged<int> changed;
  final bool zero;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        onPressed: value > (zero ? 0 : 1) ? () => changed(value - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
      IconButton(
        onPressed: () => changed(value + 1),
        icon: const Icon(Icons.add),
      ),
    ],
  );
}

class CustomizePage extends StatefulWidget {
  const CustomizePage(this.product, {super.key});
  final Product product;
  @override
  State<CustomizePage> createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> {
  int qty = 1;
  String temp = 'Dingin', size = 'Medium', syrup = 'Caramel';
  late String ice, sugar;
  late final List<int> addonQuantities;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    ice = widget.product.iceOption;
    sugar = widget.product.sugarOption;
    addonQuantities = List.filled(widget.product.addons.length, 0);
  }

  int get extra =>
      (size == 'Large'
          ? 4000
          : size == 'Small'
          ? -2000
          : 0) +
      widget.product.addons.indexed.fold(
        0,
        (sum, entry) => sum + addonQuantities[entry.$1] * entry.$2.price,
      );

  String get selectedAddons => widget.product.addons.indexed
      .where((entry) => addonQuantities[entry.$1] > 0)
      .map((entry) => '${addonQuantities[entry.$1]} ${entry.$2.name}')
      .join(' • ');

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Custom Kopi')),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 150,
                  child: ProductImage(widget.product, width: 120, height: 150),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Perpaduan espresso dan susu segar.'),
                      Text(
                        rp(widget.product.price),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Qty(qty, (v) => setState(() => qty = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Options(
          'Panas / Dingin',
          ['Panas', 'Dingin'],
          temp,
          (v) => setState(() => temp = v),
        ),
        Options(
          'Ukuran',
          ['Small', 'Medium', 'Large'],
          size,
          (v) => setState(() => size = v),
        ),
        Options(
          'Es',
          ['Normal Ice', 'Less Ice'],
          ice,
          (value) => setState(() => ice = value),
        ),
        Options(
          'Gula',
          ['Normal Sugar', 'Less Sugar'],
          sugar,
          (value) => setState(() => sugar = value),
        ),
        Pick('Syrup', syrup, [
          'Caramel',
          'Vanilla',
          'Gula Aren',
        ], (v) => setState(() => syrup = v)),
        ...widget.product.addons.indexed.map(
          (entry) => Card(
            child: ListTile(
              title: Text(entry.$2.name),
              subtitle: Text('+ ${rp(entry.$2.price)}'),
              trailing: Qty(
                addonQuantities[entry.$1],
                (value) => setState(() => addonQuantities[entry.$1] = value),
                zero: true,
              ),
            ),
          ),
        ),
        TextField(
          controller: note,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Catatan Pesanan (Opsional)',
            hintText: 'Less ice, please',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            CartItem(
              widget.product,
              qty: qty,
              extra: extra,
              note: note.text,
              options:
                  '$temp • $size • $ice • $sugar • $syrup${selectedAddons.isEmpty ? '' : ' • $selectedAddons'}',
            ),
          ),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            'Tambah ke Keranjang • ${rp((widget.product.price + extra) * qty)}',
          ),
        ),
      ],
    ),
  );
}

class Options extends StatelessWidget {
  const Options(this.title, this.items, this.value, this.changed, {super.key});
  final String title, value;
  final List<String> items;
  final ValueChanged<String> changed;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 7,
            children: items
                .map(
                  (e) => ChoiceChip(
                    label: Text(e),
                    selected: value == e,
                    onSelected: (_) => changed(e),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}

class Pick extends StatelessWidget {
  const Pick(this.title, this.value, this.items, this.changed, {super.key});
  final String title, value;
  final List<String> items;
  final ValueChanged<String> changed;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      trailing: DropdownButton(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => changed(v!),
      ),
    ),
  );
}

class CartPage extends StatefulWidget {
  const CartPage(this.shell, {super.key});
  final PosShellState shell;
  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    final s = widget.shell;
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: s.cart.isEmpty
          ? const Center(child: Text('Keranjang masih kosong'))
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextFormField(
                      initialValue: s.controller.customerName,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      onChanged: (value) => s.controller.customerName = value,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pembeli',
                        hintText: 'Contoh: Budi Santoso',
                        prefixIcon: Icon(Icons.person_outline),
                        helperText: 'Nama akan dicetak pada struk',
                      ),
                    ),
                  ),
                ),
                ...s.cart.map(
                  (e) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 68,
                            height: 82,
                            child: ProductImage(
                              e.product,
                              width: 68,
                              height: 82,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                if (e.options.isNotEmpty)
                                  Text(
                                    e.options,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                if (e.note.isNotEmpty) Text('Note: ${e.note}'),
                                Text(
                                  rp(e.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Qty(e.qty, (v) => setState(() => e.qty = v)),
                          IconButton(
                            onPressed: () => setState(() => s.cart.remove(e)),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ringkasan Pesanan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Subtotal (${s.cart.fold<int>(0, (a, b) => a + b.qty)} item)',
                          ),
                          trailing: Text(rp(s.total)),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Diskon'),
                          trailing: Text(
                            '- Rp 0',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Pembayaran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              rp(s.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 23,
                                color: brown,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PaymentPage(s)),
                  ),
                  child: const Text('Lanjut ke Pembayaran'),
                ),
              ],
            ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage(this.shell, {super.key});
  final PosShellState shell;
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String method = 'Tunai';
  int cash = 0;
  @override
  Widget build(BuildContext context) {
    final total = widget.shell.total;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ringkasan Transaksi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Subtotal (${widget.shell.cart.length} item)'),
                    trailing: Text(rp(total)),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Pajak'),
                    trailing: Text('Rp 0'),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Tagihan',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        rp(total),
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                          color: brown,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Tunai',
                label: Text('Tunai'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: 'QRIS',
                label: Text('QRIS'),
                icon: Icon(Icons.qr_code),
              ),
              ButtonSegment(
                value: 'Transfer',
                label: Text('Transfer'),
                icon: Icon(Icons.account_balance_outlined),
              ),
            ],
            selected: {method},
            onSelectionChanged: (v) => setState(() => method = v.first),
          ),
          if (method == 'Tunai')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(
                        () => cash =
                            int.tryParse(v.replaceAll(RegExp(r'\D'), '')) ?? 0,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Nominal Diterima',
                        prefixText: 'Rp ',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kembalian: ${rp((cash - total).clamp(0, 999999999))}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Wrap(
                      spacing: 5,
                      children: [50000, 100000, 150000, 200000]
                          .map(
                            (v) => ActionChip(
                              label: Text(rp(v)),
                              onPressed: () => setState(() => cash = v),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          if (method == 'QRIS')
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2, size: 150),
                    Text('Pindai QRIS Kopi Kita'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: method == 'Tunai' && cash < total
                ? null
                : () async {
                    await widget.shell.paid(method);
                    await widget.shell.printReceipt();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SuccessPage(widget.shell),
                        ),
                        (r) => r.isFirst,
                      );
                    }
                  },
            child: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
  }
}

class SuccessPage extends StatelessWidget {
  const SuccessPage(this.shell, {super.key});
  final PosShellState shell;
  @override
  Widget build(BuildContext context) {
    final total = shell.receipt.fold<int>(0, (s, e) => s + e.total);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Header(
              'Pembayaran Berhasil',
              'Terima kasih! Pembayaran telah berhasil dan transaksi Anda telah dicatat.',
            ),
            const Icon(Icons.check_circle_outline, size: 125, color: brown),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Nomor Transaksi'),
                      trailing: Text(shell.trx),
                    ),
                    ListTile(
                      title: const Text('Metode Pembayaran'),
                      trailing: Text(shell.payment),
                    ),
                    ListTile(
                      title: const Text('Nama Pembeli'),
                      trailing: Text(shell.controller.receiptCustomerName),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        'Total Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        rp(total),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Struk',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...shell.receipt.map(
                      (e) => ListTile(
                        dense: true,
                        title: Text('${e.qty}x ${e.product.name}'),
                        trailing: Text(rp(e.total)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                OutlinedButton.icon(
                  onPressed: shell.printReceipt,
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak Struk'),
                ),
                FilledButton.icon(
                  onPressed: () => shell.newTransaction(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Transaksi Baru'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Orders extends StatelessWidget {
  const Orders(this.orders, this.changed, {super.key});
  final List<OrderRecord> orders;
  final ValueChanged<int> changed;
  @override
  Widget build(BuildContext context) {
    const states = ['Baru', 'Dibuat', 'Selesai', 'Diambil'];
    return Column(
      children: [
        const Header(
          'Pesanan',
          'Kelola pesanan pelanggan dengan mudah dan cepat.',
        ),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('Belum ada pesanan'))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Text(
                            '#${orders[i].id.toString().padLeft(4, '0')}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: brown,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  orders[i].customer,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${rp(orders[i].total)} • ${orders[i].number}',
                                ),
                                Text(
                                  states[orders[i].status],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: brown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: orders[i].status < 3
                                ? () => changed(i)
                                : null,
                            child: Text(
                              orders[i].status == 0
                                  ? 'Buat'
                                  : orders[i].status == 1
                                  ? 'Selesai'
                                  : orders[i].status == 2
                                  ? 'Diambil'
                                  : 'Done',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog(this.product);
  final Product? product;

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _AddonInput {
  _AddonInput({String name = '', int? price})
    : name = TextEditingController(text: name),
      price = TextEditingController(text: formatRupiahInput(price));

  factory _AddonInput.fromProduct(ProductAddon addon) =>
      _AddonInput(name: addon.name, price: addon.price);

  final TextEditingController name, price;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _ProductDialogState extends State<_ProductDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController price;
  late final TextEditingController cost;
  final addons = <_AddonInput>[];
  late String category, iceOption, sugarOption;
  Uint8List? image;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    name = TextEditingController(text: product?.name);
    price = TextEditingController(text: formatRupiahInput(product?.price));
    cost = TextEditingController(text: formatRupiahInput(product?.cost));
    category = product?.category ?? 'Kopi';
    iceOption = product?.iceOption ?? 'Normal Ice';
    sugarOption = product?.sugarOption ?? 'Normal Sugar';
    image = product?.image;
    addons.addAll(product?.addons.map(_AddonInput.fromProduct) ?? []);
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    cost.dispose();
    for (final addon in addons) {
      addon.dispose();
    }
    super.dispose();
  }

  Future<void> chooseImage() async {
    try {
      const images = XTypeGroup(
        label: 'Gambar',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        uniformTypeIdentifiers: [
          'public.jpeg',
          'public.png',
          'org.webmproject.webp',
        ],
      );
      final file = await openFile(acceptedTypeGroups: [images]);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw Exception('Ukuran foto maksimal 5 MB.');
      }
      if (mounted) setState(() => image = bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Foto gagal dipilih: $error')));
      }
    }
  }

  void addAddon() => setState(() => addons.add(_AddonInput()));

  void removeAddon(int index) {
    final removed = addons.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  String? moneyValidator(String? value) {
    final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
    return digits.isEmpty ? 'Harga wajib diisi' : null;
  }

  void save() {
    if (!formKey.currentState!.validate()) return;
    final existing = widget.product;
    Navigator.pop(
      context,
      Product(
        name.text.trim(),
        parseRupiah(price.text),
        category,
        id: existing?.id ?? 0,
        cost: parseRupiah(cost.text),
        available: existing?.available ?? true,
        iceOption: iceOption,
        sugarOption: sugarOption,
        image: image,
        addons: category == 'Kopi'
            ? addons
                  .map(
                    (addon) => ProductAddon(
                      addon.name.text.trim(),
                      parseRupiah(addon.price.text),
                    ),
                  )
                  .toList()
            : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Tambah Menu' : 'Edit Menu'),
    content: Form(
      key: formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama menu'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama menu wajib diisi'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: const ['Kopi', 'Non Kopi', 'Makanan', 'Add-on']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => category = value!),
            ),
            const SizedBox(height: 12),
            _moneyField(price, 'Harga jual'),
            const SizedBox(height: 12),
            _moneyField(cost, 'HPP / modal'),
            const SizedBox(height: 12),
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Image.memory(
                  image!,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Foto tidak dapat dibuka')),
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: chooseImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(image == null ? 'Pilih Foto' : 'Ubah Foto'),
                ),
                if (image != null)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => image = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus Foto'),
                  ),
              ],
            ),
            if (category == 'Kopi') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: iceOption,
                decoration: const InputDecoration(labelText: 'Pilihan es awal'),
                items: const ['Normal Ice', 'Less Ice']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => iceOption = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: sugarOption,
                decoration: const InputDecoration(
                  labelText: 'Pilihan gula awal',
                ),
                items: const ['Normal Sugar', 'Less Sugar']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => sugarOption = value!),
              ),
              const SizedBox(height: 12),
              ...addons.indexed.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.$2.name,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama add-on',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Wajib diisi'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _moneyField(entry.$2.price, 'Harga add-on'),
                      ),
                      IconButton(
                        onPressed: () => removeAddon(entry.$1),
                        tooltip: 'Hapus add-on',
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: addAddon,
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Add-on'),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: save, child: const Text('Simpan')),
    ],
  );

  TextFormField _moneyField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          RupiahInputFormatter(),
        ],
        decoration: InputDecoration(labelText: label, prefixText: 'Rp '),
        validator: moneyValidator,
      );
}

class More extends StatefulWidget {
  const More(this.controller, this.reports, {super.key});
  final PosController controller;
  final VoidCallback reports;
  @override
  State<More> createState() => _MoreState();
}

class _MoreState extends State<More> {
  Future<void> editProduct([Product? existing]) async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => _ProductDialog(existing),
    );
    if (product == null) return;
    if (existing == null) {
      await widget.controller.addProduct(product);
    } else {
      await widget.controller.updateProduct(product);
    }
    if (mounted) setState(() {});
  }

  Future<void> deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus menu?'),
        content: Text('${product.name} akan dihapus dari daftar menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.deleteProduct(product);
    if (mounted) setState(() {});
  }

  Future<void> resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset database?'),
        content: const Text(
          'Semua menu dan transaksi akan dihapus permanen. Stok akan dikembalikan ke kondisi awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.resetDatabase();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database berhasil direset.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      const Header(
        'Menu & Resep',
        'Kelola menu, harga, ketersediaan, dan resep setiap produk.',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: FilledButton.icon(
          onPressed: editProduct,
          icon: const Icon(Icons.add),
          label: const Text('Tambah Menu'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(14),
        child: Card(
          child: Column(
            children: [
              if (widget.controller.products.isEmpty)
                const ListTile(
                  leading: Icon(Icons.restaurant_menu),
                  title: Text('Belum ada menu'),
                  subtitle: Text('Tambahkan menu untuk mulai berjualan.'),
                ),
              ...widget.controller.products.map(
                (p) => ListTile(
                  leading: ProductImage(p, width: 43, height: 43),
                  title: Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${p.category} • ${rp(p.price)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: p.available,
                        onChanged: (value) async {
                          await widget.controller.setAvailability(p, value);
                          if (mounted) setState(() {});
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) =>
                            value == 'edit' ? editProduct(p) : deleteProduct(p),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: FilledButton.icon(
          onPressed: widget.reports,
          icon: const Icon(Icons.insights),
          label: const Text('Laporan & Analitik'),
        ),
      ),
      Padding(
        padding: EdgeInsets.all(14),
        child: Card(
          child: Column(
            children: [
              ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeHppPage(widget.controller),
                  ),
                ).then((_) => setState(() {})),
                leading: const Icon(Icons.science_outlined),
                title: const Text('Resep & HPP'),
                subtitle: const Text('Kelola biaya dan margin produk'),
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpensesPage(widget.controller),
                  ),
                ).then((_) => setState(() {})),
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Pengeluaran'),
                subtitle: const Text('Bahan, listrik, dan gas'),
                trailing: const Icon(Icons.chevron_right),
              ),
              ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TransactionHistoryPage(widget.controller),
                  ),
                ),
                leading: const Icon(Icons.history),
                title: const Text('Riwayat Transaksi'),
                subtitle: const Text('Semua transaksi dan detail item'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
            ),
            leading: const Icon(Icons.print_outlined),
            title: const Text('Pengaturan Printer'),
            subtitle: const Text('Deteksi, pilih, dan pairing USB/Bluetooth'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Card(
          child: ListTile(
            onTap: resetDatabase,
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Reset Database'),
            subtitle: const Text('Hapus seluruh data SQLite aplikasi'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    ],
  );
}

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});
  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final manager = PrinterManager.instance;
  List<Printer> printers = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      printers = await manager.discover();
    } catch (e) {
      error = 'Printer tidak dapat dideteksi: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> pair(String connection) async {
    try {
      await manager.openPairing(connection);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Pengaturan perangkat tidak tersedia.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan Printer')),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hubungkan Printer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pair printer melalui sistem, lalu kembali dan tekan Deteksi Ulang.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pair('bluetooth'),
                          icon: const Icon(Icons.bluetooth),
                          label: const Text('Pair Bluetooth'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pair('usb'),
                          icon: const Icon(Icons.usb),
                          label: const Text('Tambah USB'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Printer Terdeteksi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: loading ? null : refresh,
                tooltip: 'Deteksi Ulang',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline, color: Colors.red),
                title: Text(error!),
              ),
            ),
          if (!loading && error == null && printers.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.print_disabled_outlined),
                title: Text('Belum ada printer yang terdeteksi'),
                subtitle: Text(
                  'Pair melalui USB/Bluetooth atau gunakan pemilih printer sistem.',
                ),
              ),
            ),
          ...printers.map((printer) {
            final selected = manager.selectedPrinter?.url == printer.url;
            return Card(
              child: ListTile(
                onTap: printer.isAvailable
                    ? () => setState(() => manager.selectedPrinter = printer)
                    : null,
                leading: Icon(
                  selected ? Icons.check_circle : Icons.print_outlined,
                  color: selected ? Colors.green : brown,
                ),
                title: Text(
                  printer.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${printer.model ?? 'Printer sistem'}${printer.isDefault ? ' • Default' : ''}\n${printer.isAvailable ? 'Siap digunakan' : 'Tidak tersedia'}',
                ),
                trailing: selected
                    ? const Text(
                        'Dipilih',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.chevron_right),
              ),
            );
          }),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              await manager.choose(context);
              if (mounted) {
                await refresh();
                setState(() {});
              }
            },
            icon: const Icon(Icons.manage_search),
            label: const Text('Buka Pemilih Printer Sistem'),
          ),
        ],
      ),
    ),
  );
}

class ReportsPage extends StatelessWidget {
  const ReportsPage(this.controller, {super.key});
  final PosController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Laporan & Analitik')),
    body: ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Harian')),
            ButtonSegment(value: 1, label: Text('Mingguan')),
            ButtonSegment(value: 2, label: Text('Bulanan')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Metric(
                'Omzet',
                rp(controller.todayRevenue),
                Icons.shopping_bag_outlined,
              ),
            ),
            Expanded(
              child: Metric(
                'Profit',
                rp(controller.todayProfit),
                Icons.show_chart,
              ),
            ),
            Expanded(
              child: Metric(
                'Pengeluaran',
                rp(controller.todayExpense),
                Icons.wallet_outlined,
              ),
            ),
          ],
        ),
        SalesChart(controller.weeklyRevenue),
        TopAndStock(controller),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';

import 'controllers/pos_controller.dart';
import 'core/currency.dart';
import 'data/app_database.dart';
import 'models/accounting.dart';
import 'models/cart_item.dart';
import 'models/product.dart';
import 'services/excel_exporter.dart';
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
    title: 'Kedai Kopi Karsa.co POS',
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

bool isTabletScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

bool isWideTabletScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 750;

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 960,
  });
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class PosShellState extends State<PosShell> {
  int tab = 0;
  late final PosController controller;
  bool loading = true;
  String? loadError;
  final printer = const ReceiptPrinter();
  List<Product> get products => controller.products;
  List<CartItem> get cart => controller.cart;
  List<OrderRecord> get orders => controller.orders;
  List<CartItem> get receipt => controller.receipt;
  String get payment => controller.payment;
  String get trx => controller.transactionNumber;
  int get orderNumber => controller.receiptDailyNumber;
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
        orderNumber: orderNumber,
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
    final width = MediaQuery.sizeOf(context).width;
    final tablet = width >= 600;
    final extendedRail = width >= 1080;
    final cartCount = cart.fold<int>(0, (s, e) => s + e.qty);

    final pages = [
      Dashboard(
        controller: controller,
        onReport: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportsPage(controller)),
        ),
      ),
      Cashier(
        shell: this,
        products: products,
        cart: cart,
        onAdd: add,
        onCart: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CartPage(this)),
        ).then((_) => setState(() {})),
        onChanged: () => setState(() {}),
      ),
      Orders(orders, (i) async {
        await controller.advanceOrder(i);
        if (mounted) setState(() {});
      }),
      More(
        controller,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReportsPage(controller)),
        ),
      ),
    ];

    if (tablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                backgroundColor: Colors.white.withValues(alpha: .88),
                extended: extendedRail,
                minWidth: 84,
                minExtendedWidth: 210,
                selectedIndex: tab,
                onDestinationSelected: (i) => setState(() => tab = i),
                labelType: extendedRail
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Image.asset(
                    'logo_karsa.png',
                    width: extendedRail ? 120 : 56,
                    semanticLabel: 'Kedai Kopi Karsa.co, Est. 2026',
                  ),
                ),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      child: const Icon(Icons.point_of_sale_outlined),
                    ),
                    selectedIcon: Badge(
                      isLabelVisible: cartCount > 0,
                      label: Text('$cartCount'),
                      child: const Icon(Icons.point_of_sale),
                    ),
                    label: const Text('Kasir'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: Text('Pesanan'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.more_horiz),
                    label: Text('Lainnya'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1, color: Color(0xffeadfd2)),
              Expanded(
                child: IndexedStack(index: tab, children: pages),
              ),
            ],
          ),
        ),
      );
    }

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
  Widget build(BuildContext context) {
    final tablet = isTabletScreen(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(22, tablet ? 20 : 24, 22, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: tablet ? 30 : 34,
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
          Image.asset(
            'logo_karsa.png',
            width: tablet ? 120 : 150,
            semanticLabel: 'Kedai Kopi Karsa.co, Est. 2026',
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.all(14),
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
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 840;
    final isTablet = width >= 600;

    return ResponsiveCenter(
      maxWidth: 1200,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          const Header(
            'Dashboard',
            'Selamat datang, Barista!\nKelola operasional coffee shop Anda.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: isTablet
                ? SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Metric(
                            'Omzet Hari Ini',
                            rp(controller.todayRevenue),
                            Icons.shopping_bag_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Metric(
                            'Transaksi Hari Ini',
                            '${controller.todayTransactions}',
                            Icons.shopping_cart_outlined,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
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
                    ],
                  ),
          ),
          if (isWide)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SalesChart(controller.weeklyRevenue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TopProducts(controller),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: onReport,
                          icon: const Icon(Icons.insights),
                          label: const Text('Lihat Laporan & Analitik'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: SalesChart(controller.weeklyRevenue),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TopProducts(controller),
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
        ],
      ),
    );
  }
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

class TopProducts extends StatelessWidget {
  const TopProducts(this.controller, {super.key});
  final PosController controller;
  @override
  Widget build(BuildContext context) => Card(
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
              trailing: Text('${e.$2.value}x'),
            ),
          ),
        ],
      ),
    ),
  );
}

class Cashier extends StatefulWidget {
  const Cashier({
    super.key,
    required this.shell,
    required this.products,
    required this.cart,
    required this.onAdd,
    required this.onCart,
    required this.onChanged,
  });
  final PosShellState shell;
  final List<Product> products;
  final List<CartItem> cart;
  final ValueChanged<Product> onAdd;
  final VoidCallback onCart;
  final VoidCallback onChanged;
  @override
  State<Cashier> createState() => _CashierState();
}

class _CashierState extends State<Cashier> {
  String category = 'Semua', query = '';
  final _tabletCartFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final splitTabletView = width >= 820;
    final isTablet = width >= 600;

    final shown = widget.products
        .where(
          (p) =>
              (category == 'Semua' || p.category == category) &&
              p.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    final count = widget.cart.fold<int>(0, (s, e) => s + e.qty),
        sum = widget.cart.fold<int>(0, (s, e) => s + e.total);

    final menuColumn = Column(
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
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  gridDelegate: isTablet
                      ? const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          childAspectRatio: .78,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        )
                      : const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(child: Text(rp(p.price))),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: brown,
                                    foregroundColor: Colors.white,
                                    child: Icon(
                                      p.available ? Icons.add : Icons.close,
                                      size: 20,
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
        if (!splitTabletView && count > 0)
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

    if (!splitTabletView) return menuColumn;

    return Row(
      children: [
        Expanded(child: menuColumn),
        const VerticalDivider(width: 1, color: Color(0xffeadfd2)),
        SizedBox(
          width: width >= 1100 ? 390 : 340,
          child: _TabletCartPanel(
            shell: widget.shell,
            formKey: _tabletCartFormKey,
            onChanged: () {
              setState(() {});
              widget.onChanged();
            },
            onOpenCartPage: widget.onCart,
          ),
        ),
      ],
    );
  }
}

class _TabletCartPanel extends StatelessWidget {
  const _TabletCartPanel({
    required this.shell,
    required this.formKey,
    required this.onChanged,
    required this.onOpenCartPage,
  });

  final PosShellState shell;
  final GlobalKey<FormState> formKey;
  final VoidCallback onChanged;
  final VoidCallback onOpenCartPage;

  @override
  Widget build(BuildContext context) {
    final count = shell.cart.fold<int>(0, (s, e) => s + e.qty);
    return Container(
      color: Colors.white.withValues(alpha: .65),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: brown),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Keranjang Pesanan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: brown,
                    ),
                  ),
                ),
                if (count > 0)
                  IconButton(
                    onPressed: onOpenCartPage,
                    tooltip: 'Buka halaman keranjang penuh',
                    icon: const Icon(Icons.open_in_full, size: 20),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeadfd2)),
          if (shell.cart.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 56,
                        color: Color(0xffb78d69),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Keranjang masih kosong',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Ketuk produk di sebelah kiri untuk menambahkan pesanan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Form(
                key: formKey,
                child: TextFormField(
                  key: ValueKey(shell.trx),
                  initialValue: shell.controller.customerName,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => shell.controller.customerName = value,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama pembeli wajib diisi'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pembeli *',
                    hintText: 'Contoh: Budi Santoso',
                    prefixIcon: Icon(Icons.person_outline),
                    isDense: true,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: shell.cart.length,
                itemBuilder: (_, i) {
                  final e = shell.cart[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProductImage(e.product, width: 44, height: 44),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (e.options.isNotEmpty)
                                      Text(
                                        e.options,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    if (e.note.isNotEmpty)
                                      Text(
                                        'Note: ${e.note}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  shell.cart.remove(e);
                                  onChanged();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                rp(e.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: brown,
                                ),
                              ),
                              Qty(e.qty, (v) {
                                e.qty = v;
                                onChanged();
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xffeadfd2))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal ($count item)'),
                      Text(rp(shell.total)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        rp(shell.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 21,
                          color: brown,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PaymentPage(shell)),
                      ).then((_) => onChanged());
                    },
                    child: const Text('Lanjut ke Pembayaran'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
  String temp = 'Dingin', size = 'Medium';
  late String ice, sugar, syrup;
  late final List<int> addonQuantities;
  final note = TextEditingController();

  @override
  void initState() {
    super.initState();
    ice = widget.product.iceOption;
    sugar = widget.product.sugarOption;
    // Syrup default: pilihan pertama dari daftar produk, atau kosong jika tidak ada
    final syrupList = widget.product.syrups;
    syrup = syrupList.isNotEmpty ? syrupList.first : '';
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
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 780;
    final productCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 150,
              child: ProductImage(widget.product, width: 120, height: 150),
            ),
            const SizedBox(width: 12),
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
    );

    final mainOptions = [
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
      if (widget.product.syrups.isNotEmpty)
        Pick(
          'Syrup',
          syrup.isNotEmpty ? syrup : widget.product.syrups.first,
          widget.product.syrups,
          (v) => setState(() => syrup = v),
        ),
    ];

    final addonsAndSubmit = [
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
      const SizedBox(height: 6),
      TextField(
        controller: note,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Catatan Pesanan (Opsional)',
          hintText: 'Less ice, please',
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(
            context,
            CartItem(
              widget.product,
              qty: qty,
              extra: extra,
              note: note.text,
              options:
                  '$temp • $size • $ice • $sugar${syrup.isNotEmpty ? ' • $syrup' : ''}${selectedAddons.isEmpty ? '' : ' • $selectedAddons'}',
            ),
          ),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(
            'Tambah ke Keranjang • ${rp((widget.product.price + extra) * qty)}',
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Kopi')),
      body: ResponsiveCenter(
        maxWidth: wide ? 1020 : 680,
        child: wide
            ? ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  productCard,
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(children: mainOptions)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(children: addonsAndSubmit)),
                    ],
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  productCard,
                  ...mainOptions,
                  ...addonsAndSubmit,
                ],
              ),
      ),
    );
  }
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
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final s = widget.shell;
    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang')),
      body: s.cart.isEmpty
          ? const Center(child: Text('Keranjang masih kosong'))
          : ResponsiveCenter(
              maxWidth: 760,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          initialValue: s.controller.customerName,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 50,
                          onChanged: (value) =>
                              s.controller.customerName = value,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Nama pembeli wajib diisi'
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Nama Pembeli *',
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
                                    if (e.note.isNotEmpty)
                                      Text('Note: ${e.note}'),
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
                                onPressed: () =>
                                    setState(() => s.cart.remove(e)),
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
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PaymentPage(s)),
                        );
                      },
                      child: const Text('Lanjut ke Pembayaran'),
                    ),
                  ],
                ),
              ),
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
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final summaryCard = Card(
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
    );

    final paymentControls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          ],
          selected: {method},
          onSelectionChanged: (v) => setState(() => method = v.first),
        ),
        const SizedBox(height: 8),
        if (method == 'Tunai')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahInputFormatter()],
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
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
                  Text('Pindai QRIS Kedai Kopi Karsa.co'),
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
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: ResponsiveCenter(
        maxWidth: wide ? 960 : 640,
        child: wide
            ? ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: summaryCard),
                      const SizedBox(width: 16),
                      Expanded(child: paymentControls),
                    ],
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  summaryCard,
                  paymentControls,
                ],
              ),
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
        child: ResponsiveCenter(
          maxWidth: 760,
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
                      if (shell.orderNumber > 0)
                        ListTile(
                          title: const Text('Nomor Order Hari Ini'),
                          trailing: Text(
                            '#${shell.orderNumber}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: brown,
                            ),
                          ),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
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
    final isTablet = MediaQuery.sizeOf(context).width >= 700;

    Widget buildOrderCard(int i) => Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              orders[i].dailyNumber > 0
                  ? '#${orders[i].dailyNumber}'
                  : '#${orders[i].id.toString().padLeft(4, '0')}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: brown,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orders[i].customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${rp(orders[i].total)} • ${orders[i].number}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 8),
            FilledButton(
              onPressed: orders[i].status < 3 ? () => changed(i) : null,
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
    );

    return ResponsiveCenter(
      maxWidth: 1200,
      child: Column(
        children: [
          const Header(
            'Pesanan',
            'Kelola pesanan pelanggan dengan mudah dan cepat.',
          ),
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('Belum ada pesanan'))
                : isTablet
                ? GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 480,
                          mainAxisExtent: 124,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => buildOrderCard(i),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => buildOrderCard(i),
                  ),
          ),
        ],
      ),
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
  final addons = <_AddonInput>[];
  final syrups = <TextEditingController>[];
  late String category, iceOption, sugarOption;
  Uint8List? image;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    name = TextEditingController(text: product?.name);
    price = TextEditingController(text: formatRupiahInput(product?.price));
    category = product?.category ?? 'Kopi';
    iceOption = product?.iceOption ?? 'Normal Ice';
    sugarOption = product?.sugarOption ?? 'Normal Sugar';
    image = product?.image;
    addons.addAll(product?.addons.map(_AddonInput.fromProduct) ?? []);
    final syrupList = product?.syrups ?? kDefaultSyrups;
    syrups.addAll(syrupList.map((s) => TextEditingController(text: s)));
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    for (final addon in addons) {
      addon.dispose();
    }
    for (final s in syrups) {
      s.dispose();
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
        syrups: category == 'Kopi'
            ? syrups
                  .map((c) => c.text.trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
            : const [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'Tambah Menu' : 'Edit Menu'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 360, maxWidth: 520),
      child: Form(
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
                const SizedBox(height: 16),
                // ── Daftar Syrup ───────────────────────────────────────────────
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pilihan Syrup',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                ...syrups.indexed.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: entry.$2,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Syrup ${entry.$1 + 1}',
                              isDense: true,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                ? 'Wajib diisi'
                                : null,
                          ),
                        ),
                        IconButton(
                          onPressed: syrups.length > 1
                              ? () {
                                  final removed = syrups.removeAt(entry.$1);
                                  setState(() {});
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => removed.dispose(),
                                  );
                                }
                              : null,
                          tooltip: 'Hapus syrup',
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(
                      () => syrups.add(TextEditingController()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Syrup'),
                  ),
                ),
              ],
            ],
          ),
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
          'Semua menu dan transaksi akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
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
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    final menuSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                          onSelected: (value) => value == 'edit'
                              ? editProduct(p)
                              : deleteProduct(p),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
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
      ],
    );

    final settingsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: FilledButton.icon(
            onPressed: widget.reports,
            icon: const Icon(Icons.insights),
            label: const Text('Laporan & Analitik'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Card(
            child: Column(
              children: [
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
                ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportPage(widget.controller),
                    ),
                  ),
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export Excel'),
                  subtitle: const Text(
                    'Rekap transaksi per minggu, bulan, atau rentang bulan',
                  ),
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

    return ResponsiveCenter(
      maxWidth: 1200,
      child: ListView(
        children: [
          const Header(
            'Menu',
            'Kelola menu dan ketersediaan produk.',
          ),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: menuSection),
                Expanded(flex: 2, child: settingsSection),
              ],
            )
          else ...[
            menuSection,
            settingsSection,
          ],
        ],
      ),
    );
  }
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
    body: ResponsiveCenter(
      maxWidth: 760,
      child: RefreshIndicator(
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
    ),
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage(this.controller, {super.key});
  final PosController controller;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _period = 0; // 0=Harian, 1=Mingguan, 2=Bulanan
  int _revenue = 0;
  int _transactions = 0;
  List<double> _chartData = List.filled(7, 0);
  // Label sumbu X chart
  List<String> _chartLabels = ['H-6', 'H-5', 'H-4', 'H-3', 'H-2', 'Kemarin', 'Hari Ini'];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int period) async {
    setState(() {
      _period = period;
      _loading = true;
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late DateTime from, to;
    late DateTime chartStart;

    if (period == 0) {
      // Harian: hari ini saja
      from = today;
      to = today;
      chartStart = today.subtract(const Duration(days: 6));
      _chartLabels = ['H-6', 'H-5', 'H-4', 'H-3', 'H-2', 'Kemarin', 'Hari Ini'];
    } else if (period == 1) {
      // Mingguan: Senin – Minggu pekan ini
      final diff = now.weekday - 1;
      from = today.subtract(Duration(days: diff));
      to = from.add(const Duration(days: 6));
      chartStart = from;
      _chartLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    } else {
      // Bulanan: bulan ini
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 0); // hari terakhir bulan
      // Chart: 4 minggu terakhir (28 hari)
      chartStart = today.subtract(const Duration(days: 27));
      _chartLabels = List.generate(28, (i) {
        final d = chartStart.add(Duration(days: i));
        return '${d.day}';
      });
    }

    final summary = await widget.controller.summaryForRange(from, to);
    final chartData = period == 2
        ? await widget.controller.revenueForDays(chartStart, 28)
        : await widget.controller.revenueForDays(chartStart, 7);

    if (!mounted) return;
    setState(() {
      _revenue = (summary['revenue'] as num).round();
      _transactions = (summary['transactions'] as num).round();
      _chartData = chartData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan & Analitik')),
      body: ResponsiveCenter(
        maxWidth: 1100,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Harian')),
                ButtonSegment(value: 1, label: Text('Mingguan')),
                ButtonSegment(value: 2, label: Text('Bulanan')),
              ],
              selected: {_period},
              onSelectionChanged: (v) => _load(v.first),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      'Omzet',
                      rp(_revenue),
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                  Expanded(
                    child: Metric(
                      'Transaksi',
                      '$_transactions',
                      Icons.shopping_cart_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _ReportChart(_chartData, _chartLabels),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TopProducts(widget.controller),
                    ),
                  ],
                )
              else ...[
                _ReportChart(_chartData, _chartLabels),
                TopProducts(widget.controller),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Chart laporan (label dinamis) ────────────────────────────────────────────

class _ReportChart extends StatelessWidget {
  const _ReportChart(this.revenue, this.labels);
  final List<double> revenue;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final max = revenue.fold<double>(1, (v, item) => item > v ? item : v);
    final count = revenue.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Omzet Periode',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 15),
            SizedBox(
              height: 175,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(count, (i) {
                  final val = revenue[i];
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (val > 0)
                          Text(
                            '${(val / 1000000).toStringAsFixed(1)}jt',
                            style: const TextStyle(fontSize: 8),
                          ),
                        Container(
                          height: 110 * val / max,
                          width: count > 10 ? 8 : 28,
                          decoration: const BoxDecoration(
                            color: brown,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            labels[i],
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Riwayat Transaksi
// ─────────────────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage(this.controller, {super.key});
  final PosController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat Transaksi')),
    body: controller.orders.isEmpty
        ? const Center(child: Text('Belum ada transaksi.'))
        : ResponsiveCenter(
            maxWidth: 860,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: controller.orders
                  .map(
                    (sale) => Card(
                      child: ExpansionTile(
                        title: Text(sale.number),
                        subtitle: Text(
                          '${sale.customer} • ${sale.paymentMethod}\n${_fmtDate(sale.createdAt)}',
                        ),
                        leading: sale.dailyNumber > 0
                            ? CircleAvatar(
                                backgroundColor: brown,
                                foregroundColor: Colors.white,
                                child: Text(
                                  '#${sale.dailyNumber}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        trailing: Text(
                          rp(sale.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          FutureBuilder<List<SaleLine>>(
                            future: controller.saleItems(sale.id),
                            builder: (_, snapshot) {
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final lines = snapshot.data!;
                              final items = lines
                                  .map(
                                    (line) => CartItem(
                                      Product(
                                        line.productName,
                                        line.unitPrice,
                                        '',
                                      ),
                                      qty: line.quantity,
                                      extra: line.extra,
                                      options: line.options,
                                      note: line.note,
                                    ),
                                  )
                                  .toList();
                              return Column(
                                children: [
                                  ...lines.map(
                                    (line) => ListTile(
                                      dense: true,
                                      title: Text(
                                        '${line.quantity}× ${line.productName}',
                                      ),
                                      subtitle: line.options.isEmpty
                                          ? null
                                          : Text(line.options),
                                      trailing: Text(rp(line.total)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () async {
                                          try {
                                            await const ReceiptPrinter().print(
                                              transactionNumber: sale.number,
                                              paymentMethod: sale.paymentMethod,
                                              customerName: sale.customer,
                                              transactionTime: sale.createdAt,
                                              items: items,
                                              orderNumber: sale.dailyNumber,
                                            );
                                          } catch (error) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Gagal mencetak: $error',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.print_outlined),
                                        label: const Text('Cetak Ulang'),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Export Excel
// ─────────────────────────────────────────────────────────────────────────────

enum _ExportMode { weekly, monthly, monthRange }

class ExportPage extends StatefulWidget {
  const ExportPage(this.controller, {super.key});
  final PosController controller;

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  _ExportMode _mode = _ExportMode.monthly;
  bool _exporting = false;

  // Filter: per bulan
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Filter: per minggu
  late DateTime _weekStart;

  // Filter: rentang bulan
  int _rangeFromYear = DateTime.now().year;
  int _rangeFromMonth = 1;
  int _rangeToYear = DateTime.now().year;
  int _rangeToMonth = DateTime.now().month;

  static const _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final diff = now.weekday - 1; // Monday=1
    _weekStart = DateTime(now.year, now.month, now.day - diff);
  }

  Future<void> _doExport() async {
    setState(() => _exporting = true);
    try {
      late DateTime from, to;
      late String label;

      if (_mode == _ExportMode.monthly) {
        from = DateTime(_selectedYear, _selectedMonth, 1);
        to = DateTime(_selectedYear, _selectedMonth + 1, 0);
        label = '${_months[_selectedMonth - 1]} $_selectedYear';
      } else if (_mode == _ExportMode.weekly) {
        from = _weekStart;
        to = _weekStart.add(const Duration(days: 6));
        label =
            '${_fmtShort(from)} s.d. ${_fmtShort(to)}';
      } else {
        from = DateTime(_rangeFromYear, _rangeFromMonth, 1);
        to = DateTime(_rangeToYear, _rangeToMonth + 1, 0);
        label =
            '${_months[_rangeFromMonth - 1]} $_rangeFromYear'
            ' – '
            '${_months[_rangeToMonth - 1]} $_rangeToYear';
      }

      final rows = await widget.controller.salesForExport(from: from, to: to);

      if (!mounted) return;

      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada transaksi pada periode ini.')),
        );
        return;
      }

      await const ExcelExporter().export(
        context: context,
        rows: rows,
        from: from,
        to: to,
        periodLabel: label,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Excel')),
      body: ResponsiveCenter(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Periode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_ExportMode>(
                      segments: const [
                        ButtonSegment(
                          value: _ExportMode.weekly,
                          label: Text('Mingguan'),
                          icon: Icon(Icons.view_week_outlined),
                        ),
                        ButtonSegment(
                          value: _ExportMode.monthly,
                          label: Text('Bulanan'),
                          icon: Icon(Icons.calendar_month_outlined),
                        ),
                        ButtonSegment(
                          value: _ExportMode.monthRange,
                          label: Text('Rentang'),
                          icon: Icon(Icons.date_range_outlined),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (v) =>
                          setState(() => _mode = v.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Filter: Per Minggu ─────────────────────────────────────────────
            if (_mode == _ExportMode.weekly)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Minggu',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          IconButton.outlined(
                            onPressed: () => setState(
                              () => _weekStart = _weekStart.subtract(
                                const Duration(days: 7),
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left),
                            tooltip: 'Minggu sebelumnya',
                          ),
                          Expanded(
                            child: Text(
                              '${_fmtShort(_weekStart)}  –  ${_fmtShort(_weekStart.add(const Duration(days: 6)))}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton.outlined(
                            onPressed: () => setState(
                              () => _weekStart = _weekStart.add(
                                const Duration(days: 7),
                              ),
                            ),
                            icon: const Icon(Icons.chevron_right),
                            tooltip: 'Minggu berikutnya',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Filter: Per Bulan ──────────────────────────────────────────────
            if (_mode == _ExportMode.monthly)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih Bulan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedMonth,
                              decoration: const InputDecoration(
                                labelText: 'Bulan',
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_months[i]),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _selectedMonth = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _YearPicker(
                              value: _selectedYear,
                              onChanged: (v) =>
                                  setState(() => _selectedYear = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // ── Filter: Rentang Bulan ──────────────────────────────────────────
            if (_mode == _ExportMode.monthRange)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dari Bulan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _rangeFromMonth,
                              decoration: const InputDecoration(
                                labelText: 'Bulan',
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_months[i]),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _rangeFromMonth = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _YearPicker(
                              value: _rangeFromYear,
                              onChanged: (v) =>
                                  setState(() => _rangeFromYear = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sampai Bulan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _rangeToMonth,
                              decoration: const InputDecoration(
                                labelText: 'Bulan',
                              ),
                              items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(_months[i]),
                                ),
                              ),
                              onChanged: (v) =>
                                  setState(() => _rangeToMonth = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _YearPicker(
                              value: _rangeToYear,
                              onChanged: (v) =>
                                  setState(() => _rangeToYear = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // ── Info file & tombol export ──────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File yang akan dibuat (.xlsx)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Sheet 1 — Ringkasan transaksi'),
                    const Text('• Sheet 2 — Detail item per transaksi'),
                    const Text('• Sheet 3 — Rekap omzet per hari'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _exporting ? null : _doExport,
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_outlined),
                        label: Text(
                          _exporting ? 'Mengekspor...' : 'Export Excel',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    return DropdownButtonFormField<int>(
      value: value,
      decoration: const InputDecoration(labelText: 'Tahun'),
      items: List.generate(
        5,
        (i) => DropdownMenuItem(value: now - i, child: Text('${now - i}')),
      ),
      onChanged: (v) => onChanged(v!),
    );
  }
}

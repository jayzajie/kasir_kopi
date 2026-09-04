import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/pos_controller.dart';
import 'core/currency.dart';
import 'models/accounting.dart';
import 'models/cart_item.dart';
import 'models/product.dart';
import 'services/receipt_printer.dart';

const _brown = Color(0xff4b2a17);

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

int _money(String value) => int.parse(value.replaceAll(RegExp(r'\D'), ''));
String _quantity(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');

class RecipeHppPage extends StatefulWidget {
  const RecipeHppPage(this.controller, {super.key});
  final PosController controller;

  @override
  State<RecipeHppPage> createState() => _RecipeHppPageState();
}

class _RecipeHppPageState extends State<RecipeHppPage> {
  var ingredients = <IngredientCost>[];
  final recipes = <int, List<RecipeLine>>{};
  var loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    ingredients = await widget.controller.ingredients();
    recipes.clear();
    for (final product in widget.controller.products) {
      recipes[product.id] = await widget.controller.recipe(product);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> editIngredient([IngredientCost? ingredient]) async {
    final result = await showDialog<IngredientCost>(
      context: context,
      builder: (_) => _IngredientDialog(ingredient),
    );
    if (result == null) return;
    await widget.controller.saveIngredient(result);
    await load();
  }

  Future<void> editRecipe(Product product) async {
    if (ingredients.isEmpty) return;
    final quantities = await showDialog<Map<String, double>>(
      context: context,
      builder: (_) => _RecipeDialog(
        product: product,
        ingredients: ingredients,
        recipe: recipes[product.id] ?? const [],
      ),
    );
    if (quantities == null) return;
    await widget.controller.saveRecipe(product, quantities);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Resep & HPP')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.calculate_outlined, color: _brown),
                  title: Text('HPP dihitung otomatis'),
                  subtitle: Text(
                    'Harga bahan per kemasan ÷ isi kemasan × pemakaian di resep.',
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Harga bahan baku',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: editIngredient,
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: ingredients
                      .map(
                        (item) => ListTile(
                          onTap: () => editIngredient(item),
                          title: Text(item.name),
                          subtitle: Text(
                            '${rupiah(item.purchasePrice)} / ${_quantity(item.packageQuantity)} ${item.unit} '
                            '• ${rupiah(item.unitCost.round())}/${item.unit}',
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'HPP dan margin menu',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (widget.controller.products.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('Belum ada menu untuk dibuatkan resep.'),
                  ),
                ),
              ...widget.controller.products.map((product) {
                final lines = recipes[product.id] ?? const <RecipeLine>[];
                final margin = product.price - product.cost;
                final percent = product.price == 0
                    ? 0
                    : margin * 100 / product.price;
                final safe = margin >= 0;
                return Card(
                  child: ExpansionTile(
                    title: Text(product.name),
                    subtitle: Text(
                      'HPP ${rupiah(product.cost)} • Margin ${rupiah(margin)} (${percent.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        color: safe ? Colors.green.shade700 : Colors.red,
                      ),
                    ),
                    children: [
                      if (lines.isEmpty)
                        const ListTile(
                          title: Text('Resep belum diatur'),
                          subtitle: Text(
                            'HPP manual masih dipakai sampai resep disimpan.',
                          ),
                        ),
                      ...lines.map(
                        (line) => ListTile(
                          dense: true,
                          title: Text(line.ingredientName),
                          subtitle: Text(
                            '${_quantity(line.quantity)} ${line.unit}',
                          ),
                          trailing: Text(rupiah(line.cost)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => editRecipe(product),
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('Atur Resep'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
  );
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog(this.ingredient);
  final IngredientCost? ingredient;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name, price, package, minimum;
  late String unit;

  @override
  void initState() {
    super.initState();
    final item = widget.ingredient;
    name = TextEditingController(text: item?.name);
    price = TextEditingController(text: item?.purchasePrice.toString());
    package = TextEditingController(text: item?.packageQuantity.toString());
    minimum = TextEditingController(text: item?.minimum.toString() ?? '0');
    unit = item?.unit ?? 'gram';
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    package.dispose();
    minimum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.ingredient == null ? 'Tambah Bahan' : 'Ubah Harga Bahan',
    ),
    content: Form(
      key: key,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: name,
              enabled: widget.ingredient == null,
              decoration: const InputDecoration(labelText: 'Nama bahan'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: unit,
              decoration: const InputDecoration(labelText: 'Satuan stok/resep'),
              items: const ['gram', 'ml', 'pcs']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: widget.ingredient == null
                  ? (value) => setState(() => unit = value!)
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Harga beli kemasan',
                prefixText: 'Rp ',
              ),
              validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Harus lebih dari 0'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: package,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Isi kemasan ($unit)'),
              validator: (value) =>
                  (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <=
                      0
                  ? 'Harus lebih dari 0'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: minimum,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Batas stok minimum ($unit)',
              ),
              validator: (value) =>
                  double.tryParse((value ?? '').replaceAll(',', '.')) == null
                  ? 'Masukkan angka'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          Navigator.pop(
            context,
            IngredientCost(
              name: name.text.trim(),
              unit: unit,
              purchasePrice: int.parse(price.text),
              packageQuantity: double.parse(package.text.replaceAll(',', '.')),
              quantity: widget.ingredient?.quantity ?? 0,
              minimum: double.parse(minimum.text.replaceAll(',', '.')),
            ),
          );
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _RecipeDialog extends StatefulWidget {
  const _RecipeDialog({
    required this.product,
    required this.ingredients,
    required this.recipe,
  });
  final Product product;
  final List<IngredientCost> ingredients;
  final List<RecipeLine> recipe;

  @override
  State<_RecipeDialog> createState() => _RecipeDialogState();
}

class _RecipeDialogState extends State<_RecipeDialog> {
  late final Map<String, TextEditingController> quantities;

  @override
  void initState() {
    super.initState();
    final current = {
      for (final line in widget.recipe) line.ingredientName: line.quantity,
    };
    quantities = {
      for (final item in widget.ingredients)
        item.name: TextEditingController(
          text: current[item.name]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in quantities.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Resep ${widget.product.name}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.ingredients
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: quantities[item.name],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: item.name,
                    suffixText: item.unit,
                    helperText: '${rupiah(item.unitCost.round())}/${item.unit}',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          for (final entry in quantities.entries)
            entry.key:
                double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0,
        }),
        child: const Text('Hitung & Simpan'),
      ),
    ],
  );
}

class ExpensesPage extends StatefulWidget {
  const ExpensesPage(this.controller, {super.key});
  final PosController controller;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  var records = <ExpenseRecord>[];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    records = await widget.controller.expenses();
    if (mounted) setState(() {});
  }

  Future<void> add() async {
    final result = await showDialog<(String, String, int)>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (result == null) return;
    await widget.controller.addExpense(result.$1, result.$2, result.$3);
    await load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengeluaran')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: add,
      icon: const Icon(Icons.add),
      label: const Text('Catat Pengeluaran'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.wallet_outlined, color: _brown),
            title: const Text('Pengeluaran hari ini'),
            subtitle: Text(
              rupiah(widget.controller.todayExpense),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (records.isEmpty)
          const Card(child: ListTile(title: Text('Belum ada pengeluaran.'))),
        ...records.map(
          (record) => Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(record.description),
              subtitle: Text('${record.category} • ${_date(record.createdAt)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rupiah(record.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    onPressed: () async {
                      await widget.controller.deleteExpense(record.id);
                      await load();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final key = GlobalKey<FormState>();
  final description = TextEditingController(), amount = TextEditingController();
  String category = 'Bahan';

  @override
  void dispose() {
    description.dispose();
    amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Catat Pengeluaran'),
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: const ['Bahan', 'Listrik', 'Gas', 'Sewa', 'Gaji', 'Lainnya']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => category = value!,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Keterangan'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Jumlah',
              prefixText: 'Rp ',
            ),
            validator: (value) =>
                (_money(value ?? '0')) <= 0 ? 'Harus lebih dari 0' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          Navigator.pop(context, (
            category,
            description.text.trim(),
            _money(amount.text),
          ));
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class InventoryPage extends StatefulWidget {
  const InventoryPage(this.controller, {super.key});
  final PosController controller;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  var ingredients = <IngredientCost>[];
  var loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    ingredients = await widget.controller.ingredients();
    if (mounted) setState(() => loading = false);
  }

  Future<void> addIngredient([IngredientCost? current]) async {
    final result = await showDialog<IngredientCost>(
      context: context,
      builder: (_) => _IngredientDialog(current),
    );
    if (result == null) return;
    await widget.controller.saveIngredient(result);
    await load();
  }

  Future<void> purchase() async {
    final result = await showDialog<(String, double, double, int)>(
      context: context,
      builder: (_) => _PurchaseDialog(ingredients),
    );
    if (result == null) return;
    await widget.controller.addPurchase(
      name: result.$1,
      packages: result.$2,
      packageQuantity: result.$3,
      packagePrice: result.$4,
    );
    await load();
  }

  Future<void> adjust() async {
    final result = await showDialog<(String, double, String)>(
      context: context,
      builder: (_) => _AdjustmentDialog(ingredients),
    );
    if (result == null) return;
    await widget.controller.adjustStock(
      name: result.$1,
      change: result.$2,
      reason: result.$3,
    );
    await load();
  }

  Future<void> stocktake() async {
    final result = await showDialog<(String, double)>(
      context: context,
      builder: (_) => _StocktakeDialog(ingredients),
    );
    if (result == null) return;
    await widget.controller.stocktake(result.$1, result.$2);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final low = ingredients
        .where((item) => item.minimum > 0 && item.quantity <= item.minimum)
        .length;
    final value = ingredients.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.unitCost,
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 24, 22, 14),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inventory',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: _brown,
                  ),
                ),
                Text('Stok bahan, pembelian, pemakaian, dan opname.'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: _StockMetric('Nilai Stok', rupiah(value.round())),
              ),
              Expanded(child: _StockMetric('Stok Rendah', '$low')),
              Expanded(
                child: _StockMetric(
                  'Bahan Habis',
                  '${ingredients.where((item) => item.quantity == 0).length}',
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: ingredients.isEmpty ? null : purchase,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Stok Masuk'),
              ),
              OutlinedButton.icon(
                onPressed: ingredients.isEmpty ? null : adjust,
                icon: const Icon(Icons.tune),
                label: const Text('Penyesuaian'),
              ),
              OutlinedButton.icon(
                onPressed: ingredients.isEmpty ? null : stocktake,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Stok Opname'),
              ),
              IconButton.outlined(
                onPressed: addIngredient,
                tooltip: 'Tambah bahan',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  children: ingredients.map((item) {
                    final isLow =
                        item.minimum > 0 && item.quantity <= item.minimum;
                    return Card(
                      child: ExpansionTile(
                        leading: Icon(
                          isLow
                              ? Icons.warning_amber
                              : Icons.inventory_2_outlined,
                          color: isLow ? Colors.red : _brown,
                        ),
                        title: Text(item.name),
                        subtitle: Text(
                          '${_quantity(item.quantity)} ${item.unit} • minimum ${_quantity(item.minimum)} ${item.unit}\n'
                          'Nilai ${rupiah((item.quantity * item.unitCost).round())}',
                          style: TextStyle(color: isLow ? Colors.red : null),
                        ),
                        children: [
                          ListTile(
                            dense: true,
                            title: const Text('Harga bahan'),
                            subtitle: Text(
                              '${rupiah(item.purchasePrice)} / ${_quantity(item.packageQuantity)} ${item.unit}',
                            ),
                            trailing: IconButton(
                              onPressed: () => addIngredient(item),
                              tooltip: 'Ubah bahan',
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ),
                          FutureBuilder<List<StockMovement>>(
                            future: widget.controller.stockMovements(item.name),
                            builder: (_, snapshot) {
                              final movements =
                                  snapshot.data ?? const <StockMovement>[];
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (movements.isEmpty) {
                                return const ListTile(
                                  title: Text('Belum ada riwayat stok.'),
                                );
                              }
                              return Column(
                                children: movements
                                    .map(
                                      (movement) => ListTile(
                                        dense: true,
                                        title: Text(movement.type),
                                        subtitle: Text(
                                          '${movement.reason} • ${_date(movement.createdAt)}',
                                        ),
                                        trailing: Text(
                                          '${movement.quantity > 0 ? '+' : ''}${_quantity(movement.quantity)} ${item.unit}',
                                          style: TextStyle(
                                            color: movement.quantity > 0
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _StockMetric extends StatelessWidget {
  const _StockMetric(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog(this.ingredients);
  final List<IngredientCost> ingredients;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  final key = GlobalKey<FormState>();
  final packages = TextEditingController(text: '1');
  late final TextEditingController packageQuantity, price;
  late IngredientCost selected;

  @override
  void initState() {
    super.initState();
    selected = widget.ingredients.first;
    packageQuantity = TextEditingController(
      text: _quantity(selected.packageQuantity),
    );
    price = TextEditingController(text: selected.purchasePrice.toString());
  }

  void select(IngredientCost item) {
    setState(() {
      selected = item;
      packageQuantity.text = _quantity(item.packageQuantity);
      price.text = item.purchasePrice.toString();
    });
  }

  @override
  void dispose() {
    packages.dispose();
    packageQuantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Stok Masuk & Pembelian'),
    content: Form(
      key: key,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<IngredientCost>(
              initialValue: selected,
              decoration: const InputDecoration(labelText: 'Bahan'),
              items: widget.ingredients
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.name)),
                  )
                  .toList(),
              onChanged: (value) => select(value!),
            ),
            const SizedBox(height: 12),
            _numberField(packages, 'Jumlah kemasan'),
            const SizedBox(height: 12),
            _numberField(packageQuantity, 'Isi per kemasan (${selected.unit})'),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Harga per kemasan',
                prefixText: 'Rp ',
              ),
              validator: _positiveNumber,
            ),
            const SizedBox(height: 8),
            const Text('Pembelian ini otomatis masuk ke Pengeluaran.'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          Navigator.pop(context, (
            selected.name,
            _decimal(packages.text),
            _decimal(packageQuantity.text),
            int.parse(price.text),
          ));
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _AdjustmentDialog extends StatefulWidget {
  const _AdjustmentDialog(this.ingredients);
  final List<IngredientCost> ingredients;

  @override
  State<_AdjustmentDialog> createState() => _AdjustmentDialogState();
}

class _AdjustmentDialogState extends State<_AdjustmentDialog> {
  final key = GlobalKey<FormState>();
  final quantity = TextEditingController();
  late IngredientCost selected;
  String reason = 'Rusak/tumpah';

  @override
  void initState() {
    super.initState();
    selected = widget.ingredients.first;
  }

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Penyesuaian Stok'),
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<IngredientCost>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Bahan'),
            items: widget.ingredients
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() => selected = value!),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Alasan'),
            items: const ['Rusak/tumpah', 'Dipakai sendiri', 'Koreksi tambah']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => reason = value!,
          ),
          const SizedBox(height: 12),
          _numberField(quantity, 'Jumlah (${selected.unit})'),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          final amount = _decimal(quantity.text);
          Navigator.pop(context, (
            selected.name,
            reason == 'Koreksi tambah' ? amount : -amount,
            reason,
          ));
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}

class _StocktakeDialog extends StatefulWidget {
  const _StocktakeDialog(this.ingredients);
  final List<IngredientCost> ingredients;

  @override
  State<_StocktakeDialog> createState() => _StocktakeDialogState();
}

class _StocktakeDialogState extends State<_StocktakeDialog> {
  final key = GlobalKey<FormState>();
  final actual = TextEditingController();
  late IngredientCost selected;

  @override
  void initState() {
    super.initState();
    selected = widget.ingredients.first;
    actual.text = _quantity(selected.quantity);
  }

  @override
  void dispose() {
    actual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Stok Opname'),
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<IngredientCost>(
            initialValue: selected,
            decoration: const InputDecoration(labelText: 'Bahan'),
            items: widget.ingredients
                .map(
                  (item) =>
                      DropdownMenuItem(value: item, child: Text(item.name)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              selected = value!;
              actual.text = _quantity(value.quantity);
            }),
          ),
          const SizedBox(height: 12),
          _numberField(
            actual,
            'Stok fisik (${selected.unit})',
            allowZero: true,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (!key.currentState!.validate()) return;
          Navigator.pop(context, (selected.name, _decimal(actual.text)));
        },
        child: const Text('Simpan Selisih'),
      ),
    ],
  );
}

double _decimal(String value) => double.parse(value.replaceAll(',', '.'));

String? _positiveNumber(String? value) =>
    (double.tryParse((value ?? '').replaceAll(',', '.')) ?? 0) <= 0
    ? 'Harus lebih dari 0'
    : null;

TextFormField _numberField(
  TextEditingController controller,
  String label, {
  bool allowZero = false,
}) => TextFormField(
  controller: controller,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  decoration: InputDecoration(labelText: label),
  validator: (value) {
    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
    return number == null || (allowZero ? number < 0 : number <= 0)
        ? allowZero
              ? 'Tidak boleh negatif'
              : 'Harus lebih dari 0'
        : null;
  },
);

class TransactionHistoryPage extends StatelessWidget {
  const TransactionHistoryPage(this.controller, {super.key});
  final PosController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Riwayat Transaksi')),
    body: controller.orders.isEmpty
        ? const Center(child: Text('Belum ada transaksi.'))
        : ListView(
            padding: const EdgeInsets.all(14),
            children: controller.orders
                .map(
                  (sale) => Card(
                    child: ExpansionTile(
                      title: Text(sale.number),
                      subtitle: Text(
                        '${sale.customer} • ${sale.paymentMethod}\n${_date(sale.createdAt)}',
                      ),
                      trailing: Text(
                        rupiah(sale.total),
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
                            final profit = lines.fold<int>(
                              0,
                              (sum, line) => sum + line.grossProfit,
                            );
                            final items = lines
                                .map(
                                  (line) => CartItem(
                                    Product(
                                      line.productName,
                                      line.unitPrice,
                                      '',
                                      cost: line.unitCost,
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
                                    trailing: Text(rupiah(line.total)),
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Laba kotor transaksi'),
                                  trailing: Text(
                                    rupiah(profit),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
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
  );
}

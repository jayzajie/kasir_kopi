class SaleLine {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.extra,
    required this.options,
    required this.note,
  });

  final String productName, options, note;
  final int quantity, unitPrice, extra;
  int get total => (unitPrice + extra) * quantity;

  factory SaleLine.fromMap(Map<String, Object?> map) => SaleLine(
    productName: map['product_name'] as String,
    quantity: map['quantity'] as int,
    unitPrice: map['unit_price'] as int,
    extra: map['extra'] as int,
    options: map['options'] as String,
    note: map['note'] as String,
  );
}

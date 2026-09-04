class IngredientCost {
  const IngredientCost({
    required this.name,
    required this.unit,
    required this.purchasePrice,
    required this.packageQuantity,
    this.quantity = 0,
    this.minimum = 0,
  });

  final String name, unit;
  final int purchasePrice;
  final double packageQuantity, quantity, minimum;

  double get unitCost =>
      packageQuantity == 0 ? 0 : purchasePrice / packageQuantity;

  factory IngredientCost.fromMap(Map<String, Object?> map) => IngredientCost(
    name: map['name'] as String,
    unit: map['unit'] as String,
    purchasePrice: (map['purchase_price'] as num).round(),
    packageQuantity: (map['package_quantity'] as num).toDouble(),
    quantity: (map['quantity'] as num).toDouble(),
    minimum: (map['minimum'] as num).toDouble(),
  );
}

class StockMovement {
  const StockMovement({
    required this.type,
    required this.quantity,
    required this.reason,
    required this.createdAt,
  });

  final String type, reason;
  final double quantity;
  final DateTime createdAt;

  factory StockMovement.fromMap(Map<String, Object?> map) => StockMovement(
    type: map['type'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    reason: map['reason'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

class RecipeLine {
  const RecipeLine({
    required this.ingredientName,
    required this.quantity,
    required this.unit,
    required this.cost,
  });

  final String ingredientName, unit;
  final double quantity;
  final int cost;

  factory RecipeLine.fromMap(Map<String, Object?> map) => RecipeLine(
    ingredientName: map['ingredient_name'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    unit: map['unit'] as String,
    cost: (map['cost'] as num).round(),
  );
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  final int id, amount;
  final String category, description;
  final DateTime createdAt;

  factory ExpenseRecord.fromMap(Map<String, Object?> map) => ExpenseRecord(
    id: map['id'] as int,
    category: map['category'] as String,
    description: map['description'] as String,
    amount: map['amount'] as int,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

class SaleLine {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.extra,
    required this.options,
    required this.note,
  });

  final String productName, options, note;
  final int quantity, unitPrice, unitCost, extra;
  int get total => (unitPrice + extra) * quantity;
  int get grossProfit => (unitPrice + extra - unitCost) * quantity;

  factory SaleLine.fromMap(Map<String, Object?> map) => SaleLine(
    productName: map['product_name'] as String,
    quantity: map['quantity'] as int,
    unitPrice: map['unit_price'] as int,
    unitCost: map['unit_cost'] as int,
    extra: map['extra'] as int,
    options: map['options'] as String,
    note: map['note'] as String,
  );
}

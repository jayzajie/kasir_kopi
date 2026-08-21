class Product {
  Product(
    this.name,
    this.price,
    this.category, {
    this.id = 0,
    this.cost = 0,
    this.available = true,
  });

  final int id;
  final String name;
  final String category;
  final int price;
  final int cost;
  bool available;

  factory Product.fromMap(Map<String, Object?> map) => Product(
    map['name'] as String,
    map['price'] as int,
    map['category'] as String,
    id: map['id'] as int,
    cost: map['cost'] as int,
    available: (map['available'] as int) == 1,
  );
}

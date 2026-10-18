import 'dart:convert';
import 'dart:typed_data';

class ProductAddon {
  const ProductAddon(this.name, this.price);

  final String name;
  final int price;

  Map<String, Object> toMap() => {'name': name, 'price': price};

  factory ProductAddon.fromMap(Map<String, Object?> map) =>
      ProductAddon(map['name'] as String, (map['price'] as num).round());
}

const kDefaultSyrups = ['Caramel', 'Vanilla', 'Gula Aren'];

class Product {
  Product(
    this.name,
    this.price,
    this.category, {
    this.id = 0,
    this.available = true,
    this.iceOption = 'Normal Ice',
    this.sugarOption = 'Normal Sugar',
    this.image,
    this.addons = const [],
    List<String>? syrups,
  }) : syrups = syrups ?? List.of(kDefaultSyrups);

  final int id;
  String name;
  String category;
  int price;
  bool available;
  String iceOption;
  String sugarOption;
  Uint8List? image;
  List<ProductAddon> addons;
  /// Daftar pilihan syrup yang muncul di halaman kustomisasi kopi.
  List<String> syrups;

  String get addonsJson =>
      jsonEncode(addons.map((addon) => addon.toMap()).toList());

  String get syrupsJson => jsonEncode(syrups);

  factory Product.fromMap(Map<String, Object?> map) {
    final syrupsRaw = map['syrups_json'] as String?;
    List<String> syrups;
    if (syrupsRaw != null && syrupsRaw.isNotEmpty) {
      syrups = (jsonDecode(syrupsRaw) as List).cast<String>();
    } else {
      syrups = List.of(kDefaultSyrups);
    }
    return Product(
      map['name'] as String,
      map['price'] as int,
      map['category'] as String,
      id: map['id'] as int,
      available: (map['available'] as int) == 1,
      iceOption: map['ice_option'] as String,
      sugarOption: map['sugar_option'] as String,
      image: map['image'] as Uint8List?,
      addons: (jsonDecode(map['addons_json'] as String) as List)
          .map((value) => ProductAddon.fromMap(Map<String, Object?>.from(value)))
          .toList(),
      syrups: syrups,
    );
  }
}

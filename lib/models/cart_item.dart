import 'product.dart';

class CartItem {
  CartItem(
    this.product, {
    this.qty = 1,
    this.extra = 0,
    this.note = '',
    this.options = '',
  });

  final Product product;
  int qty;
  int extra;
  String note;
  String options;

  int get total => (product.price + extra) * qty;

  CartItem copy() =>
      CartItem(product, qty: qty, extra: extra, note: note, options: options);
}

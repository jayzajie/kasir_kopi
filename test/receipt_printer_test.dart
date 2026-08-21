import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/models/cart_item.dart';
import 'package:kasir_kopi/models/product.dart';
import 'package:kasir_kopi/services/receipt_printer.dart';

void main() {
  test('ESC/POS receipt contains init, customer, total, feed, and cut', () {
    final bytes = const ReceiptPrinter().buildEscPos(
      transactionNumber: 'TRX-001',
      paymentMethod: 'Tunai',
      customerName: 'Budi',
      transactionTime: DateTime(2026, 8, 19, 10, 24),
      items: [CartItem(Product('Es Latte', 28000, 'Kopi'))],
    );
    final text = String.fromCharCodes(bytes);

    expect(bytes.take(2), [0x1b, 0x40]);
    expect(text, contains('Pembeli : Budi'));
    expect(text, contains('TOTAL'));
    expect(bytes.sublist(bytes.length - 6), [0x1b, 0x64, 4, 0x1d, 0x56, 1]);
  });
}

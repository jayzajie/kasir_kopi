import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/models/cart_item.dart';
import 'package:kasir_kopi/models/product.dart';
import 'package:kasir_kopi/services/receipt_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ESC/POS receipt contains logo, customer, total, feed, and cut',
    () async {
      final logo = (await rootBundle.load(
        'logo_karsa.png',
      )).buffer.asUint8List();
      final bytes = const ReceiptPrinter().buildEscPos(
        transactionNumber: 'TRX-001',
        paymentMethod: 'Tunai',
        customerName: 'Budi',
        transactionTime: DateTime(2026, 8, 19, 10, 24),
        items: [CartItem(Product('Es Latte', 28000, 'Kopi'))],
        logoBytes: logo,
      );
      final text = String.fromCharCodes(bytes);

      expect(bytes.take(2), [0x1b, 0x40]);
      expect(text, contains('Pembeli : Budi'));
      expect(bytes, containsAllInOrder([0x1d, 0x76, 0x30, 0]));
      expect(text, contains('TOTAL'));
      expect(bytes.sublist(bytes.length - 6), [0x1b, 0x64, 2, 0x1d, 0x56, 1]);
    },
  );

  test('receipt printing builds a PDF document', () async {
    final bytes = await const ReceiptPrinter().buildPdf(
      transactionNumber: 'TRX-002',
      paymentMethod: 'QRIS',
      customerName: 'Sari',
      transactionTime: DateTime(2026, 8, 27, 14, 30),
      items: [CartItem(Product('Kopi Susu', 24000, 'Kopi'))],
    );

    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildEscPosFromRgba converts PDF raster RGBA into ESC/POS GS v 0 bands', () {
    // 16x4 RGBA bitmap with transparent white (R=255,G=255,B=255,A=0) top/bottom
    // and black ink (R=0,G=0,B=0,A=255) in middle rows
    final rgba = Uint8List(16 * 4 * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 255;
      rgba[i + 1] = 255;
      rgba[i + 2] = 255;
      rgba[i + 3] = 0;
    }
    // Set pixel (0, 1) and (8, 2) to black ink
    final row1Pixel0 = (1 * 16 + 0) * 4;
    rgba[row1Pixel0] = 0;
    rgba[row1Pixel0 + 1] = 0;
    rgba[row1Pixel0 + 2] = 0;
    rgba[row1Pixel0 + 3] = 255;

    final row2Pixel8 = (2 * 16 + 8) * 4;
    rgba[row2Pixel8] = 0;
    rgba[row2Pixel8 + 1] = 0;
    rgba[row2Pixel8 + 2] = 0;
    rgba[row2Pixel8 + 3] = 255;

    final escPos = const ReceiptPrinter().buildEscPosFromRgba(
      rgbaPixels: rgba,
      width: 16,
      height: 4,
    );

    // Starts with ESC @ and ESC a 1, followed by GS v 0 header for 2 cropped rows
    expect(escPos.take(5), [0x1b, 0x40, 0x1b, 0x61, 1]);
    expect(escPos.sublist(5, 13), [0x1d, 0x76, 0x30, 0, 2, 0, 2, 0]);
    expect(escPos.sublist(escPos.length - 6), [0x1b, 0x64, 3, 0x1d, 0x56, 1]);
  });
}

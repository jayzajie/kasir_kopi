import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

import '../core/currency.dart';
import '../models/cart_item.dart';
import 'printer_manager.dart';

class ReceiptPrinter {
  const ReceiptPrinter();

  Future<void> print({
    required String transactionNumber,
    required String paymentMethod,
    required String customerName,
    required DateTime transactionTime,
    required List<CartItem> items,
  }) async {
    final selected = PrinterManager.instance.selectedPrinter;
    final rawWindows = defaultTargetPlatform == TargetPlatform.windows;
    final rawBluetooth =
        defaultTargetPlatform == TargetPlatform.android &&
        selected?.url.startsWith('bt://') == true;
    if (selected != null && (rawWindows || rawBluetooth)) {
      await PrinterManager.instance.rawPrint(
        printerName: selected.url.replaceFirst('bt://', ''),
        documentName: 'Struk $transactionNumber',
        data: buildEscPos(
          transactionNumber: transactionNumber,
          paymentMethod: paymentMethod,
          customerName: customerName,
          transactionTime: transactionTime,
          items: items,
        ),
      );
      return;
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.total);
    const page = PdfPageFormat.roll80;
    final date = _dateTime(transactionTime);
    final regular = pw.TextStyle(fontSize: 9);
    final small = pw.TextStyle(fontSize: 7.5, color: PdfColors.grey800);
    pw.Widget line([double height = 1]) => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
      height: height,
      color: PdfColors.black,
    );
    pw.Widget detail(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 72, child: pw.Text(label, style: regular)),
          pw.Expanded(child: pw.Text(value, style: regular)),
        ],
      ),
    );
    final document = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: page,
          margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'KOPI KITA',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              pw.Text(
                'COFFEE SHOP',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 9, letterSpacing: 1),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Jl. Kopi Nikmat No. 17',
                textAlign: pw.TextAlign.center,
                style: small,
              ),
              pw.Text(
                'Terima kasih sudah berkunjung',
                textAlign: pw.TextAlign.center,
                style: small,
              ),
              line(1.5),
              detail('No. Transaksi', transactionNumber),
              detail('Tanggal', date),
              detail('Pembeli', customerName),
              detail('Pembayaran', paymentMethod),
              line(),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'PESANAN',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    'JUMLAH',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '${item.qty}x  ${item.product.name}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Text(rupiah(item.total), style: regular),
                        ],
                      ),
                      if (item.options.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 17, top: 1),
                          child: pw.Text(item.options, style: small),
                        ),
                      if (item.note.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 17, top: 1),
                          child: pw.Text('Catatan: ${item.note}', style: small),
                        ),
                    ],
                  ),
                ),
              ),
              line(),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Subtotal', style: regular)),
                  pw.Text(rupiah(total), style: regular),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Diskon', style: regular)),
                  pw.Text('- Rp 0', style: regular),
                ],
              ),
              pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('Pajak', style: regular)),
                  pw.Text('Rp 0', style: regular),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'TOTAL',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    rupiah(total),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              line(1.5),
              pw.Text(
                'Terima kasih, $customerName!',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Selamat menikmati kopi terbaik Anda.',
                textAlign: pw.TextAlign.center,
                style: small,
              ),
              pw.Text(
                'Instagram: @kopikita',
                textAlign: pw.TextAlign.center,
                style: small,
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                '--- POTONG DI SINI ---',
                textAlign: pw.TextAlign.center,
                style: small,
              ),
            ],
          ),
        ),
      );

    Future<Uint8List> onLayout(PdfPageFormat _) => document.save();
    if (selected != null) {
      await Printing.directPrintPdf(
        printer: selected,
        name: 'Struk $transactionNumber',
        format: page,
        usePrinterSettings: true,
        onLayout: onLayout,
      );
    } else {
      await Printing.layoutPdf(
        name: 'Struk $transactionNumber',
        format: page,
        onLayout: onLayout,
      );
    }
  }

  String _dateTime(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }

  Uint8List buildEscPos({
    required String transactionNumber,
    required String paymentMethod,
    required String customerName,
    required DateTime transactionTime,
    required List<CartItem> items,
  }) {
    const width = 32;
    final bytes = BytesBuilder();
    void command(List<int> value) => bytes.add(value);
    void text(String value) => bytes.add(
      value
          .replaceAll('•', ',')
          .replaceAll('–', '-')
          .codeUnits
          .map((c) => c < 128 ? c : 63)
          .toList(),
    );
    void wrapped(String value, {String prefix = ''}) {
      final words = value.trim().split(RegExp(r'\s+'));
      var line = prefix;
      for (final word in words) {
        if (line.isNotEmpty && line.length + word.length + 1 > width) {
          text('${line.trimRight()}\n');
          line = '${' ' * prefix.length}$word ';
        } else {
          line += '$word ';
        }
      }
      if (line.trim().isNotEmpty) text('${line.trimRight()}\n');
    }

    String columns(String left, String right) {
      final safeLeft = left.length > width - right.length - 1
          ? left.substring(0, width - right.length - 1)
          : left;
      return '$safeLeft${' ' * (width - safeLeft.length - right.length)}$right\n';
    }

    final total = items.fold<int>(0, (sum, item) => sum + item.total);
    command([0x1b, 0x40]);
    command([0x1b, 0x61, 1]);
    command([0x1b, 0x45, 1]);
    command([0x1d, 0x21, 0x11]);
    text('KOPI KITA\n');
    command([0x1d, 0x21, 0]);
    command([0x1b, 0x45, 0]);
    text('COFFEE SHOP\n');
    text('Jl. Kopi Nikmat No. 17\n');
    command([0x1b, 0x61, 0]);
    text('${'-' * width}\n');
    wrapped('No: $transactionNumber');
    text('Tanggal : ${_dateTime(transactionTime)}\n');
    wrapped('Pembeli : $customerName');
    text('Bayar   : $paymentMethod\n');
    text('${'-' * width}\n');
    for (final item in items) {
      command([0x1b, 0x45, 1]);
      wrapped('${item.qty}x ${item.product.name}');
      command([0x1b, 0x45, 0]);
      text(
        columns(
          '  ${item.qty} x ${rupiah(item.product.price + item.extra).replaceFirst('Rp ', '')}',
          rupiah(item.total).replaceFirst('Rp ', ''),
        ),
      );
      if (item.options.isNotEmpty) wrapped(item.options, prefix: '  ');
      if (item.note.isNotEmpty) wrapped('Catatan: ${item.note}', prefix: '  ');
    }
    text('${'-' * width}\n');
    text(columns('Subtotal', rupiah(total)));
    text(columns('Diskon', 'Rp 0'));
    command([0x1b, 0x45, 1]);
    command([0x1d, 0x21, 0x01]);
    text(columns('TOTAL', rupiah(total)));
    command([0x1d, 0x21, 0]);
    command([0x1b, 0x45, 0]);
    text('${'-' * width}\n');
    command([0x1b, 0x61, 1]);
    command([0x1b, 0x45, 1]);
    wrapped('Terima kasih, $customerName!');
    command([0x1b, 0x45, 0]);
    text('Selamat menikmati kopi Anda.\n');
    text('@kopikita\n');
    command([0x1b, 0x64, 4]);
    command([0x1d, 0x56, 1]);
    return bytes.toBytes();
  }
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../core/currency.dart';
import '../models/cart_item.dart';
import '../models/receipt_settings.dart';
import 'printer_manager.dart';

class ReceiptPrinter {
  const ReceiptPrinter();

  Future<void> print({
    required String transactionNumber,
    required String paymentMethod,
    required String customerName,
    required DateTime transactionTime,
    required List<CartItem> items,
    int orderNumber = 0,
    String orderType = 'Dine In',
    ReceiptSettings? settings,
  }) async {
    final s = settings ?? ReceiptSettings.current;
    var selected = PrinterManager.instance.selectedPrinter;
    if (selected == null) {
      try {
        final printers = await Printing.listPrinters();
        final defaultPrinter = printers.where((p) => p.isDefault).firstOrNull ?? printers.firstOrNull;
        if (defaultPrinter != null) {
          selected = defaultPrinter;
          PrinterManager.instance.selectedPrinter = defaultPrinter;
        }
      } catch (_) {}
    }

    final rawBluetooth =
        defaultTargetPlatform == TargetPlatform.android &&
        selected?.url.startsWith('bt://') == true;
    if (selected != null && rawBluetooth) {
      Uint8List? logo;
      try {
        logo = (await rootBundle.load('logo_karsa.png')).buffer.asUint8List();
      } catch (_) {}

      Uint8List? socialImage;
      try {
        socialImage = (await rootBundle.load('assets/social_karsa.png')).buffer.asUint8List();
      } catch (_) {}

      await PrinterManager.instance.rawPrint(
        printerName: selected.url.replaceFirst('bt://', ''),
        documentName: 'Struk $transactionNumber',
        data: buildEscPos(
          transactionNumber: transactionNumber,
          paymentMethod: paymentMethod,
          customerName: customerName,
          transactionTime: transactionTime,
          items: items,
          orderNumber: orderNumber,
          orderType: orderType,
          logoBytes: logo,
          socialBytes: socialImage,
          settings: s,
        ),
      );
      return;
    }

    final is58 = s.paperWidth == 58 ||
        selected?.name.toLowerCase().contains('58') == true ||
        selected?.model?.toLowerCase().contains('58') == true;
    final rollWidth = (is58 ? 48.0 : 72.0) * PdfPageFormat.mm;
    final estimatedHeight = _calculateHeightMm(s, items, orderNumber) * PdfPageFormat.mm;
    final page = PdfPageFormat(
      rollWidth,
      estimatedHeight,
      marginAll: 0,
    );

    Future<Uint8List> onLayout(PdfPageFormat _) => buildPdf(
      transactionNumber: transactionNumber,
      paymentMethod: paymentMethod,
      customerName: customerName,
      transactionTime: transactionTime,
      items: items,
      orderNumber: orderNumber,
      orderType: orderType,
      pageFormat: page,
      is58: is58,
      settings: s,
    );
    if (selected != null) {
      await Printing.directPrintPdf(
        printer: selected,
        name: 'Struk $transactionNumber',
        format: page,
        dynamicLayout: false,
        usePrinterSettings: true,
        onLayout: onLayout,
      );
    } else {
      await Printing.layoutPdf(
        name: 'Struk $transactionNumber',
        format: page,
        dynamicLayout: false,
        onLayout: onLayout,
      );
    }
  }

  Future<Uint8List> buildPdf({
    required String transactionNumber,
    required String paymentMethod,
    required String customerName,
    required DateTime transactionTime,
    required List<CartItem> items,
    int orderNumber = 0,
    String orderType = 'Dine In',
    PdfPageFormat? pageFormat,
    bool is58 = false,
    ReceiptSettings? settings,
  }) async {
    final s = settings ?? ReceiptSettings.current;
    final total = items.fold<int>(0, (sum, item) => sum + item.total);
    final logo = (await rootBundle.load('logo_karsa.png')).buffer.asUint8List();
    Uint8List? igLogo;
    try {
      igLogo = (await rootBundle.load('assets/instagram.png')).buffer.asUint8List();
    } catch (_) {}
    Uint8List? ttLogo;
    try {
      ttLogo = (await rootBundle.load('assets/tiktok.png')).buffer.asUint8List();
    } catch (_) {}

    final effectiveIs58 = s.paperWidth == 58 || is58;
    final rollWidth = (effectiveIs58 ? 48.0 : 72.0) * PdfPageFormat.mm;
    final estimatedHeight = _calculateHeightMm(s, items, orderNumber) * PdfPageFormat.mm;
    final page = pageFormat ??
        PdfPageFormat(
          rollWidth,
          estimatedHeight,
          marginAll: 0,
        );
    final date = _dateTime(transactionTime);
    final regular = pw.TextStyle(fontSize: effectiveIs58 ? 8 : 9);
    final small = pw.TextStyle(fontSize: effectiveIs58 ? 7 : 7.5, color: PdfColors.grey800);
    pw.Widget line([double height = 1]) => pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      height: height,
      color: PdfColors.black,
    );
    pw.Widget detail(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.SizedBox(width: effectiveIs58 ? 54 : 68, child: pw.Text(label, style: regular)),
          pw.Expanded(child: pw.Text(value, style: regular)),
        ],
      ),
    );

    final widgets = <pw.Widget>[];
    for (final block in s.blocks) {
      if (!block.enabled) continue;
      switch (block.type) {
        case BlockType.logo:
          widgets.add(pw.Center(
            child: pw.Image(pw.MemoryImage(logo), width: effectiveIs58 ? 95 : 130),
          ));
          widgets.add(pw.SizedBox(height: 3));
          break;
        case BlockType.orderNumber:
          if (orderNumber > 0) {
            widgets.add(pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'Order #$orderNumber',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ));
            widgets.add(pw.SizedBox(height: 4));
          }
          break;
        case BlockType.socialMedia:
          if (igLogo != null && ttLogo != null) {
            widgets.add(pw.Center(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Image(pw.MemoryImage(igLogo), width: 12, height: 12),
                      pw.SizedBox(width: 5),
                      pw.Text('@kopikarsa.co', style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Image(pw.MemoryImage(ttLogo), width: 12, height: 12),
                      pw.SizedBox(width: 5),
                      pw.Text('@kopikarsa', style: pw.TextStyle(fontSize: 9.0, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ));
          } else {
            widgets.add(pw.Text('IG: @kopikarsa.co', textAlign: pw.TextAlign.center, style: small));
            widgets.add(pw.Text('TT: @kopikarsa', textAlign: pw.TextAlign.center, style: small));
          }
          widgets.add(pw.SizedBox(height: 3));
          break;
        case BlockType.footerGreeting:
          widgets.add(pw.Text(
            'Terima kasih, $customerName!',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: effectiveIs58 ? 8.5 : 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ));
          widgets.add(pw.SizedBox(height: 2));
          widgets.add(pw.Text(
            block.text.isNotEmpty ? _cleanText(block.text) : 'Selamat menikmati kopi Anda.',
            textAlign: pw.TextAlign.center,
            style: small,
          ));
          break;
        case BlockType.text:
          if (block.text.trim().isNotEmpty) {
            pw.TextAlign align = pw.TextAlign.center;
            if (block.align == BlockAlign.left) align = pw.TextAlign.left;
            if (block.align == BlockAlign.right) align = pw.TextAlign.right;
            final isLong = block.text.trim().length > 25;
            final fontSize = block.isLarge
                ? (effectiveIs58 ? 10.0 : 12.0)
                : (isLong ? (effectiveIs58 ? 7.0 : 8.0) : (effectiveIs58 ? 8.0 : 9.0));
            widgets.add(pw.Text(
              _cleanText(block.text),
              textAlign: align,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: block.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ));
            widgets.add(pw.SizedBox(height: 2));
          }
          break;
        case BlockType.divider:
          widgets.add(line());
          break;
        case BlockType.transactionDetails:
          widgets.add(detail('No. Transaksi', transactionNumber));
          widgets.add(detail('Tanggal', date));
          if (s.showCustomerName) widgets.add(detail('Pembeli', customerName));
          if (s.showPaymentMethod) widgets.add(detail('Pembayaran', paymentMethod));
          widgets.add(pw.SizedBox(height: 5));
          widgets.add(pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                orderType.toUpperCase(),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ),
          ));
          break;
        case BlockType.itemsTable:
          for (final item in items) {
            widgets.add(pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${item.qty}x  ${item.product.name}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Text(rupiah(item.total), style: regular),
                    ],
                  ),
                  if (s.showItemDetails) ...[
                    if (item.options.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14, top: 1),
                        child: pw.Text(_cleanText(item.options), style: small),
                      ),
                    if (item.note.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 14, top: 1),
                        child: pw.Text('Catatan: ${_cleanText(item.note)}', style: small),
                      ),
                  ],
                ],
              ),
            ));
          }
          break;
        case BlockType.totalSummary:
          widgets.add(pw.Row(
            children: [
              pw.Expanded(child: pw.Text('Subtotal', style: regular)),
              pw.Text(rupiah(total), style: regular),
            ],
          ));
          widgets.add(pw.SizedBox(height: 3));
          widgets.add(pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Text(rupiah(total), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ],
          ));
          break;
        case BlockType.cutLine:
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('--- POTONG DI SINI ---', textAlign: pw.TextAlign.center, style: small));
          break;
      }
    }

    final document = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: page,
          margin: pw.EdgeInsets.symmetric(
            horizontal: effectiveIs58 ? 2 : 6,
            vertical: 2,
          ),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: widgets,
          ),
        ),
      );

    return document.save();
  }

  static String _cleanText(String value) {
    return value
        .replaceAll('•', ', ')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll(RegExp(r'\s+,\s+'), ', ')
        .trim();
  }

  double _calculateHeightMm(ReceiptSettings s, List<CartItem> items, int orderNumber) {
    double h = 4.0; // Minimal top & bottom margins
    for (final block in s.blocks) {
      if (!block.enabled) continue;
      switch (block.type) {
        case BlockType.logo:
          h += 15.0;
          break;
        case BlockType.orderNumber:
          if (orderNumber > 0) h += 7.0;
          break;
        case BlockType.socialMedia:
          h += 11.0;
          break;
        case BlockType.footerGreeting:
          h += 7.0;
          break;
        case BlockType.text:
          if (block.text.trim().isNotEmpty) h += 4.0;
          break;
        case BlockType.divider:
          h += 3.0;
          break;
        case BlockType.transactionDetails:
          int lines = 2; // No, Tanggal
          if (s.showCustomerName) lines++;
          if (s.showPaymentMethod) lines++;
          h += (lines * 3.5) + 10.0; // details + DINE IN badge
          break;
        case BlockType.itemsTable:
          for (final item in items) {
            h += 4.8; // name & price
            if (s.showItemDetails) {
              if (item.options.isNotEmpty) h += 3.8;
              if (item.note.isNotEmpty) h += 3.8;
            }
          }
          break;
        case BlockType.totalSummary:
          h += 10.0;
          break;
        case BlockType.cutLine:
          h += 6.0;
          break;
      }
    }
    return math.max(45.0, h + 3.0);
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
    int orderNumber = 0,
    String orderType = 'Dine In',
    Uint8List? logoBytes,
    Uint8List? socialBytes,
    ReceiptSettings? settings,
  }) {
    final s = settings ?? ReceiptSettings.current;
    final width = s.paperWidth == 80 ? 48 : 32;
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
    void setAlign(BlockAlign align) {
      switch (align) {
        case BlockAlign.center:
          command([0x1b, 0x61, 1]);
          break;
        case BlockAlign.right:
          command([0x1b, 0x61, 2]);
          break;
        case BlockAlign.left:
          command([0x1b, 0x61, 0]);
          break;
      }
    }

    void wrapped(String value, {String prefix = ''}) {
      final trimmed = value.trim();
      if (trimmed.length <= width) {
        text('$trimmed\n');
        return;
      }
      final words = trimmed.split(RegExp(r'\s+'));
      var line = prefix;
      for (final word in words) {
        final currentLen = line.trimRight().length;
        final needed = currentLen == 0 ? word.length : currentLen + 1 + word.length;
        if (needed > width) {
          text('${line.trimRight()}\n');
          line = '${' ' * prefix.length}$word ';
        } else {
          line = '${line.trimRight()} $word '.trimLeft();
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
    command([0x1b, 0x40]); // init

    for (final block in s.blocks) {
      if (!block.enabled) continue;
      switch (block.type) {
        case BlockType.orderNumber:
          if (orderNumber > 0) {
            setAlign(BlockAlign.center);
            command([0x1b, 0x45, 1]);
            command([0x1d, 0x21, 0x11]);
            text('Order #$orderNumber\n');
            command([0x1d, 0x21, 0]);
            command([0x1b, 0x45, 0]);
            text('${'-' * width}\n');
          }
          break;
        case BlockType.logo:
          if (logoBytes != null) {
            setAlign(BlockAlign.center);
            command(_rasterLogo(logoBytes));
            text('\n');
          }
          break;
        case BlockType.socialMedia:
          if (socialBytes != null) {
            setAlign(BlockAlign.center);
            command(_rasterLogo(socialBytes));
            text('\n');
          } else {
            setAlign(BlockAlign.center);
            command([0x1b, 0x45, 1]);
            text('IG: @kopikarsa.co\n');
            text('TT: @kopikarsa\n');
            command([0x1b, 0x45, 0]);
          }
          break;
        case BlockType.text:
          if (block.text.trim().isNotEmpty) {
            setAlign(block.align);
            if (block.isBold) command([0x1b, 0x45, 1]);
            if (block.isLarge) command([0x1d, 0x21, 0x01]);
            wrapped(block.text);
            if (block.isLarge) command([0x1d, 0x21, 0]);
            if (block.isBold) command([0x1b, 0x45, 0]);
          }
          break;
        case BlockType.divider:
          setAlign(BlockAlign.left);
          text('${'-' * width}\n');
          break;
        case BlockType.transactionDetails:
          setAlign(BlockAlign.left);
          wrapped('No: $transactionNumber');
          text('Tanggal : ${_dateTime(transactionTime)}\n');
          if (s.showCustomerName) wrapped('Pembeli : $customerName');
          if (s.showPaymentMethod) text('Bayar   : $paymentMethod\n');
          text('\n');
          setAlign(BlockAlign.center);
          command([0x1b, 0x45, 1]); // bold
          command([0x1d, 0x21, 0x01]); // double height
          text('$orderType\n');
          command([0x1d, 0x21, 0]); // normal
          command([0x1b, 0x45, 0]); // unbold
          break;
        case BlockType.itemsTable:
          setAlign(BlockAlign.left);
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
            if (s.showItemDetails) {
              if (item.options.isNotEmpty) wrapped(_cleanText(item.options), prefix: '  ');
              if (item.note.isNotEmpty) wrapped('Catatan: ${_cleanText(item.note)}', prefix: '  ');
            }
          }
          break;
        case BlockType.totalSummary:
          setAlign(BlockAlign.left);
          text(columns('Subtotal', rupiah(total)));
          command([0x1b, 0x45, 1]);
          command([0x1d, 0x21, 0x01]);
          text(columns('TOTAL', rupiah(total)));
          command([0x1d, 0x21, 0]);
          command([0x1b, 0x45, 0]);
          break;
        case BlockType.footerGreeting:
          setAlign(BlockAlign.center);
          command([0x1b, 0x45, 1]);
          wrapped('Terima kasih, $customerName!');
          command([0x1b, 0x45, 0]);
          final footerNote = block.text.isNotEmpty ? block.text : 'Selamat menikmati kopi Anda.';
          text('$footerNote\n');
          break;
        case BlockType.cutLine:
          setAlign(BlockAlign.center);
          text('--- POTONG DI SINI ---\n\n');
          command([0x1b, 0x64, 2]);
          command([0x1d, 0x56, 1]);
          break;
      }
    }

    final hasCut = s.blocks.any((b) => b.enabled && b.type == BlockType.cutLine);
    if (!hasCut) {
      command([0x1b, 0x64, 2]);
      command([0x1d, 0x56, 1]);
    }

    return bytes.toBytes();
  }

  List<int> _rasterLogo(Uint8List bytes) {
    final source = img.decodeImage(bytes);
    if (source == null) return const [];
    final targetWidth = source.width <= 384 ? source.width : 320;
    final logo = source.width == targetWidth
        ? source
        : img.copyResize(source, width: targetWidth);
    final widthBytes = (logo.width + 7) ~/ 8;
    final data = <int>[];
    for (var y = 0; y < logo.height; y++) {
      for (var xByte = 0; xByte < widthBytes; xByte++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x >= logo.width) continue;
          final pixel = logo.getPixel(x, y);
          final luminance =
              (299 * pixel.r + 587 * pixel.g + 114 * pixel.b) / 1000;
          if (pixel.a > 127 && luminance < 160) value |= 0x80 >> bit;
        }
        data.add(value);
      }
    }
    return [
      0x1d,
      0x76,
      0x30,
      0,
      widthBytes & 0xff,
      widthBytes >> 8,
      logo.height & 0xff,
      logo.height >> 8,
      ...data,
    ];
  }
}

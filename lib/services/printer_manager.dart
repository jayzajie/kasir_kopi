import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

class PrinterManager {
  PrinterManager._();

  static final instance = PrinterManager._();
  static const _settings = MethodChannel('kopi_kita/device_settings');

  Printer? selectedPrinter;

  Future<List<Printer>> discover() async {
    final printers = <Printer>[];
    final info = await Printing.info();
    if (info.canListPrinters) printers.addAll(await Printing.listPrinters());
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final devices =
          await _settings.invokeListMethod<Object?>('listBluetoothPrinters') ??
          [];
      for (final value in devices) {
        final device = Map<Object?, Object?>.from(value! as Map);
        final address = device['address'] as String;
        printers.add(
          Printer(
            url: 'bt://$address',
            name: (device['name'] as String?)?.trim().isNotEmpty == true
                ? device['name']! as String
                : address,
            model: 'Bluetooth ESC/POS',
          ),
        );
      }
    }
    printers.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return printers;
  }

  Future<Printer?> choose(BuildContext context) async {
    final printer = await Printing.pickPrinter(
      context: context,
      title: 'Pilih Printer Struk',
    );
    if (printer != null) selectedPrinter = printer;
    return printer;
  }

  Future<void> openPairing(String connection) =>
      _settings.invokeMethod('openPrinterSettings', connection);

  Future<void> rawPrint({
    required String printerName,
    required String documentName,
    required Uint8List data,
  }) => _settings.invokeMethod('rawPrint', {
    'printerName': printerName,
    'documentName': documentName,
    'data': data,
  });
}

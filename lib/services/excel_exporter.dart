import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart'
    show XTypeGroup, getSaveLocation;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExcelExporter {
  const ExcelExporter();

  /// Export transaksi ke .xlsx lalu buka share sheet / save dialog.
  /// [rows] adalah hasil query [AppDatabase.salesForExport].
  Future<void> export({
    required BuildContext context,
    required List<Map<String, Object?>> rows,
    required DateTime from,
    required DateTime to,
    required String periodLabel,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Ringkasan Transaksi ─────────────────────────────────────────
    final summary = excel['Ringkasan Transaksi'];
    excel.setDefaultSheet('Ringkasan Transaksi');

    _addHeaderRow(summary, [
      'No. Transaksi',
      'Tanggal',
      'Jam',
      'Nama Pelanggan',
      'Metode Bayar',
      'Total (Rp)',
      'Status',
    ]);

    final seen = <int>{};
    int summaryRow = 1;
    int totalRevenue = 0;

    for (final row in rows) {
      final id = row['id'] as int;
      if (seen.contains(id)) continue;
      seen.add(id);
      totalRevenue += row['total'] as int;

      final dt = DateTime.parse(row['created_at'] as String).toLocal();
      _setRow(summary, summaryRow, [
        row['transaction_number'] as String,
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}',
        '${_pad(dt.hour)}:${_pad(dt.minute)}',
        row['customer_name'] as String,
        row['payment_method'] as String,
        row['total'] as int,
        _statusLabel(row['status'] as int),
      ]);
      summaryRow++;
    }

    if (seen.isNotEmpty) {
      _setRow(summary, summaryRow, [
        'TOTAL',
        '',
        '',
        '',
        '${seen.length} transaksi',
        totalRevenue,
        '',
      ]);
      for (int c = 0; c < 7; c++) {
        summary
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: summaryRow),
            )
            .cellStyle = CellStyle(
          bold: true,
        );
      }
    }

    // ── Sheet 2: Detail Item ──────────────────────────────────────────────────
    final detail = excel['Detail Item'];

    _addHeaderRow(detail, [
      'No. Transaksi',
      'Tanggal',
      'Jam',
      'Nama Pelanggan',
      'Produk',
      'Kustomisasi',
      'Catatan',
      'Qty',
      'Harga Satuan (Rp)',
      'Surcharge (Rp)',
      'Subtotal (Rp)',
    ]);

    int detailRow = 1;
    for (final row in rows) {
      final dt = DateTime.parse(row['created_at'] as String).toLocal();
      final unitPrice = row['unit_price'] as int;
      final extra = row['extra'] as int;
      final qty = row['quantity'] as int;
      _setRow(detail, detailRow, [
        row['transaction_number'] as String,
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}',
        '${_pad(dt.hour)}:${_pad(dt.minute)}',
        row['customer_name'] as String,
        row['product_name'] as String,
        row['options'] as String,
        row['note'] as String,
        qty,
        unitPrice,
        extra,
        (unitPrice + extra) * qty,
      ]);
      detailRow++;
    }

    // ── Sheet 3: Rekap Per Hari ───────────────────────────────────────────────
    final daily = excel['Rekap Harian'];

    _addHeaderRow(daily, ['Tanggal', 'Jumlah Transaksi', 'Total Omzet (Rp)']);

    final dailyMap = <String, _DailyStat>{};
    for (final row in rows) {
      final id = row['id'] as int;
      final dt = DateTime.parse(row['created_at'] as String).toLocal();
      final dayKey = '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
      final stat = dailyMap.putIfAbsent(dayKey, _DailyStat.new);
      if (!stat.seenIds.contains(id)) {
        stat.seenIds.add(id);
        stat.revenue += row['total'] as int;
      }
    }

    int dailyRow = 1;
    int totalTrx = 0;
    int totalRev = 0;
    for (final day in (dailyMap.keys.toList()..sort())) {
      final stat = dailyMap[day]!;
      final parts = day.split('-');
      _setRow(daily, dailyRow, [
        '${parts[2]}/${parts[1]}/${parts[0]}',
        stat.seenIds.length,
        stat.revenue,
      ]);
      dailyRow++;
      totalTrx += stat.seenIds.length;
      totalRev += stat.revenue;
    }
    if (dailyRow > 1) {
      _setRow(daily, dailyRow, ['TOTAL', totalTrx, totalRev]);
      for (int c = 0; c < 3; c++) {
        daily
            .cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: dailyRow),
            )
            .cellStyle = CellStyle(
          bold: true,
        );
      }
    }

    // ── Judul di semua sheet ──────────────────────────────────────────────────
    for (final name in excel.sheets.keys) {
      final sheet = excel.sheets[name]!;
      sheet.insertRow(0);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        ..value = TextCellValue('Kedai Kopi Karsa.co POS — Rekap $periodLabel')
        ..cellStyle = CellStyle(bold: true, fontSize: 13);
    }

    // ── Simpan & share ────────────────────────────────────────────────────────
    final bytes = excel.save();
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuat file Excel.')),
        );
      }
      return;
    }

    final safeName = periodLabel.replaceAll(' ', '_').replaceAll('/', '-');
    final fileName = 'karsa_co_$safeName.xlsx';

    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Excel', extensions: ['xlsx']),
          ],
        );
        if (location == null) return;
        await File(location.path).writeAsBytes(bytes);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File tersimpan di ${location.path}')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ], subject: 'Rekap $periodLabel — Kedai Kopi Karsa.co POS');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyimpan file: $e')));
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addHeaderRow(Sheet sheet, List<String> headers) {
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#4B2A17'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  void _setRow(Sheet sheet, int rowIndex, List<Object?> values) {
    for (int col = 0; col < values.length; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
      );
      final v = values[col];
      if (v is int) {
        cell.value = IntCellValue(v);
      } else if (v is double) {
        cell.value = DoubleCellValue(v);
      } else {
        cell.value = TextCellValue(v?.toString() ?? '');
      }
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  String _statusLabel(int status) => switch (status) {
    0 => 'Baru',
    1 => 'Dibuat',
    2 => 'Selesai',
    3 => 'Diambil',
    _ => 'Unknown',
  };
}

class _DailyStat {
  final seenIds = <int>{};
  int revenue = 0;
}

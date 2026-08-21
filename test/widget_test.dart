import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/main.dart';
import 'package:kasir_kopi/data/app_database.dart';

void main() {
  testWidgets('dashboard and POS render', (tester) async {
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    await tester.pumpWidget(KopiKitaApp(database: database));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Dashboard'), findsWidgets);
    await tester.tap(find.text('Kasir').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Pilih produk untuk ditambahkan ke keranjang.'),
      findsOneWidget,
    );
    expect(find.text('Americano'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

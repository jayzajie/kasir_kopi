import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/main.dart';
import 'package:kasir_kopi/data/app_database.dart';

void main() {
  testWidgets('dashboard and POS render', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase();
    await database.initialize(inMemory: true);
    addTearDown(database.close);
    await tester.pumpWidget(KopiKitaApp(database: database));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Dashboard'), findsWidgets);
    await tester.tap(find.text('Inventory').last);
    await tester.pumpAndSettle();
    expect(find.text('Stok Masuk'), findsOneWidget);
    expect(find.text('Stok Opname'), findsOneWidget);
    expect(find.text('Biji Kopi'), findsOneWidget);
    await tester.tap(find.text('Kasir').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Pilih produk untuk ditambahkan ke keranjang.'),
      findsOneWidget,
    );
    expect(
      find.text('Belum ada menu. Tambahkan dari halaman Lainnya.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Lainnya').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah Menu'));
    await tester.pumpAndSettle();

    Finder field(String label) => find.widgetWithText(TextFormField, label);
    await tester.enterText(field('Nama menu'), 'Kopi Susu');
    await tester.enterText(field('Harga jual'), '10000');
    expect(
      tester.widget<TextFormField>(field('Harga jual')).controller!.text,
      '10.000',
    );
    await tester.enterText(field('HPP / modal'), '5000');
    await tester.ensureVisible(find.text('Tambah Add-on'));
    await tester.tap(find.text('Tambah Add-on'));
    await tester.pump();
    await tester.enterText(field('Nama add-on'), 'Extra Shot');
    await tester.enterText(field('Harga add-on'), '3000');
    await tester.ensureVisible(find.text('Tambah Add-on'));
    await tester.tap(find.text('Tambah Add-on'));
    await tester.pump();
    await tester.enterText(field('Nama add-on').last, 'Whipped Cream');
    await tester.enterText(field('Harga add-on').last, '4000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kopi Susu'), findsOneWidget);
    final product = (await database.products()).single;
    expect(product.price, 10000);
    expect(product.addons, hasLength(2));
    expect(product.addons.first.name, 'Extra Shot');
    expect(product.addons.last.price, 4000);
    await tester.tap(find.text('Kasir').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Kopi Susu'));
    await tester.tap(find.text('Kopi Susu'));
    await tester.pumpAndSettle();
    expect(find.text('Normal Ice'), findsOneWidget);
    expect(find.text('Normal Sugar'), findsOneWidget);
    expect(find.text('Extra Shot'), findsOneWidget);
    expect(find.text('Whipped Cream'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

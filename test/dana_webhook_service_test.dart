import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_kopi/services/dana_webhook_service.dart';

void main() {
  group('DanaWebhookService Parser Tests', () {
    test('parseAmount correctly extracts integer and formatted rupiah', () {
      expect(DanaWebhookService.parseAmount(25000), 25000);
      expect(DanaWebhookService.parseAmount('25000'), 25000);
      expect(DanaWebhookService.parseAmount('25.000'), 25000);
      expect(DanaWebhookService.parseAmount('Rp 25.000'), 25000);
      expect(DanaWebhookService.parseAmount('Rp. 25.000'), 25000);
      expect(DanaWebhookService.parseAmount('Rp 150.000'), 150000);
      expect(DanaWebhookService.parseAmount('Rp 1.500.000'), 1500000);
      expect(
        DanaWebhookService.parseAmount(
          'Kamu menerima pembayaran sebesar Rp 28.000 dari Ahmad',
        ),
        28000,
      );
    });

    test('parseAmount returns null on invalid input', () {
      expect(DanaWebhookService.parseAmount(null), isNull);
      expect(DanaWebhookService.parseAmount(''), isNull);
      expect(DanaWebhookService.parseAmount('Halo dunia'), isNull);
    });

    test('isDanaBisnisPaymentNotification accepts DANA Bisnis QRIS and rejects promos', () {
      expect(
        DanaWebhookService.isDanaBisnisPaymentNotification(
          'Kamu telah menerima Rp15.000 dari pembayaran QRIS.',
          title: 'DANA Bisnis',
        ),
        isTrue,
      );
      expect(
        DanaWebhookService.isDanaBisnisPaymentNotification(
          'Kamu menerima pembayaran sebesar Rp 28.000 dari Ahmad',
          title: 'DANA',
        ),
        isTrue,
      );
      expect(
        DanaWebhookService.isDanaBisnisPaymentNotification(
          'HARI TERAKHIR⏰ Serbu promo cuma Rp11 buat semuanya di DANA 11.11',
          title: 'DANA',
        ),
        isFalse,
      );
      expect(
        DanaWebhookService.isDanaBisnisPaymentNotification(
          '💎Serbu 5.000 Diamond buat klaim GRATIS Saldo DANA. Cek VIP Pass yuk!',
          title: 'DANA',
        ),
        isFalse,
      );
      expect(
        DanaWebhookService.isDanaBisnisPaymentNotification(
          'HARI INI🔥 Klaim Samsung Z Fold 8 Ultra & iPhone 18 Pro Max di DANA 11.11!',
          title: 'DANA',
        ),
        isFalse,
      );
    });
  });

  group('DanaWebhookService HTTP Server Tests', () {
    final service = DanaWebhookService.instance;

    setUp(() async {
      await service.startServer(preferredPort: 8989);
    });

    tearDown(() async {
      await service.stopServer();
    });

    test('GET /ping returns 200 and ok status', () async {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${service.port}/ping'),
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      final body = await utf8.decoder.bind(response).join();
      final json = jsonDecode(body);
      expect(json['status'], 'ok');
      client.close();
    });

    test('POST /dana-webhook emits event on payment', () async {
      final client = HttpClient();
      final expectation = expectLater(
        service.onPaymentReceived,
        emits(
          predicate<DanaPaymentNotification>((notif) => notif.amount == 35000),
        ),
      );

      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${service.port}/dana-webhook'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'amount': 35000, 'sender': 'Budi'}));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      await expectation;
      client.close();
    });

    test('POST /dana-webhook handles raw notification text from MacroDroid', () async {
      final client = HttpClient();
      final expectation = expectLater(
        service.onPaymentReceived,
        emits(
          predicate<DanaPaymentNotification>((notif) => notif.amount == 18000),
        ),
      );

      final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${service.port}/dana-webhook'),
      );
      request.headers.contentType = ContentType.text;
      request.write(
        'Kamu menerima pembayaran sebesar Rp 18.000 dari SITI AISYAH',
      );
      final response = await request.close();
      expect(response.statusCode, HttpStatus.ok);

      await expectation;
      client.close();
    });
  });
}

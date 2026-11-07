import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DanaPaymentNotification {
  const DanaPaymentNotification({
    required this.amount,
    required this.timestamp,
    this.sender,
    this.raw = '',
  });

  final int amount;
  final DateTime timestamp;
  final String? sender;
  final String raw;

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
    'sender': sender,
    'raw': raw,
  };
}

class DanaWebhookService {
  DanaWebhookService._();
  static final DanaWebhookService instance = DanaWebhookService._();

  /// Data QRIS DANA Bisnis Merchant
  static const String merchantName = 'Jayzie.Dev';
  static const String nmid = 'ID1025452810423';
  static const String qrisPayload =
      '00020101021126570011ID.DANA.WWW011893600915300923823102090092382310303UMI51440014ID.CO.QRIS.WWW0215ID10254528104230303UMI5204737253033605802ID5910Jayzie.Dev600454916105741156304FB27';

  HttpServer? _server;
  int _port = 8080;
  List<String> _localIps = [];
  bool _isRunning = false;

  final _paymentController =
      StreamController<DanaPaymentNotification>.broadcast();
  final List<DanaPaymentNotification> _recentPayments = [];

  bool get isRunning => _isRunning;
  int get port => _port;
  List<String> get localIps => List.unmodifiable(_localIps);
  List<DanaPaymentNotification> get recentPayments =>
      List.unmodifiable(_recentPayments);
  Stream<DanaPaymentNotification> get onPaymentReceived =>
      _paymentController.stream;

  List<String> get webhookUrls {
    if (_localIps.isEmpty) {
      return ['http://localhost:$_port/dana-webhook'];
    }
    return _localIps.map((ip) => 'http://$ip:$_port/dana-webhook').toList();
  }

  /// Memulai HTTP server lokal untuk menerima webhook notifikasi DANA
  Future<bool> startServer({int preferredPort = 8080}) async {
    if (_isRunning) return true;

    await _refreshLocalIps();

    final candidatePorts = [preferredPort, 8081, 8082, 8888, 9090];
    for (final p in candidatePorts) {
      try {
        _server = await HttpServer.bind(
          InternetAddress.anyIPv4,
          p,
          shared: false,
        );
        _port = p;
        _isRunning = true;
        _listenToRequests();
        return true;
      } catch (_) {
        // Port mungkin sedang digunakan, coba kandidat port berikutnya
      }
    }

    _isRunning = false;
    return false;
  }

  /// Menghentikan HTTP server
  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
  }

  Future<void> _refreshLocalIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      _localIps = interfaces
          .expand((iface) => iface.addresses)
          .where((addr) => !addr.isLoopback)
          .map((addr) => addr.address)
          .toList();
    } catch (_) {
      _localIps = [];
    }
  }

  void _listenToRequests() {
    _server?.listen((HttpRequest request) async {
      // CORS headers agar bisa dipanggil dari browser / app apapun
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add(
        'Access-Control-Allow-Methods',
        'GET, POST, OPTIONS',
      );
      request.response.headers.add(
        'Access-Control-Allow-Headers',
        'Content-Type',
      );

      if (request.method == 'OPTIONS') {
        request.response.statusCode = HttpStatus.ok;
        await request.response.close();
        return;
      }

      final path = request.uri.path.toLowerCase();

      // Endpoint cek status server (Health Check)
      if (request.method == 'GET' && (path == '/' || path == '/ping')) {
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          jsonEncode({
            'status': 'ok',
            'service': 'Kedai Kopi Karsa.co POS Webhook',
            'port': _port,
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        await request.response.close();
        return;
      }

      // Endpoint Webhook DANA
      if (request.method == 'POST' &&
          (path == '/dana' ||
              path == '/dana-webhook' ||
              path == '/webhook' ||
              path == '/api/dana')) {
        try {
          final content = await utf8.decoder.bind(request).join();
          final notification = _parseNotification(content);

          if (notification != null && notification.amount > 0) {
            _handleIncomingPayment(notification);

            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.ok;
            request.response.write(
              jsonEncode({
                'status': 'success',
                'message': 'Pembayaran berhasil diproses',
                'amount': notification.amount,
              }),
            );
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.statusCode = HttpStatus.badRequest;
            request.response.write(
              jsonEncode({
                'status': 'error',
                'message': 'Nominal pembayaran tidak ditemukan dalam payload',
                'received': content,
              }),
            );
          }
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.write(jsonEncode({'status': 'error', 'error': '$e'}));
        }
        await request.response.close();
        return;
      }

      // Endpoint 404
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not Found');
      await request.response.close();
    });
  }

  DanaPaymentNotification? _parseNotification(String content) {
    if (content.trim().isEmpty) return null;

    dynamic jsonBody;
    try {
      jsonBody = jsonDecode(content);
    } catch (_) {
      // Bukan JSON murni, anggap plain text notifikasi
      jsonBody = null;
    }

    int? parsedAmount;
    String? sender;
    String raw = content;

    if (jsonBody is Map<String, dynamic>) {
      // 1. Cek field amount langsung
      if (jsonBody.containsKey('amount')) {
        parsedAmount = parseAmount(jsonBody['amount']);
      }

      // 2. Cek sender/pengirim
      if (jsonBody.containsKey('sender')) {
        sender = jsonBody['sender']?.toString();
      } else if (jsonBody.containsKey('from')) {
        sender = jsonBody['from']?.toString();
      }

      // 3. Jika amount belum dapat, cek di field message/text/notif/raw
      if (parsedAmount == null) {
        final text =
            jsonBody['message'] ??
            jsonBody['text'] ??
            jsonBody['notif'] ??
            jsonBody['raw'] ??
            '';
        parsedAmount = parseAmount(text.toString());
      }
      raw = jsonEncode(jsonBody);
    } else {
      // Plain text (misal dikirim langsung teks notif dari MacroDroid)
      parsedAmount = parseAmount(content);
    }

    if (parsedAmount == null || parsedAmount <= 0) return null;

    return DanaPaymentNotification(
      amount: parsedAmount,
      timestamp: DateTime.now(),
      sender: sender,
      raw: raw,
    );
  }

  void _handleIncomingPayment(DanaPaymentNotification notification) {
    _recentPayments.insert(0, notification);
    if (_recentPayments.length > 20) {
      _recentPayments.removeLast();
    }
    _paymentController.add(notification);
  }

  /// Simulasi pembayaran untuk pengujian langsung tanpa perlu HP
  void simulatePayment(int amount, {String? sender}) {
    final notif = DanaPaymentNotification(
      amount: amount,
      timestamp: DateTime.now(),
      sender: sender ?? 'Simulasi DANA',
      raw: 'Simulasi pembayaran masuk sebesar Rp $amount',
    );
    _handleIncomingPayment(notif);
  }

  /// Parser nominal yang toleran terhadap berbagai format Rupiah:
  /// - 25000
  /// - "25000"
  /// - "25.000"
  /// - "Rp 25.000"
  /// - "Rp. 25.000,00"
  /// - "Kamu menerima pembayaran Rp 25.000 dari BUDI"
  static int? parseAmount(dynamic input) {
    if (input == null) return null;
    if (input is int) return input;
    if (input is num) return input.toInt();

    final str = input.toString().trim();
    if (str.isEmpty) return null;

    // Coba parse angka murni
    final direct = int.tryParse(str);
    if (direct != null) return direct;

    // Regex mencocokkan format ribuan Indonesia: 25.000 atau Rp 25.000
    final match = RegExp(
      r'(?:Rp\.?|IDR)?\s*(\d{1,3}(?:\.\d{3})+|\d+)',
      caseSensitive: false,
    ).firstMatch(str);

    if (match != null) {
      final rawDigits = match.group(1)!.replaceAll('.', '');
      return int.tryParse(rawDigits);
    }

    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/currency.dart';
import '../services/dana_webhook_service.dart';

class DanaWebhookPage extends StatefulWidget {
  const DanaWebhookPage({super.key});

  @override
  State<DanaWebhookPage> createState() => _DanaWebhookPageState();
}

class _DanaWebhookPageState extends State<DanaWebhookPage> {
  final _service = DanaWebhookService.instance;
  final _amountController = TextEditingController(text: '25000');
  bool _isRefreshing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refreshServer() async {
    setState(() => _isRefreshing = true);
    await _service.stopServer();
    await _service.startServer();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server webhook berhasil diperbarui.')),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin ke clipboard!')),
    );
  }

  void _simulatePayment() {
    final amount = int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid untuk simulasi.')),
      );
      return;
    }
    _service.simulatePayment(amount, sender: 'Pengujian Kasir');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green.shade800,
        content: Text('Simulasi pembayaran ${rupiah(amount)} berhasil dikirim ke kasir!'),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const brown = Color(0xff4b2a17);
    final urls = _service.webhookUrls;
    final primaryUrl = urls.isNotEmpty ? urls.first : 'Belum terdeteksi';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrasi QRIS DANA (Webhook)'),
        actions: [
          IconButton(
            tooltip: 'Refresh Server & IP',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshServer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Status Server Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _service.isRunning ? Icons.check_circle : Icons.error,
                        color: _service.isRunning ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _service.isRunning
                                  ? 'Server Webhook Aktif'
                                  : 'Server Webhook Nonaktif',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Port: ${_service.port} • Berjalan di latar belakang laptop',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text(
                    'URL Webhook Laptop (Gunakan di MacroDroid HP):',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            primaryUrl,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: brown,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Salin URL',
                          onPressed: () => _copyToClipboard(primaryUrl, 'URL Webhook'),
                        ),
                      ],
                    ),
                  ),
                  if (urls.length > 1) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pilihan IP lokal lainnya: ${urls.skip(1).join(', ')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Uji Coba Simulasi Pembayaran
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science_outlined, color: brown),
                      SizedBox(width: 8),
                      Text(
                        'Uji Simulasi Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Coba kirimkan sinyal notifikasi masuk secara langsung untuk menguji validasi kasir tanpa perlu HP.',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Nominal Simulasi',
                            prefixText: 'Rp ',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _simulatePayment,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Kirim Tes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Panduan Pengaturan MacroDroid di HP
          Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.phone_android, color: brown),
              title: const Text(
                'Panduan Setting MacroDroid di HP Pribadi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                _buildGuideStep(
                  step: '1',
                  title: 'Install MacroDroid',
                  desc: 'Download aplikasi MacroDroid (Gratis) dari Google Play Store di HP pribadi yang terpasang aplikasi DANA.',
                ),
                _buildGuideStep(
                  step: '2',
                  title: 'Hubungkan ke Wi-Fi yang Sama',
                  desc: 'Pastikan HP pribadi dan Laptop Windows tersambung ke jaringan Wi-Fi kedai yang sama.',
                ),
                _buildGuideStep(
                  step: '3',
                  title: 'Buat Macro Baru di MacroDroid',
                  desc: '• Trigger: Notifikasi Diterima -> Pilih aplikasi DANA.\n'
                      '• Tindakan (Action): Buka Situs / Permintaan HTTP (HTTP Request):\n'
                      '    - Metode: POST\n'
                      '    - URL: $primaryUrl\n'
                      '    - Header: Content-Type: application/json\n'
                      '    - Body Konten: {"raw": "[not_message]"}',
                ),
                _buildGuideStep(
                  step: '4',
                  title: 'Selesai!',
                  desc: 'Setiap kali pelanggan bayar ke QRIS DANA Anda dan HP memunculkan notifikasi, notifikasi akan langsung diteruskan ke aplikasi kasir ini dalam hitungan detik.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Log Riwayat Notifikasi Masuk
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Riwayat Notifikasi DANA Terakhir',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_service.recentPayments.length} riwayat',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (_service.recentPayments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Belum ada notifikasi pembayaran yang diterima.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._service.recentPayments.map((payment) {
                      final timeStr =
                          '${payment.timestamp.hour.toString().padLeft(2, '0')}:${payment.timestamp.minute.toString().padLeft(2, '0')}:${payment.timestamp.second.toString().padLeft(2, '0')}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.arrow_downward, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          rupiah(payment.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          payment.sender != null && payment.sender!.isNotEmpty
                              ? '${payment.sender} • $timeStr'
                              : timeStr,
                        ),
                        trailing: const Icon(Icons.check, color: Colors.green, size: 20),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xff4b2a17),
            child: Text(
              step,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

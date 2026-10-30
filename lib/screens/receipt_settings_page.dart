import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/receipt_settings.dart';
import '../services/receipt_printer.dart';

const brown = Color(0xff4b2a17);

class ReceiptSettingsPage extends StatefulWidget {
  const ReceiptSettingsPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ReceiptSettingsPage> createState() => _ReceiptSettingsPageState();
}

class _ReceiptSettingsPageState extends State<ReceiptSettingsPage> {
  late ReceiptSettings _settings;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _settings = ReceiptSettings.current;
  }

  Future<void> _save() async {
    await ReceiptSettings.save(widget.database, _settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Layout struk berhasil disimpan!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetToDefault() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Layout Struk?'),
        content: const Text(
          'Semua blok dan susunan struk akan dikembalikan ke format awal standar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _settings = _settings.copyWith(
                  blocks: ReceiptSettings.defaultBlocks(),
                );
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrint() async {
    setState(() => _printing = true);
    try {
      final sampleItems = [
        CartItem(
          Product('Kopi Susu Aren', 18000, 'Coffee'),
          qty: 2,
          options: 'Normal Ice, Less Sugar',
        ),
        CartItem(
          Product('Croissant Butter', 22000, 'Pastry'),
          qty: 1,
        ),
      ];

      await const ReceiptPrinter().print(
        transactionNumber: 'TRX-SAMPLE-001',
        paymentMethod: 'Tunai',
        customerName: 'Pelanggan',
        transactionTime: DateTime.now(),
        items: sampleItems,
        orderNumber: 1,
        orderType: 'Dine In',
        settings: _settings,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Struk contoh berhasil dikirim ke printer!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak struk contoh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _addBlockDialog() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tambah Blok / Elemen Struk',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.text_fields, color: brown),
                ),
                title: const Text('Teks Kustom'),
                subtitle: const Text(
                  'Alamat, sosmed, no. WhatsApp, nomor rekening, catatan promo, dll.',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _editTextDialog(null);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.horizontal_rule, color: brown),
                ),
                title: const Text('Garis Pembatas (Divider)'),
                subtitle: const Text('Garis putus-putus pemisah bagian struk'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.divider,
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.image_outlined, color: brown),
                ),
                title: const Text('Logo Toko'),
                subtitle: const Text('Gambar logo toko di bagian atas'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.logo,
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.confirmation_number_outlined, color: brown),
                ),
                title: const Text('Nomor Order Besar'),
                subtitle: const Text('Kotak Order #1 di struk'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.orderNumber,
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.alternate_email, color: brown),
                ),
                title: const Text('Sosmed (Instagram & TikTok)'),
                subtitle: const Text('Logo Instagram & TikTok atas-bawah (@kopikarsa.co & @kopikarsa)'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.socialMedia,
                        text: '@kopikarsa.co • @kopikarsa',
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.favorite_outline, color: brown),
                ),
                title: const Text('Ucapan Terima Kasih (Footer)'),
                subtitle: const Text('Terima kasih, [Pelanggan]! & pesan penutup'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.footerGreeting,
                        text: 'Selamat menikmati kopi Anda.',
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xfff3e5db),
                  child: Icon(Icons.content_cut, color: brown),
                ),
                title: const Text('Garis Potong Kertas'),
                subtitle: const Text('Tanda --- POTONG DI SINI ---'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.cutLine,
                      ),
                    );
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editTextDialog(ReceiptBlock? existing) {
    final textCtrl = TextEditingController(text: existing?.text ?? '');
    var align = existing?.align ?? BlockAlign.center;
    var isBold = existing?.isBold ?? false;
    var isLarge = existing?.isLarge ?? false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(existing == null ? 'Tambah Baris Teks' : 'Edit Baris Teks'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: textCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Isi Teks',
                    hintText: 'Misal: WA: 0812-3456-7890 / WiFi: kopikarsa',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                const Text('Perataan Teks (Alignment):',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SegmentedButton<BlockAlign>(
                  segments: const [
                    ButtonSegment(
                      value: BlockAlign.left,
                      icon: Icon(Icons.format_align_left),
                      label: Text('Kiri'),
                    ),
                    ButtonSegment(
                      value: BlockAlign.center,
                      icon: Icon(Icons.format_align_center),
                      label: Text('Tengah'),
                    ),
                    ButtonSegment(
                      value: BlockAlign.right,
                      icon: Icon(Icons.format_align_right),
                      label: Text('Kanan'),
                    ),
                  ],
                  selected: {align},
                  onSelectionChanged: (val) {
                    setDlgState(() => align = val.first);
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Cetak Tebal (Bold)'),
                  value: isBold,
                  onChanged: (v) => setDlgState(() => isBold = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Teks Ukuran Besar (Judul)'),
                  value: isLarge,
                  onChanged: (v) => setDlgState(() => isLarge = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: brown),
              onPressed: () {
                final txt = textCtrl.text.trim();
                if (txt.isEmpty) return;
                Navigator.pop(ctx);
                setState(() {
                  if (existing == null) {
                    _settings.blocks.add(
                      ReceiptBlock(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        type: BlockType.text,
                        text: txt,
                        align: align,
                        isBold: isBold,
                        isLarge: isLarge,
                      ),
                    );
                  } else {
                    existing.text = txt;
                    existing.align = align;
                    existing.isBold = isBold;
                    existing.isLarge = isLarge;
                  }
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _moveBlock(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _settings.blocks.length) return;
    setState(() {
      final block = _settings.blocks.removeAt(index);
      _settings.blocks.insert(newIndex, block);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 960;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kustomisasi Layout Struk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Kembalikan ke Default',
            onPressed: _resetToDefault,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Simpan',
            onPressed: _save,
          ),
        ],
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildBlockEditor(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey.shade100,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.preview_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Live Preview (${_settings.paperWidth}mm)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: _buildReceiptPreview(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: brown,
                    indicatorColor: brown,
                    tabs: [
                      Tab(icon: Icon(Icons.dashboard_customize), text: 'Editor Blok'),
                      Tab(icon: Icon(Icons.preview), text: 'Live Preview'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBlockEditor(),
                        Container(
                          color: Colors.grey.shade100,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 20,
                            ),
                            child: Center(child: _buildReceiptPreview()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _printing ? null : _testPrint,
                icon: _printing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: const Text('Tes Cetak Struk'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: brown),
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Simpan Pengaturan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockEditor() {
    return Column(
      children: [
        // ── Controls atas: Pilihan kertas & tombol tambah ─────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Lebar Kertas:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 58, label: Text('58 mm')),
                      ButtonSegment(value: 80, label: Text('80 mm')),
                    ],
                    selected: {_settings.paperWidth},
                    onSelectionChanged: (val) {
                      setState(() {
                        _settings = _settings.copyWith(paperWidth: val.first);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: brown,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _addBlockDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Tambah Baris / Blok Baru'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Geser atau gunakan panah untuk atur urutan. Toggle switch untuk nyala/mati.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // ── Daftar Blok (Reorderable) ──────────────────────────────────────
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
            itemCount: _settings.blocks.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final b = _settings.blocks.removeAt(oldIdx);
                _settings.blocks.insert(newIdx, b);
              });
            },
            itemBuilder: (context, index) {
              final block = _settings.blocks[index];
              return _buildBlockCard(block, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBlockCard(ReceiptBlock block, int index) {
    IconData icon;
    Color iconBg = Colors.grey.shade100;
    Color iconColor = Colors.grey.shade700;

    switch (block.type) {
      case BlockType.logo:
        icon = Icons.image_outlined;
        iconBg = Colors.purple.shade50;
        iconColor = Colors.purple;
        break;
      case BlockType.orderNumber:
        icon = Icons.confirmation_number_outlined;
        iconBg = Colors.amber.shade50;
        iconColor = Colors.amber.shade900;
        break;
      case BlockType.socialMedia:
        icon = Icons.alternate_email;
        iconBg = Colors.pink.shade50;
        iconColor = Colors.pink;
        break;
      case BlockType.footerGreeting:
        icon = Icons.favorite_outline;
        iconBg = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        break;
      case BlockType.text:
        icon = Icons.short_text;
        iconBg = Colors.blue.shade50;
        iconColor = Colors.blue.shade800;
        break;
      case BlockType.divider:
        icon = Icons.horizontal_rule;
        iconBg = Colors.grey.shade100;
        iconColor = Colors.grey.shade600;
        break;
      case BlockType.transactionDetails:
        icon = Icons.receipt_outlined;
        iconBg = Colors.teal.shade50;
        iconColor = Colors.teal;
        break;
      case BlockType.itemsTable:
        icon = Icons.list_alt;
        iconBg = Colors.green.shade50;
        iconColor = Colors.green;
        break;
      case BlockType.totalSummary:
        icon = Icons.calculate_outlined;
        iconBg = Colors.orange.shade50;
        iconColor = Colors.orange.shade800;
        break;
      case BlockType.cutLine:
        icon = Icons.content_cut;
        iconBg = Colors.red.shade50;
        iconColor = Colors.red;
        break;
    }

    return Card(
      key: ValueKey(block.id),
      elevation: 0.8,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: block.enabled ? Colors.white : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: block.enabled ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: CircleAvatar(
          backgroundColor: iconBg,
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                block.label,
                style: TextStyle(
                  fontWeight: block.isBold ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                  color: block.enabled ? Colors.black87 : Colors.grey,
                  decoration: block.enabled ? null : TextDecoration.lineThrough,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (block.type == BlockType.text)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  block.align == BlockAlign.center
                      ? 'Tengah'
                      : block.align == BlockAlign.right
                          ? 'Kanan'
                          : 'Kiri',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Switch On/Off
            Switch(
              value: block.enabled,
              onChanged: (val) {
                setState(() => block.enabled = val);
              },
            ),
            // Edit button (for text, social, and footer blocks)
            if (block.type == BlockType.text ||
                block.type == BlockType.socialMedia ||
                block.type == BlockType.footerGreeting)
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit Teks',
                onPressed: () => _editTextDialog(block),
              ),
            // Move up / down
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 18),
              tooltip: 'Pindah ke atas',
              onPressed: index > 0 ? () => _moveBlock(index, -1) : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 18),
              tooltip: 'Pindah ke bawah',
              onPressed: index < _settings.blocks.length - 1
                  ? () => _moveBlock(index, 1)
                  : null,
            ),
            // Delete button
            if (block.canDelete)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                tooltip: 'Hapus Blok',
                onPressed: () {
                  setState(() {
                    _settings.blocks.removeAt(index);
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    final previewWidth = _settings.paperWidth == 80 ? 340.0 : 280.0;
    final widgets = <Widget>[];

    for (final block in _settings.blocks) {
      if (!block.enabled) continue;
      switch (block.type) {
        case BlockType.logo:
          widgets.add(Center(
            child: Image.asset(
              'logo_karsa.png',
              width: _settings.paperWidth == 80 ? 120 : 90,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.coffee,
                size: 40,
                color: Colors.black54,
              ),
            ),
          ));
          widgets.add(const SizedBox(height: 6));
          break;
        case BlockType.orderNumber:
          widgets.add(Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Order #1',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ));
          widgets.add(const SizedBox(height: 6));
          break;
        case BlockType.socialMedia:
          widgets.add(Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/instagram.png',
                      width: 15,
                      height: 15,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.camera_alt, size: 15),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '@kopikarsa.co',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/tiktok.png',
                      width: 15,
                      height: 15,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.music_note, size: 15),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '@kopikarsa',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ));
          widgets.add(const SizedBox(height: 5));
          break;
        case BlockType.footerGreeting:
          widgets.add(const Text(
            'Terima kasih, Pelanggan!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ));
          widgets.add(const SizedBox(height: 2));
          widgets.add(Text(
            block.text.isNotEmpty ? block.text : 'Selamat menikmati kopi Anda.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 9,
              color: Colors.black87,
            ),
          ));
          widgets.add(const SizedBox(height: 4));
          break;
        case BlockType.text:
          if (block.text.trim().isNotEmpty) {
            TextAlign ta = TextAlign.center;
            if (block.align == BlockAlign.left) ta = TextAlign.left;
            if (block.align == BlockAlign.right) ta = TextAlign.right;
            final isLong = block.text.trim().length > 30;
            widgets.add(Text(
              block.text,
              textAlign: ta,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: block.isLarge ? 13 : (isLong ? 9 : 10),
                fontWeight: block.isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ));
            widgets.add(const SizedBox(height: 2));
          }
          break;
        case BlockType.divider:
          widgets.add(_dashLine());
          break;
        case BlockType.transactionDetails:
          widgets.add(_rowText('No. Transaksi', 'TRX-SAMPLE-001'));
          widgets.add(_rowText('Tanggal', '28/10/2026 18:23'));
          widgets.add(_rowText('Pembeli', 'Pelanggan'));
          widgets.add(_rowText('Pembayaran', 'Tunai'));
          widgets.add(const SizedBox(height: 6));
          widgets.add(Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black87),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'DINE IN',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ));
          break;
        case BlockType.itemsTable:
          widgets.add(_itemRow('2x Kopi Susu Aren', 'Rp 36.000',
              options: 'Normal Ice, Less Sugar'));
          widgets.add(_itemRow('1x Croissant Butter', 'Rp 22.000'));
          break;
        case BlockType.totalSummary:
          widgets.add(_rowText('Subtotal', 'Rp 58.000'));
          widgets.add(const SizedBox(height: 3));
          widgets.add(Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Rp 58.000',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ));
          break;
        case BlockType.cutLine:
          widgets.add(const SizedBox(height: 12));
          widgets.add(Row(
            children: [
              const Icon(Icons.content_cut, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '- - - - - - - - - - - - - - - - - - - -',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.grey.shade400,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ));
          break;
      }
    }

    return Container(
      width: previewWidth,
      decoration: BoxDecoration(
        color: const Color(0xfffdfcf7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widgets,
      ),
    );
  }

  Widget _dashLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        '------------------------------------------------',
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontFamily: 'monospace',
          color: Colors.grey.shade400,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _rowText(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
          Text(right, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
        ],
      ),
    );
  }

  Widget _itemRow(String name, String price, {String? options}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              Text(price, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
            ],
          ),
          if (options != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 1),
              child: Text(
                options,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

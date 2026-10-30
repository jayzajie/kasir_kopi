import 'dart:convert';
import '../data/app_database.dart';

enum BlockType {
  logo,
  orderNumber,
  text,
  socialMedia,
  footerGreeting,
  divider,
  transactionDetails,
  itemsTable,
  totalSummary,
  cutLine,
}

enum BlockAlign { center, left, right }

class ReceiptBlock {
  final String id;
  final BlockType type;
  String text;
  BlockAlign align;
  bool isBold;
  bool isLarge;
  bool enabled;
  final bool canDelete;

  ReceiptBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.align = BlockAlign.center,
    this.isBold = false,
    this.isLarge = false,
    this.enabled = true,
    this.canDelete = true,
  });

  ReceiptBlock copyWith({
    String? id,
    BlockType? type,
    String? text,
    BlockAlign? align,
    bool? isBold,
    bool? isLarge,
    bool? enabled,
    bool? canDelete,
  }) {
    return ReceiptBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      align: align ?? this.align,
      isBold: isBold ?? this.isBold,
      isLarge: isLarge ?? this.isLarge,
      enabled: enabled ?? this.enabled,
      canDelete: canDelete ?? this.canDelete,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'text': text,
    'align': align.name,
    'isBold': isBold,
    'isLarge': isLarge,
    'enabled': enabled,
    'canDelete': canDelete,
  };

  factory ReceiptBlock.fromMap(Map<String, dynamic> map) {
    return ReceiptBlock(
      id: map['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: BlockType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BlockType.text,
      ),
      text: map['text'] as String? ?? '',
      align: BlockAlign.values.firstWhere(
        (e) => e.name == map['align'],
        orElse: () => BlockAlign.center,
      ),
      isBold: map['isBold'] as bool? ?? false,
      isLarge: map['isLarge'] as bool? ?? false,
      enabled: map['enabled'] as bool? ?? true,
      canDelete: map['canDelete'] as bool? ?? true,
    );
  }

  String get label {
    switch (type) {
      case BlockType.logo:
        return 'Logo Toko';
      case BlockType.orderNumber:
        return 'Nomor Order Besar (#1)';
      case BlockType.socialMedia:
        return 'Sosmed (@kopikarsa.co & @kopikarsa)';
      case BlockType.footerGreeting:
        return 'Ucapan Terima Kasih (Footer)';
      case BlockType.divider:
        return 'Garis Pembatas (---)';
      case BlockType.transactionDetails:
        return 'Detail Transaksi (No/Tgl/Pelanggan/Bayar)';
      case BlockType.itemsTable:
        return 'Daftar Pesanan & Harga Item';
      case BlockType.totalSummary:
        return 'Ringkasan Total & Pembayaran';
      case BlockType.cutLine:
        return 'Garis Potong Kertas';
      case BlockType.text:
        return text.isNotEmpty ? text : 'Teks Kustom';
    }
  }
}

class ReceiptSettings {
  final int paperWidth; // 58 or 80
  final bool showCustomerName;
  final bool showPaymentMethod;
  final bool showItemDetails;
  final List<ReceiptBlock> blocks;

  const ReceiptSettings({
    this.paperWidth = 58,
    this.showCustomerName = true,
    this.showPaymentMethod = true,
    this.showItemDetails = true,
    this.blocks = const [],
  });

  static List<ReceiptBlock> defaultBlocks() {
    return [
      ReceiptBlock(id: 'b_order', type: BlockType.orderNumber),
      ReceiptBlock(id: 'b_logo', type: BlockType.logo),
      ReceiptBlock(
        id: 'b_address1',
        type: BlockType.text,
        text: 'Jl. Aminah Syukur',
        align: BlockAlign.center,
      ),
      ReceiptBlock(
        id: 'b_address2',
        type: BlockType.text,
        text: 'Gg. Mulia No. 22',
        align: BlockAlign.center,
      ),
      ReceiptBlock(
        id: 'b_address3',
        type: BlockType.text,
        text: 'Samarinda Kota, Kalimantan Timur',
        align: BlockAlign.center,
      ),
      ReceiptBlock(
        id: 'b_social',
        type: BlockType.socialMedia,
        text: '@kopikarsa.co • @kopikarsa',
        align: BlockAlign.center,
      ),
      ReceiptBlock(id: 'b_div1', type: BlockType.divider),
      ReceiptBlock(
        id: 'b_trx_details',
        type: BlockType.transactionDetails,
        canDelete: false,
      ),
      ReceiptBlock(id: 'b_div2', type: BlockType.divider),
      ReceiptBlock(
        id: 'b_items',
        type: BlockType.itemsTable,
        canDelete: false,
      ),
      ReceiptBlock(id: 'b_div3', type: BlockType.divider),
      ReceiptBlock(
        id: 'b_totals',
        type: BlockType.totalSummary,
        canDelete: false,
      ),
      ReceiptBlock(id: 'b_div4', type: BlockType.divider),
      ReceiptBlock(
        id: 'b_footer',
        type: BlockType.footerGreeting,
        text: 'Selamat menikmati kopi Anda.',
        align: BlockAlign.center,
      ),
      ReceiptBlock(id: 'b_cut', type: BlockType.cutLine),
    ];
  }

  ReceiptSettings copyWith({
    int? paperWidth,
    bool? showCustomerName,
    bool? showPaymentMethod,
    bool? showItemDetails,
    List<ReceiptBlock>? blocks,
  }) {
    return ReceiptSettings(
      paperWidth: paperWidth ?? this.paperWidth,
      showCustomerName: showCustomerName ?? this.showCustomerName,
      showPaymentMethod: showPaymentMethod ?? this.showPaymentMethod,
      showItemDetails: showItemDetails ?? this.showItemDetails,
      blocks: blocks ?? this.blocks,
    );
  }

  Map<String, dynamic> toMap() => {
    'paperWidth': paperWidth,
    'showCustomerName': showCustomerName,
    'showPaymentMethod': showPaymentMethod,
    'showItemDetails': showItemDetails,
    'blocks': blocks.map((b) => b.toMap()).toList(),
  };

  factory ReceiptSettings.fromMap(Map<String, dynamic> map) {
    List<ReceiptBlock> parsedBlocks = [];
    if (map['blocks'] is List) {
      parsedBlocks = (map['blocks'] as List)
          .map((item) => ReceiptBlock.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    if (parsedBlocks.isEmpty) {
      parsedBlocks = defaultBlocks();
    }

    return ReceiptSettings(
      paperWidth: map['paperWidth'] as int? ?? 58,
      showCustomerName: map['showCustomerName'] as bool? ?? true,
      showPaymentMethod: map['showPaymentMethod'] as bool? ?? true,
      showItemDetails: map['showItemDetails'] as bool? ?? true,
      blocks: parsedBlocks,
    );
  }

  static ReceiptSettings current = ReceiptSettings(blocks: defaultBlocks());

  static const _key = 'receipt_modular_settings_v6';

  static Future<ReceiptSettings> load(AppDatabase db) async {
    try {
      final jsonStr = await db.getSetting(_key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        current = ReceiptSettings.fromMap(map);
      } else {
        current = ReceiptSettings(blocks: defaultBlocks());
      }
    } catch (_) {
      current = ReceiptSettings(blocks: defaultBlocks());
    }
    return current;
  }

  static Future<void> save(AppDatabase db, ReceiptSettings settings) async {
    current = settings;
    try {
      await db.setSetting(_key, jsonEncode(settings.toMap()));
    } catch (_) {}
  }
}

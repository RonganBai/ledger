import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 识别后的“待导入交易草稿”
/// 这里用 categoryKey（你的 i18n 分类 key），如果你项目不是 key 体系，后面接入时再映射。
class DraftTx {
  final bool isExpense; // true=支出 false=收入
  final int amountCents;
  final DateTime occurredAt;
  final String merchant;
  final String? memo;
  final String? categoryKey;

  DraftTx({
    required this.isExpense,
    required this.amountCents,
    required this.occurredAt,
    required this.merchant,
    this.memo,
    this.categoryKey,
  });
}

class TransactionImageImportPage extends StatefulWidget {
  const TransactionImageImportPage({super.key});

  /// 打开页面并返回用户勾选的 DraftTx 列表
  static Future<List<DraftTx>?> open(BuildContext context) {
    return Navigator.of(context).push<List<DraftTx>>(
      MaterialPageRoute(builder: (_) => const TransactionImageImportPage()),
    );
  }

  @override
  State<TransactionImageImportPage> createState() => _TransactionImageImportPageState();
}

class _TransactionImageImportPageState extends State<TransactionImageImportPage> {
  final _picker = ImagePicker();
  bool _loading = false;

  List<DraftTx> _items = [];
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = [];
  }

  Future<void> _pickAndScan() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;

    setState(() {
      _loading = true;
      _items = [];
      _selected = [];
    });

    final inputImage = InputImage.fromFilePath(x.path);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final res = await recognizer.processImage(inputImage);
      final parsed = _parseMultipleTransactions(res.text);

      if (!mounted) return;
      setState(() {
        _items = parsed;
        _selected = List<bool>.filled(_items.length, true);
        _loading = false;
      });

      if (parsed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没识别到交易。建议先在相册里裁剪到“交易列表区域”，再试一次。')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('识别失败：$e')),
      );
    } finally {
      await recognizer.close();
    }
  }

  void _toggleAll(bool v) {
    setState(() {
      for (int i = 0; i < _selected.length; i++) _selected[i] = v;
    });
  }

  void _confirmReturn() {
    final out = <DraftTx>[];
    for (int i = 0; i < _items.length; i++) {
      if (_selected[i]) out.add(_items[i]);
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = _items.isNotEmpty && _selected.any((x) => x);

    return Scaffold(
      appBar: AppBar(
        title: const Text('识图导入账单'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _pickAndScan,
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: '选择截图',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '从截图识别多条交易',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      const Text('建议：先在相册裁剪到“交易列表区域”，识别更准。'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickAndScan,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: const Text('选择截图并识别'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Text('识别到 ${_items.length} 条', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => _toggleAll(true),
                            child: const Text('全选'),
                          ),
                          TextButton(
                            onPressed: () => _toggleAll(false),
                            child: const Text('全不选'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final t = _items[i];
                          final date = '${t.occurredAt.month.toString().padLeft(2, '0')}/${t.occurredAt.day.toString().padLeft(2, '0')}/${t.occurredAt.year}';
                          final amt = (t.amountCents / 100.0).toStringAsFixed(2);
                          final sign = t.isExpense ? '-' : '+';
                          final color = t.isExpense ? Colors.red : Colors.green;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                            ),
                            child: CheckboxListTile(
                              value: _selected[i],
                              onChanged: (v) => setState(() => _selected[i] = v ?? false),
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                t.merchant,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text([
                                date,
                                if (t.categoryKey != null) 'cat=${t.categoryKey}',
                                if (t.memo != null && t.memo!.trim().isNotEmpty) t.memo!.trim(),
                              ].join(' · ')),
                              secondary: Text(
                                '$sign\$$amt',
                                style: TextStyle(fontWeight: FontWeight.w900, color: color),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canConfirm ? _confirmReturn : null,
                            child: Text(canConfirm ? '导入所选（${_selected.where((x) => x).length}）' : '请选择要导入的交易'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ===========================
  // OCR 文本 → 多条交易解析
  // ===========================

  List<DraftTx> _parseMultipleTransactions(String raw) {
    final text = raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'[ \t]+'), ' ');
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 金额：-$23.00 / $38.51 / $1,910.25  (也兼容无$)
    final amtRe = RegExp(r'([-+])?\$?\s*([0-9]{1,3}(?:,[0-9]{3})*|[0-9]+)\.([0-9]{2})');
    // 日期：02/21/2026
    final dateRe = RegExp(r'([01]?\d)\/([0-3]?\d)\/((?:19|20)\d{2})');

    // 策略：找到所有 “包含金额+日期” 的行，视为一条交易的 anchor
    final anchors = <_Anchor>[];
    for (int i = 0; i < lines.length; i++) {
      final mAmt = amtRe.firstMatch(lines[i]);
      final mDate = dateRe.firstMatch(lines[i]);
      if (mAmt == null || mDate == null) continue;

      final sign = mAmt.group(1); // '-' '+' or null
      final num = (mAmt.group(2)!.replaceAll(',', '') + '.' + mAmt.group(3)!);
      final amount = double.tryParse(num);
      if (amount == null) continue;

      final mm = int.parse(mDate.group(1)!);
      final dd = int.parse(mDate.group(2)!);
      final yy = int.parse(mDate.group(3)!);
      final date = DateTime(yy, mm, dd);

      anchors.add(_Anchor(
        lineIndex: i,
        amount: amount,
        isExpense: sign == '-' ? true : true, // 默认按支出；你也可改成 sign==null ? true : sign=='-'
        date: date,
      ));
    }

    if (anchors.isEmpty) return [];

    final out = <DraftTx>[];

    for (final a in anchors) {
      // 商户通常在 anchor 上一行或上两行
      String merchant = '';
      if (a.lineIndex - 1 >= 0) merchant = lines[a.lineIndex - 1];
      if (merchant.isEmpty && a.lineIndex - 2 >= 0) merchant = lines[a.lineIndex - 2];
      if (merchant.isEmpty) merchant = lines[a.lineIndex];

      merchant = _cleanMerchant(merchant);

      // 分类猜测
      final cat = _guessCategoryKey(merchant);

      // 金额转 cents
      final cents = (a.amount * 100).round();

      // 默认时间：当天 + 当前时分（因为截图里通常没具体时间）
      final now = DateTime.now();
      final occurredAt = DateTime(a.date.year, a.date.month, a.date.day, now.hour, now.minute);

      // 去重：同一天同商户同金额可能重复，简单过滤一下
      final dup = out.any((x) =>
          x.amountCents == cents &&
          x.occurredAt.year == occurredAt.year &&
          x.occurredAt.month == occurredAt.month &&
          x.occurredAt.day == occurredAt.day &&
          x.merchant == merchant);
      if (dup) continue;

      out.add(DraftTx(
        isExpense: a.isExpense,
        amountCents: cents,
        occurredAt: occurredAt,
        merchant: merchant.isEmpty ? 'Unknown' : merchant,
        categoryKey: cat,
      ));
    }

    // 按日期倒序 + 金额倒序
    out.sort((a, b) {
      final d = b.occurredAt.compareTo(a.occurredAt);
      if (d != 0) return d;
      return b.amountCents.compareTo(a.amountCents);
    });

    return out;
  }

  String _cleanMerchant(String s) {
    return s
        .replaceAll(RegExp(r'\bCARD\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bPENDING\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  String? _guessCategoryKey(String merchant) {
    final s = merchant.toLowerCase();
    if (s.contains('amazon') || s.contains('temu') || s.contains('walmart') || s.contains('target')) return 'shopping';
    if (s.contains('doordash') || s.contains('ubereats') || s.contains('restaurant') || s.contains('applebees')) return 'food';
    if (s.contains('uber') || s.contains('lyft') || s.contains('gas')) return 'transport';
    if (s.contains('paypal') || s.contains('zel') || s.contains('zelle')) return 'transfer';
    return null;
  }
}

class _Anchor {
  final int lineIndex;
  final double amount;
  final bool isExpense;
  final DateTime date;
  _Anchor({
    required this.lineIndex,
    required this.amount,
    required this.isExpense,
    required this.date,
  });
}
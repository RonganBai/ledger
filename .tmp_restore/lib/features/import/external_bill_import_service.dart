import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as d;
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';

enum ExternalBillType { wechatPay, alipay, unknown }

class ExternalBillRecord {
  final ExternalBillType type;
  final String source;
  final String sourceId;
  final DateTime occurredAt;
  final String direction; // income / expense
  final int amountCents;
  final String currency;
  final String? counterparty;
  final String? memo;
  final String tradeType;

  const ExternalBillRecord({
    required this.type,
    required this.source,
    required this.sourceId,
    required this.occurredAt,
    required this.direction,
    required this.amountCents,
    required this.currency,
    required this.counterparty,
    required this.memo,
    required this.tradeType,
  });
}

class ExternalBillParsedData {
  final String fileName;
  final ExternalBillType type;
  final String currency;
  final int scannedRows;
  final int skippedRows;
  final List<ExternalBillRecord> records;

  int get importableRows => records.length;

  const ExternalBillParsedData({
    required this.fileName,
    required this.type,
    required this.currency,
    required this.scannedRows,
    required this.skippedRows,
    required this.records,
  });
}

class ExternalBillImportResult {
  final int inserted;
  final int skipped;
  final int failed;

  const ExternalBillImportResult({
    required this.inserted,
    required this.skipped,
    required this.failed,
  });
}

class ExternalBillImportService {
  final AppDatabase? _db;
  final Uuid _uuid = const Uuid();

  ExternalBillImportService(AppDatabase db) : _db = db;

  ExternalBillImportService.parserOnly() : _db = null;

  Future<ExternalBillParsedData> parsePickedFile(PlatformFile file) async {
    final bytes = await _readBytes(file);
    final fileName = file.name.trim().isEmpty ? 'unknown' : file.name.trim();
    final lowerName = fileName.toLowerCase();

    if (lowerName.endsWith('.xlsx')) {
      return _parseXlsx(bytes, fileName);
    }
    if (lowerName.endsWith('.csv')) {
      return _parseCsv(bytes, fileName);
    }

    // Fallback probe for uncommon extensions.
    try {
      return _parseXlsx(bytes, fileName);
    } catch (_) {
      return _parseCsv(bytes, fileName);
    }
  }

  Future<ExternalBillImportResult> importParsedData({
    required int accountId,
    required ExternalBillParsedData parsed,
  }) async {
    final db = _dbOrThrow;
    final expenseCategoryMap = await _categoryMapForDirection('expense');
    final incomeCategoryMap = await _categoryMapForDirection('income');

    int inserted = 0;
    int skipped = 0;
    int failed = 0;

    for (final record in parsed.records) {
      try {
        final exists = await _existsBySourceId(
          source: record.source,
          sourceId: record.sourceId,
        );
        if (exists) {
          skipped++;
          continue;
        }

        final categoryKey = _inferCategoryKey(record);
        final categoryMap = record.direction == 'income'
            ? incomeCategoryMap
            : expenseCategoryMap;
        final categoryId = categoryMap[categoryKey] ?? categoryMap['other'];

        await db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                id: _uuid.v4(),
                source: d.Value(record.source),
                sourceId: d.Value(record.sourceId),
                accountId: accountId,
                direction: d.Value(record.direction),
                amountCents: record.amountCents,
                currency: d.Value(record.currency),
                merchant: d.Value(_nullIfBlank(record.counterparty)),
                memo: d.Value(_nullIfBlank(record.memo)),
                categoryId: d.Value(categoryId),
                occurredAt: record.occurredAt,
                confidence: const d.Value(0.9),
              ),
            );
        inserted++;
      } catch (_) {
        failed++;
      }
    }

    return ExternalBillImportResult(
      inserted: inserted,
      skipped: skipped,
      failed: failed,
    );
  }

  Future<bool> _existsBySourceId({
    required String source,
    required String sourceId,
  }) async {
    final db = _dbOrThrow;
    if (sourceId.trim().isEmpty) return false;
    final existing =
        await (db.select(db.transactions)
              ..where(
                (t) => t.source.equals(source) & t.sourceId.equals(sourceId),
              ))
            .getSingleOrNull();
    return existing != null;
  }

  Future<Map<String, int>> _categoryMapForDirection(String direction) async {
    final db = _dbOrThrow;
    final rows =
        await (db.select(db.categories)
              ..where(
                (c) => c.direction.equals(direction) & c.isActive.equals(true),
              ))
            .get();
    final map = <String, int>{};
    for (final row in rows) {
      map[row.name.toLowerCase()] = row.id;
    }
    if (!map.containsKey('other')) {
      final id = await db.ensureOtherCategoryId(direction);
      map['other'] = id;
    }
    return map;
  }

  String _inferCategoryKey(ExternalBillRecord record) {
    final haystack =
        '${record.tradeType} ${record.counterparty ?? ''} ${record.memo ?? ''}'
            .toLowerCase();

    if (record.direction == 'income') {
      if (haystack.contains('工资') || haystack.contains('salary')) {
        return 'salary';
      }
      if (haystack.contains('红包') || haystack.contains('gift')) {
        return 'gift';
      }
      if (haystack.contains('退款') || haystack.contains('refund')) {
        return 'refund';
      }
      if (haystack.contains('转账') || haystack.contains('transfer')) {
        return 'transfer';
      }
      return 'other';
    }

    if (_containsAny(haystack, const ['餐', '外卖', 'coffee', 'food'])) {
      return 'food';
    }
    if (_containsAny(haystack, const ['交通', '地铁', '公交', '打车', 'taxi'])) {
      return 'transport';
    }
    if (_containsAny(haystack, const ['购物', '商户消费', '淘宝', '京东'])) {
      return 'shopping';
    }
    if (_containsAny(
      haystack,
      const [
        '娱乐',
        '游戏',
        'steam',
        'bilibili',
        'app store',
        'apple music',
      ],
    )) {
      return 'entertainment';
    }
    if (_containsAny(haystack, const ['水电', '燃气', '话费', '宽带', '生活服务', '缴费'])) {
      return 'utilities';
    }
    if (_containsAny(haystack, const ['医疗', '医院', '药', 'health', 'medical'])) {
      return 'health';
    }
    if (_containsAny(haystack, const ['房租', 'rent'])) {
      return 'rent';
    }
    if (_containsAny(haystack, const ['旅行', '旅游', 'travel', '机票', '酒店'])) {
      return 'travel';
    }
    if (_containsAny(haystack, const ['转账', 'transfer'])) {
      return 'transfer';
    }
    return 'other';
  }

  bool _containsAny(String text, List<String> parts) {
    for (final p in parts) {
      if (text.contains(p)) return true;
    }
    return false;
  }

  Future<Uint8List> _readBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes!;
    final path = file.path;
    if (path == null || path.isEmpty) {
      throw const FormatException('Cannot read selected file.');
    }
    return File(path).readAsBytes();
  }

  ExternalBillParsedData _parseCsv(Uint8List bytes, String fileName) {
    final text = _decodeCsvText(bytes);
    final rowsRaw = CsvDecoder(
      dynamicTyping: false,
      fieldDelimiter: ',',
    ).convert(text);
    final rows = rowsRaw
        .map(
          (r) => r
              .map((c) => c == null ? '' : c.toString())
              .map(_cleanText)
              .toList(),
        )
        .toList(growable: false);

    if (_looksLikeAlipay(rows, text)) {
      return _parseAlipayRows(rows, fileName);
    }
    if (_looksLikeWechat(rows, text)) {
      return _parseWechatRows(rows, fileName);
    }

    throw const FormatException(
      'Unsupported CSV format. Please use WeChat or Alipay export files.',
    );
  }

  ExternalBillParsedData _parseXlsx(Uint8List bytes, String fileName) {
    final excel = xl.Excel.decodeBytes(bytes);
    final rows = <List<String>>[];
    for (final sheet in excel.tables.values) {
      for (final row in sheet.rows) {
        rows.add(
          row.map((cell) => _cellValueToString(cell?.value)).map(_cleanText).toList(),
        );
      }
    }

    if (_looksLikeWechat(rows, '')) {
      return _parseWechatRows(rows, fileName);
    }
    if (_looksLikeAlipay(rows, '')) {
      return _parseAlipayRows(rows, fileName);
    }

    throw const FormatException(
      'Unsupported XLSX format. Please use WeChat or Alipay export files.',
    );
  }

  String _decodeCsvText(Uint8List bytes) {
    String? utfText;
    try {
      utfText = utf8.decode(bytes);
      if (_hasKnownBillKeywords(utfText)) {
        return utfText;
      }
    } catch (_) {
      utfText = null;
    }

    try {
      final gbkText = gbk_bytes.decode(bytes);
      if (_hasKnownBillKeywords(gbkText)) {
        return gbkText;
      }
      return gbkText;
    } catch (_) {
      if (utfText != null) return utfText;
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  bool _hasKnownBillKeywords(String text) {
    return text.contains('交易时间') ||
        text.contains('支付宝') ||
        text.contains('微信支付') ||
        text.contains('收/支');
  }

  AppDatabase get _dbOrThrow {
    final db = _db;
    if (db == null) {
      throw StateError('Database is required for import operation.');
    }
    return db;
  }

  String _cellValueToString(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return _formatDateTime(value);
    return value.toString();
  }

  String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  bool _looksLikeAlipay(List<List<String>> rows, String rawText) {
    if (rawText.contains('支付宝')) return true;
    return _findHeaderRow(
          rows,
          const ['交易时间', '交易分类', '交易订单号'],
        ) >=
        0;
  }

  bool _looksLikeWechat(List<List<String>> rows, String rawText) {
    if (rawText.contains('微信支付')) return true;
    return _findHeaderRow(
          rows,
          const ['交易时间', '交易类型', '交易单号'],
        ) >=
        0;
  }

  ExternalBillParsedData _parseWechatRows(
    List<List<String>> rows,
    String fileName,
  ) {
    final headerIndex = _findHeaderRow(
      rows,
      const ['交易时间', '交易类型', '交易对方', '收/支', '交易单号'],
    );
    if (headerIndex < 0) {
      throw const FormatException('Cannot find WeChat bill header row.');
    }

    final headerMap = _buildHeaderMap(rows[headerIndex]);
    final records = <ExternalBillRecord>[];
    int scanned = 0;
    int skipped = 0;

    for (int i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      scanned++;

      final occurredRaw = _cellByAliases(row, headerMap, const ['交易时间']);
      final tradeType = _cellByAliases(row, headerMap, const ['交易类型']);
      final counterparty = _cellByAliases(row, headerMap, const ['交易对方']);
      final io = _cellByAliases(row, headerMap, const ['收/支']);
      final amountRaw = _cellByAliases(row, headerMap, const ['金额']);
      final status = _cellByAliases(row, headerMap, const ['当前状态']);
      final txNo = _cellByAliases(row, headerMap, const ['交易单号']);
      final merchantNo = _cellByAliases(row, headerMap, const ['商户单号']);
      final goods = _cellByAliases(row, headerMap, const ['商品']);
      final remark = _cellByAliases(row, headerMap, const ['备注']);

      if (occurredRaw.isEmpty || amountRaw.isEmpty || txNo.isEmpty) {
        skipped++;
        continue;
      }

      if (!_isSuccessStatus(status)) {
        skipped++;
        continue;
      }

      final direction = _parseDirection(io);
      if (direction == null) {
        skipped++;
        continue;
      }

      final occurredAt = _parseOccurredAt(occurredRaw);
      if (occurredAt == null) {
        skipped++;
        continue;
      }

      final amount = _parseAmountAndCurrency(amountRaw, fallbackCurrency: 'CNY');
      if (amount.amountCents <= 0) {
        skipped++;
        continue;
      }

      final sourceId = txNo.trim().isNotEmpty ? txNo.trim() : merchantNo.trim();
      if (sourceId.isEmpty) {
        skipped++;
        continue;
      }

      final memo = _joinMemo([tradeType, goods, remark]);

      records.add(
        ExternalBillRecord(
          type: ExternalBillType.wechatPay,
          source: 'wechatpay',
          sourceId: sourceId,
          occurredAt: occurredAt,
          direction: direction,
          amountCents: amount.amountCents,
          currency: amount.currency,
          counterparty: _nullIfBlank(counterparty),
          memo: memo,
          tradeType: tradeType,
        ),
      );
    }

    final currency = _majorCurrency(records, fallback: 'CNY');
    return ExternalBillParsedData(
      fileName: fileName,
      type: ExternalBillType.wechatPay,
      currency: currency,
      scannedRows: scanned,
      skippedRows: skipped,
      records: records,
    );
  }

  ExternalBillParsedData _parseAlipayRows(
    List<List<String>> rows,
    String fileName,
  ) {
    final headerIndex = _findHeaderRow(
      rows,
      const ['交易时间', '交易分类', '交易对方', '收/支', '交易订单号'],
    );
    if (headerIndex < 0) {
      throw const FormatException('Cannot find Alipay bill header row.');
    }

    final headerMap = _buildHeaderMap(rows[headerIndex]);
    final records = <ExternalBillRecord>[];
    int scanned = 0;
    int skipped = 0;

    for (int i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      scanned++;

      final occurredRaw = _cellByAliases(row, headerMap, const ['交易时间']);
      final tradeClass = _cellByAliases(row, headerMap, const ['交易分类']);
      final counterparty = _cellByAliases(row, headerMap, const ['交易对方']);
      final io = _cellByAliases(row, headerMap, const ['收/支']);
      final amountRaw = _cellByAliases(row, headerMap, const ['金额']);
      final status = _cellByAliases(row, headerMap, const ['交易状态']);
      final txNo = _cellByAliases(row, headerMap, const ['交易订单号']);
      final merchantNo = _cellByAliases(row, headerMap, const ['商家订单号']);
      final goods = _cellByAliases(row, headerMap, const ['商品说明']);
      final remark = _cellByAliases(row, headerMap, const ['备注']);

      if (occurredRaw.isEmpty || amountRaw.isEmpty || txNo.isEmpty) {
        skipped++;
        continue;
      }

      if (!_isSuccessStatus(status)) {
        skipped++;
        continue;
      }

      final direction = _parseDirection(io);
      if (direction == null) {
        skipped++;
        continue;
      }

      final occurredAt = _parseOccurredAt(occurredRaw);
      if (occurredAt == null) {
        skipped++;
        continue;
      }

      final amount = _parseAmountAndCurrency(amountRaw, fallbackCurrency: 'CNY');
      if (amount.amountCents <= 0) {
        skipped++;
        continue;
      }

      final sourceId = txNo.trim().isNotEmpty ? txNo.trim() : merchantNo.trim();
      if (sourceId.isEmpty) {
        skipped++;
        continue;
      }

      final memo = _joinMemo([tradeClass, goods, remark]);

      records.add(
        ExternalBillRecord(
          type: ExternalBillType.alipay,
          source: 'alipay',
          sourceId: sourceId,
          occurredAt: occurredAt,
          direction: direction,
          amountCents: amount.amountCents,
          currency: amount.currency,
          counterparty: _nullIfBlank(counterparty),
          memo: memo,
          tradeType: tradeClass,
        ),
      );
    }

    final currency = _majorCurrency(records, fallback: 'CNY');
    return ExternalBillParsedData(
      fileName: fileName,
      type: ExternalBillType.alipay,
      currency: currency,
      scannedRows: scanned,
      skippedRows: skipped,
      records: records,
    );
  }

  String _majorCurrency(List<ExternalBillRecord> records, {required String fallback}) {
    if (records.isEmpty) return fallback;
    final freq = <String, int>{};
    for (final r in records) {
      freq[r.currency] = (freq[r.currency] ?? 0) + 1;
    }
    String best = fallback;
    int max = -1;
    freq.forEach((currency, count) {
      if (count > max) {
        best = currency;
        max = count;
      }
    });
    return best;
  }

  int _findHeaderRow(List<List<String>> rows, List<String> requiredParts) {
    for (int i = 0; i < rows.length; i++) {
      final line = rows[i].map(_normalizeHeader).join('|');
      bool ok = true;
      for (final part in requiredParts) {
        if (!line.contains(_normalizeHeader(part))) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  Map<String, int> _buildHeaderMap(List<String> headerRow) {
    final map = <String, int>{};
    for (int i = 0; i < headerRow.length; i++) {
      final key = _normalizeHeader(headerRow[i]);
      if (key.isNotEmpty && !map.containsKey(key)) {
        map[key] = i;
      }
    }
    return map;
  }

  String _cellByAliases(
    List<String> row,
    Map<String, int> headerMap,
    List<String> aliases,
  ) {
    for (final alias in aliases) {
      final normAlias = _normalizeHeader(alias);
      final exact = headerMap[normAlias];
      if (exact != null) {
        return _safeCell(row, exact);
      }
    }
    for (final entry in headerMap.entries) {
      for (final alias in aliases) {
        if (entry.key.contains(_normalizeHeader(alias))) {
          return _safeCell(row, entry.value);
        }
      }
    }
    return '';
  }

  String _safeCell(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return _cleanText(row[index]);
  }

  bool _isRowEmpty(List<String> row) {
    for (final c in row) {
      if (_cleanText(c).isNotEmpty) return false;
    }
    return true;
  }

  String _normalizeHeader(String s) {
    return s
        .replaceAll('\uFEFF', '')
        .replaceAll('\u3000', '')
        .replaceAll('：', ':')
        .replaceAll(RegExp(r'\s+'), '')
        .trim()
        .toLowerCase();
  }

  String _cleanText(String s) {
    return s.replaceAll('\uFEFF', '').trim();
  }

  bool _isSuccessStatus(String statusRaw) {
    final status = statusRaw.trim();
    if (status.isEmpty || status == '/') return true;
    return status.contains('成功') ||
        status.contains('已存入') ||
        status.contains('已收款') ||
        status.contains('已到账');
  }

  String? _parseDirection(String raw) {
    final v = raw.trim();
    if (v.contains('支出')) return 'expense';
    if (v.contains('收入')) return 'income';
    return null;
  }

  DateTime? _parseOccurredAt(String raw) {
    final v = raw.trim().replaceAll('/', '-');
    if (v.isEmpty) return null;
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }

  String? _nullIfBlank(String? text) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == '/') return null;
    return trimmed;
  }

  String? _joinMemo(List<String> pieces) {
    final seen = <String>{};
    final out = <String>[];
    for (final piece in pieces) {
      final p = piece.trim();
      if (p.isEmpty || p == '/') continue;
      if (seen.add(p)) out.add(p);
    }
    if (out.isEmpty) return null;
    return out.join(' | ');
  }

  _AmountWithCurrency _parseAmountAndCurrency(
    String raw, {
    required String fallbackCurrency,
  }) {
    final text = raw.trim();
    String currency = fallbackCurrency.toUpperCase();
    final up = text.toUpperCase();

    if (up.contains('HK\$')) {
      currency = 'HKD';
    } else if (up.contains('US\$') || up.contains('\$')) {
      currency = 'USD';
    } else if (up.contains('€') || up.contains('EUR')) {
      currency = 'EUR';
    } else if (up.contains('£') || up.contains('GBP')) {
      currency = 'GBP';
    } else if (up.contains('¥') || up.contains('￥') || up.contains('元')) {
      currency = 'CNY';
    }

    final cleaned = text
        .replaceAll('HK\$', '')
        .replaceAll('US\$', '')
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll('\$', '')
        .replaceAll('€', '')
        .replaceAll('£', '')
        .replaceAll('元', '')
        .replaceAll(',', '')
        .trim();

    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(cleaned);
    final value = match == null ? 0.0 : double.tryParse(match.group(0)!) ?? 0.0;
    final cents = (value.abs() * 100).round();
    return _AmountWithCurrency(amountCents: cents, currency: currency);
  }
}

class _AmountWithCurrency {
  final int amountCents;
  final String currency;

  const _AmountWithCurrency({
    required this.amountCents,
    required this.currency,
  });
}

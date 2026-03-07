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

enum ExternalBillType { wechatPay, alipay, pnc, unknown }

class ExternalBillRecord {
  final ExternalBillType type;
  final String source;
  final String sourceId;
  final DateTime occurredAt;
  final String direction; // income / expense / pending
  final String?
  pendingBaseDirection; // income / expense when direction == pending
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
    this.pendingBaseDirection,
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
  final int? latestBalanceCents;
  final DateTime? latestBalanceAt;
  final int? earliestBalanceCents;
  final DateTime? earliestBalanceAt;
  final int? earliestBalanceAmountCents;
  final String? earliestBalanceDirection;

  int get importableRows => records.length;

  const ExternalBillParsedData({
    required this.fileName,
    required this.type,
    required this.currency,
    required this.scannedRows,
    required this.skippedRows,
    required this.records,
    this.latestBalanceCents,
    this.latestBalanceAt,
    this.earliestBalanceCents,
    this.earliestBalanceAt,
    this.earliestBalanceAmountCents,
    this.earliestBalanceDirection,
  });
}

class ExternalBillImportResult {
  final int inserted;
  final int skipped;
  final int failed;
  final int balanceAdjustedCents;
  final List<String> insertedTransactionIds;

  bool get hasBalanceAdjustment => balanceAdjustedCents != 0;

  const ExternalBillImportResult({
    required this.inserted,
    required this.skipped,
    required this.failed,
    this.balanceAdjustedCents = 0,
    this.insertedTransactionIds = const <String>[],
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
    final insertedTransactionIds = <String>[];
    int balanceAdjustedCents = 0;
    final accountHasTransactions = await _accountHasAnyTransactions(accountId);
    if (parsed.type == ExternalBillType.pnc && !accountHasTransactions) {
      try {
        final seedResult = await _applyPncOpeningBalanceSeed(
          accountId: accountId,
          parsed: parsed,
          expenseCategoryMap: expenseCategoryMap,
          incomeCategoryMap: incomeCategoryMap,
        );
        balanceAdjustedCents = seedResult.adjustedCents;
        if (seedResult.txId != null) {
          insertedTransactionIds.add(seedResult.txId!);
        }
      } catch (_) {
        // Keep import result available even if opening seed fails.
      }
    }

    final existingForAccount = await (db.select(
      db.transactions,
    )..where((t) => t.accountId.equals(accountId))).get();
    final pncMatcher = _PncDuplicateMatcher(existingForAccount);

    for (final record in parsed.records) {
      try {
        final existsBySource = await _existsBySourceId(
          accountId: accountId,
          source: record.source,
          sourceId: record.sourceId,
        );
        if (existsBySource) {
          skipped++;
          continue;
        }
        if (parsed.type == ExternalBillType.pnc && pncMatcher.matches(record)) {
          skipped++;
          continue;
        }

        final categoryKey = _inferCategoryKey(record);
        final categoryDirection = _effectiveDirectionForCategory(record);
        final categoryMap = categoryDirection == 'income'
            ? incomeCategoryMap
            : expenseCategoryMap;
        final categoryId = categoryMap[categoryKey] ?? categoryMap['other'];

        final localTxId = _uuid.v4();
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: localTxId,
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
        insertedTransactionIds.add(localTxId);
        if (parsed.type == ExternalBillType.pnc) {
          pncMatcher.addRecord(record);
        }
      } catch (_) {
        failed++;
      }
    }

    return ExternalBillImportResult(
      inserted: inserted,
      skipped: skipped,
      failed: failed,
      balanceAdjustedCents: balanceAdjustedCents,
      insertedTransactionIds: insertedTransactionIds,
    );
  }

  Future<bool> _existsBySourceId({
    required int accountId,
    required String source,
    required String sourceId,
  }) async {
    final db = _dbOrThrow;
    if (sourceId.trim().isEmpty) return false;
    final existing =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.accountId.equals(accountId) &
                  t.source.equals(source) &
                  t.sourceId.equals(sourceId),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  Future<Map<String, int>> _categoryMapForDirection(String direction) async {
    final db = _dbOrThrow;
    final rows =
        await (db.select(db.categories)..where(
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

  String _effectiveDirectionForCategory(ExternalBillRecord record) {
    if (record.direction == 'income') return 'income';
    if (record.direction == 'expense') return 'expense';
    return record.pendingBaseDirection == 'income' ? 'income' : 'expense';
  }

  String _inferCategoryKey(ExternalBillRecord record) {
    final categoryDirection = _effectiveDirectionForCategory(record);
    final haystack =
        '${record.tradeType} ${record.counterparty ?? ''} ${record.memo ?? ''}'
            .toLowerCase();

    if (categoryDirection == 'income') {
      if (_containsAny(haystack, const ['salary', 'payroll', '工资']))
        return 'salary';
      if (_containsAny(haystack, const ['gift', '红包', '礼物'])) return 'gift';
      if (_containsAny(haystack, const ['refund', '退款'])) return 'refund';
      if (_containsAny(haystack, const ['transfer', '转账', 'zelle', 'zel']))
        return 'transfer';
      return 'other';
    }

    if (_containsAny(haystack, const [
      'food',
      '餐',
      'doordash',
      'mcdonald',
      'restaurant',
    ])) {
      return 'food';
    }
    if (_containsAny(haystack, const [
      'transport',
      '交通',
      'uber',
      'lyft',
      'taxi',
      'travel',
    ])) {
      return 'transport';
    }
    if (_containsAny(haystack, const [
      'shopping',
      '购物',
      'amazon',
      '淘宝',
      '京东',
    ])) {
      return 'shopping';
    }
    if (_containsAny(haystack, const [
      'entertainment',
      '娱乐',
      'steam',
      'game',
    ])) {
      return 'entertainment';
    }
    if (_containsAny(haystack, const [
      'utilities',
      '水电',
      'internet',
      'insurance',
    ])) {
      return 'utilities';
    }
    if (_containsAny(haystack, const ['health', '医疗', 'medical']))
      return 'health';
    if (_containsAny(haystack, const ['rent', '房租'])) return 'rent';
    if (_containsAny(haystack, const ['travel', '旅行', 'flight', 'hotel']))
      return 'travel';
    if (_containsAny(haystack, const ['transfer', '转账', 'web pmt']))
      return 'transfer';

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

    if (_looksLikePncCsv(rows)) return _parsePncCsvRows(rows, fileName);
    if (_looksLikeAlipay(rows, text)) return _parseAlipayRows(rows, fileName);
    if (_looksLikeWechat(rows, text)) return _parseWechatRows(rows, fileName);

    throw const FormatException(
      'Unsupported CSV format. Please use WeChat, Alipay, or PNC export files.',
    );
  }

  ExternalBillParsedData _parseXlsx(Uint8List bytes, String fileName) {
    final excel = xl.Excel.decodeBytes(bytes);
    final rows = <List<String>>[];
    for (final sheet in excel.tables.values) {
      for (final row in sheet.rows) {
        rows.add(
          row
              .map((cell) => _cellValueToString(cell?.value))
              .map(_cleanText)
              .toList(),
        );
      }
    }

    if (_looksLikeWechat(rows, '')) return _parseWechatRows(rows, fileName);
    if (_looksLikeAlipay(rows, '')) return _parseAlipayRows(rows, fileName);

    throw const FormatException(
      'Unsupported XLSX format. Please use WeChat or Alipay export files.',
    );
  }

  bool _looksLikePncCsv(List<List<String>> rows) {
    if (rows.isEmpty) return false;
    final header = rows.first.map(_normalizeHeader).join('|');
    return header.contains('transactiondate') &&
        header.contains('transactiondescription') &&
        header.contains('amount') &&
        header.contains('category') &&
        header.contains('balance');
  }

  ExternalBillParsedData _parsePncCsvRows(
    List<List<String>> rows,
    String fileName,
  ) {
    if (rows.isEmpty) {
      throw const FormatException('PNC CSV is empty.');
    }

    final headerMap = _buildHeaderMap(rows.first);
    final records = <ExternalBillRecord>[];
    int scanned = 0;
    int skipped = 0;
    int? latestBalanceCents;
    DateTime? latestBalanceAt;
    int? latestBalanceRowIndex;
    int? earliestBalanceCents;
    DateTime? earliestBalanceAt;
    int? earliestBalanceRowIndex;
    int? earliestBalanceAmountCents;
    String? earliestBalanceDirection;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      scanned++;

      final dateRaw = _cellByAliases(row, headerMap, const [
        'Transaction Date',
      ]);
      final desc = _cellByAliases(row, headerMap, const [
        'Transaction Description',
      ]);
      final amountRaw = _cellByAliases(row, headerMap, const ['Amount']);
      final category = _cellByAliases(row, headerMap, const ['Category']);
      final balanceRaw = _cellByAliases(row, headerMap, const ['Balance']);

      final occurredAt = _parsePncCsvDate(dateRaw);

      if (dateRaw.isEmpty || desc.isEmpty || amountRaw.isEmpty) {
        skipped++;
        continue;
      }
      if (occurredAt == null) {
        skipped++;
        continue;
      }

      final amount = _parseAmountAndCurrency(
        amountRaw,
        fallbackCurrency: 'USD',
      );
      if (amount.amountCents <= 0) {
        skipped++;
        continue;
      }

      final baseDirection = _parseDirectionFromSign(amountRaw);
      if (baseDirection == null) {
        skipped++;
        continue;
      }
      final parsedBalance = _parseSignedCents(balanceRaw);
      if (parsedBalance != null) {
        if (latestBalanceAt == null ||
            occurredAt.isAfter(latestBalanceAt) ||
            (occurredAt.isAtSameMomentAs(latestBalanceAt) &&
                (latestBalanceRowIndex == null || i < latestBalanceRowIndex))) {
          latestBalanceCents = parsedBalance;
          latestBalanceAt = occurredAt;
          latestBalanceRowIndex = i;
        }
        if (earliestBalanceAt == null ||
            occurredAt.isBefore(earliestBalanceAt) ||
            (occurredAt.isAtSameMomentAs(earliestBalanceAt) &&
                (earliestBalanceRowIndex == null ||
                    i < earliestBalanceRowIndex))) {
          earliestBalanceCents = parsedBalance;
          earliestBalanceAt = occurredAt;
          earliestBalanceRowIndex = i;
          earliestBalanceAmountCents = amount.amountCents;
          earliestBalanceDirection = baseDirection;
        }
      }

      final isPending = _isPncPendingRow(
        dateRaw: dateRaw,
        description: desc,
        category: category,
        balanceRaw: balanceRaw,
      );
      final direction = isPending ? 'pending' : baseDirection;

      final normalizedDesc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
      final sourceId =
          'pnc_csv|$fileName|$i|${occurredAt.toIso8601String()}|$direction|${amount.amountCents}|$normalizedDesc';

      records.add(
        ExternalBillRecord(
          type: ExternalBillType.pnc,
          source: 'pnc',
          sourceId: sourceId,
          occurredAt: occurredAt,
          direction: direction,
          pendingBaseDirection: isPending ? baseDirection : null,
          amountCents: amount.amountCents,
          currency: 'USD',
          counterparty: _inferPncCounterparty(desc),
          memo: _joinMemo([desc, category]),
          tradeType: category.isEmpty ? 'PNC' : category,
        ),
      );
    }

    return ExternalBillParsedData(
      fileName: fileName,
      type: ExternalBillType.pnc,
      currency: 'USD',
      scannedRows: scanned,
      skippedRows: skipped,
      records: records,
      latestBalanceCents: latestBalanceCents,
      latestBalanceAt: latestBalanceAt,
      earliestBalanceCents: earliestBalanceCents,
      earliestBalanceAt: earliestBalanceAt,
      earliestBalanceAmountCents: earliestBalanceAmountCents,
      earliestBalanceDirection: earliestBalanceDirection,
    );
  }

  bool _isPncPendingRow({
    required String dateRaw,
    required String description,
    required String category,
    required String balanceRaw,
  }) {
    final dateLower = dateRaw.toLowerCase();
    final descLower = description.toLowerCase();
    final categoryLower = category.toLowerCase();
    final balanceLower = balanceRaw.toLowerCase();
    return dateLower.contains('pending') ||
        descLower.contains('pending') ||
        categoryLower == 'pending' ||
        balanceLower == 'pending';
  }

  DateTime? _parsePncCsvDate(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
      return DateTime.tryParse(v);
    }

    final pending = RegExp(
      r'PENDING\s*-\s*(\d{2})/(\d{2})/(\d{4})',
      caseSensitive: false,
    ).firstMatch(v);
    if (pending != null) {
      final month = int.parse(pending.group(1)!);
      final day = int.parse(pending.group(2)!);
      final year = int.parse(pending.group(3)!);
      return DateTime(year, month, day);
    }

    final mdY = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(v);
    if (mdY != null) {
      final month = int.parse(mdY.group(1)!);
      final day = int.parse(mdY.group(2)!);
      final year = int.parse(mdY.group(3)!);
      return DateTime(year, month, day);
    }

    return null;
  }

  String? _parseDirectionFromSign(String amountRaw) {
    final v = amountRaw.trim();
    if (v.startsWith('-')) return 'expense';
    if (v.startsWith('+')) return 'income';
    return null;
  }

  String? _inferPncCounterparty(String desc) {
    final norm = desc.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (norm.isEmpty) return null;
    const prefixes = [
      'DEBIT CARD PURCHASE ',
      'RECURRING DEBIT CARD ',
      'POS PURCHASE ',
      'PAYPAL INST XFER ACH WEB ',
      'ZEL FROM ',
      'ZEL TO ',
      'ACH DEP ',
      'WEB PMT- ',
    ];
    for (final p in prefixes) {
      if (norm.toUpperCase().startsWith(p)) {
        return norm.substring(p.length).trim();
      }
    }
    return null;
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
    final lower = text.toLowerCase();
    return text.contains('交易时间') ||
        text.contains('支付宝') ||
        text.contains('微信支付') ||
        text.contains('收/支') ||
        (lower.contains('transaction date') &&
            lower.contains('transaction description'));
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
    return _findHeaderRow(rows, const ['交易时间', '交易分类', '交易订单号']) >= 0;
  }

  bool _looksLikeWechat(List<List<String>> rows, String rawText) {
    if (rawText.contains('微信支付')) return true;
    return _findHeaderRow(rows, const ['交易时间', '交易类型', '交易单号']) >= 0;
  }

  ExternalBillParsedData _parseWechatRows(
    List<List<String>> rows,
    String fileName,
  ) {
    final headerIndex = _findHeaderRow(rows, const [
      '交易时间',
      '交易类型',
      '交易对方',
      '收/支',
      '交易单号',
    ]);
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

      final amount = _parseAmountAndCurrency(
        amountRaw,
        fallbackCurrency: 'CNY',
      );
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

    return ExternalBillParsedData(
      fileName: fileName,
      type: ExternalBillType.wechatPay,
      currency: _majorCurrency(records, fallback: 'CNY'),
      scannedRows: scanned,
      skippedRows: skipped,
      records: records,
    );
  }

  ExternalBillParsedData _parseAlipayRows(
    List<List<String>> rows,
    String fileName,
  ) {
    final headerIndex = _findHeaderRow(rows, const [
      '交易时间',
      '交易分类',
      '交易对方',
      '收/支',
      '交易订单号',
    ]);
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

      final amount = _parseAmountAndCurrency(
        amountRaw,
        fallbackCurrency: 'CNY',
      );
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

    return ExternalBillParsedData(
      fileName: fileName,
      type: ExternalBillType.alipay,
      currency: _majorCurrency(records, fallback: 'CNY'),
      scannedRows: scanned,
      skippedRows: skipped,
      records: records,
    );
  }

  String _majorCurrency(
    List<ExternalBillRecord> records, {
    required String fallback,
  }) {
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
      if (exact != null) return _safeCell(row, exact);
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
        status.contains('已到账') ||
        status.toLowerCase().contains('success');
  }

  String? _parseDirection(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('支出') || v.contains('expense')) return 'expense';
    if (v.contains('收入') || v.contains('income')) return 'income';
    if (v.startsWith('-')) return 'expense';
    if (v.startsWith('+')) return 'income';
    return null;
  }

  DateTime? _parseOccurredAt(String raw) {
    final v = raw.trim().replaceAll('/', '-');
    if (v.isEmpty) return null;

    final direct = DateTime.tryParse(v);
    if (direct != null) return direct;

    final m = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
    ).firstMatch(v);
    if (m == null) return null;

    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(m.group(5) ?? '0') ?? 0;
    final second = int.tryParse(m.group(6) ?? '0') ?? 0;
    return DateTime(year, month, day, hour, minute, second);
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
    } else if (up.contains('¥') ||
        up.contains('CNY') ||
        up.contains('RMB') ||
        up.contains('￥')) {
      currency = 'CNY';
    }

    final match = RegExp(r'-?\d[\d,]*(?:\.\d+)?').firstMatch(text);
    final value = match == null
        ? 0.0
        : double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0.0;
    final cents = (value.abs() * 100).round();
    return _AmountWithCurrency(amountCents: cents, currency: currency);
  }

  int? _parseSignedCents(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'-?\d[\d,]*(?:\.\d+)?').firstMatch(text);
    if (match == null) return null;
    final numeric = match.group(0)!.replaceAll(',', '');
    final value = double.tryParse(numeric);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<bool> _accountHasAnyTransactions(int accountId) async {
    final db = _dbOrThrow;
    final one =
        await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(accountId))
              ..limit(1))
            .getSingleOrNull();
    return one != null;
  }

  Future<({int adjustedCents, String? txId})> _applyPncOpeningBalanceSeed({
    required int accountId,
    required ExternalBillParsedData parsed,
    required Map<String, int> expenseCategoryMap,
    required Map<String, int> incomeCategoryMap,
  }) async {
    final earliestBalance = parsed.earliestBalanceCents;
    final earliestAmount = parsed.earliestBalanceAmountCents;
    final earliestDirection = parsed.earliestBalanceDirection;
    if (earliestBalance == null ||
        earliestAmount == null ||
        earliestDirection == null) {
      return (adjustedCents: 0, txId: null);
    }
    final openingBalance = earliestDirection == 'expense'
        ? earliestBalance + earliestAmount
        : earliestBalance - earliestAmount;
    if (openingBalance == 0) {
      return (adjustedCents: 0, txId: null);
    }

    final db = _dbOrThrow;
    final direction = openingBalance > 0 ? 'income' : 'expense';
    final categoryMap = direction == 'income'
        ? incomeCategoryMap
        : expenseCategoryMap;
    final categoryId = categoryMap['other'];
    final occurredAt = (parsed.earliestBalanceAt ?? DateTime.now()).subtract(
      const Duration(seconds: 1),
    );

    final seedTxId = _uuid.v4();
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: seedTxId,
            source: const d.Value('pnc'),
            sourceId: d.Value(
              'pnc_opening_balance|$accountId|${parsed.fileName}|${occurredAt.microsecondsSinceEpoch}',
            ),
            accountId: accountId,
            direction: d.Value(direction),
            amountCents: openingBalance.abs(),
            currency: const d.Value('USD'),
            merchant: const d.Value('PNC Opening Balance'),
            memo: d.Value(
              'Seed from earliest CSV balance ${(earliestBalance / 100.0).toStringAsFixed(2)} USD '
              'and first transaction ${earliestDirection == 'expense' ? '-' : '+'}'
              '${(earliestAmount / 100.0).toStringAsFixed(2)} USD (${parsed.fileName})',
            ),
            categoryId: d.Value(categoryId),
            occurredAt: occurredAt,
            confidence: const d.Value(1.0),
          ),
        );
    return (adjustedCents: openingBalance, txId: seedTxId);
  }
}

class _PncDuplicateMatcher {
  final Map<String, List<_PncTxComparable>> _byKey =
      <String, List<_PncTxComparable>>{};

  _PncDuplicateMatcher(List<Transaction> existing) {
    for (final tx in existing) {
      final c = _PncTxComparable.fromTransaction(tx);
      final key = _key(c.dayKey, c.direction, c.amountCents);
      (_byKey[key] ??= <_PncTxComparable>[]).add(c);
    }
  }

  bool matches(ExternalBillRecord record) {
    final c = _PncTxComparable.fromRecord(record);
    final key = _key(c.dayKey, c.direction, c.amountCents);
    final candidates = _byKey[key];
    if (candidates == null || candidates.isEmpty) return false;
    for (final x in candidates) {
      if (_sameText(c.normalizedText, x.normalizedText)) {
        return true;
      }
    }
    return false;
  }

  void addRecord(ExternalBillRecord record) {
    final c = _PncTxComparable.fromRecord(record);
    final key = _key(c.dayKey, c.direction, c.amountCents);
    (_byKey[key] ??= <_PncTxComparable>[]).add(c);
  }

  String _key(String dayKey, String direction, int amountCents) =>
      '$dayKey|$direction|$amountCents';

  bool _sameText(String a, String b) {
    if (a.isEmpty && b.isEmpty) return true;
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    final minLen = a.length < b.length ? a.length : b.length;
    if (minLen < 6) return false;
    return a.contains(b) || b.contains(a);
  }
}

class _PncTxComparable {
  final String dayKey;
  final String direction;
  final int amountCents;
  final String normalizedText;

  const _PncTxComparable({
    required this.dayKey,
    required this.direction,
    required this.amountCents,
    required this.normalizedText,
  });

  factory _PncTxComparable.fromRecord(ExternalBillRecord record) {
    return _PncTxComparable(
      dayKey: _dayKey(record.occurredAt),
      direction: record.direction,
      amountCents: record.amountCents,
      normalizedText: _normalizePncComparableText(
        '${record.counterparty ?? ''} ${record.memo ?? ''} ${record.tradeType}',
      ),
    );
  }

  factory _PncTxComparable.fromTransaction(Transaction tx) {
    return _PncTxComparable(
      dayKey: _dayKey(tx.occurredAt),
      direction: tx.direction,
      amountCents: tx.amountCents,
      normalizedText: _normalizePncComparableText(
        '${tx.merchant ?? ''} ${tx.memo ?? ''}',
      ),
    );
  }

  static String _dayKey(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

String _normalizePncComparableText(String raw) {
  return raw
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _AmountWithCurrency {
  final int amountCents;
  final String currency;

  const _AmountWithCurrency({
    required this.amountCents,
    required this.currency,
  });
}

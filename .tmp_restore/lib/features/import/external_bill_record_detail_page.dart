import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import 'external_bill_import_service.dart';

class ExternalBillRecordDetailPage extends StatelessWidget {
  final ExternalBillRecord record;
  final int? index;

  const ExternalBillRecordDetailPage({
    super.key,
    required this.record,
    this.index,
  });

  String _fmtDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _directionLabel(BuildContext context, String direction) {
    return direction == 'income'
        ? tr(context, en: 'Income', zh: '收入')
        : tr(context, en: 'Expense', zh: '支出');
  }

  String _typeLabel(BuildContext context, ExternalBillType type) {
    switch (type) {
      case ExternalBillType.wechatPay:
        return tr(context, en: 'WeChat Pay', zh: '微信支付');
      case ExternalBillType.alipay:
        return tr(context, en: 'Alipay', zh: '支付宝');
      case ExternalBillType.unknown:
        return tr(context, en: 'Unknown', zh: '未知');
    }
  }

  String _fmtAmount(ExternalBillRecord r) {
    final abs = (r.amountCents.abs() / 100.0).toStringAsFixed(2);
    final sign = r.direction == 'income' ? '+' : '-';
    return '$sign$abs ${r.currency}';
  }

  @override
  Widget build(BuildContext context) {
    final title = index == null
        ? tr(context, en: 'Bill Detail', zh: '账单详情')
        : '${tr(context, en: 'Bill Detail', zh: '账单详情')} #$index';

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value.isEmpty ? '-' : value)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(
                    tr(context, en: 'Bill Type', zh: '账单类型'),
                    _typeLabel(context, record.type),
                  ),
                  row(
                    tr(context, en: 'Direction', zh: '收支方向'),
                    _directionLabel(context, record.direction),
                  ),
                  row(
                    tr(context, en: 'Amount', zh: '金额'),
                    _fmtAmount(record),
                  ),
                  row(
                    tr(context, en: 'Time', zh: '交易时间'),
                    _fmtDateTime(record.occurredAt),
                  ),
                  row(
                    tr(context, en: 'Counterparty', zh: '交易对方'),
                    record.counterparty ?? '',
                  ),
                  row(
                    tr(context, en: 'Trade Type', zh: '交易类型'),
                    record.tradeType,
                  ),
                  row(
                    tr(context, en: 'Source', zh: '来源'),
                    record.source,
                  ),
                  row(
                    tr(context, en: 'Source ID', zh: '来源单号'),
                    record.sourceId,
                  ),
                  row(
                    tr(context, en: 'Memo', zh: '备注'),
                    record.memo ?? '',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

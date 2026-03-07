import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/currency.dart';
import '../../../l10n/category_i18n.dart';
import '../../../l10n/tr.dart';
import '../models.dart';

class TxDetailPage extends StatelessWidget {
  final TxViewRow row;

  const TxDetailPage({
    super.key,
    required this.row,
  });

  String _fmtDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  String _fmtAmount() {
    final tx = row.tx;
    final sign = switch (tx.direction) {
      'income' => '+',
      'expense' => '-',
      'pending' => '~',
      _ => '~',
    };
    final symbol = currencySymbol(tx.currency);
    final amount = (tx.amountCents / 100.0).toStringAsFixed(2);
    return '$sign$symbol$amount';
  }

  String _sourceLabel(BuildContext context, String source) {
    switch (source) {
      case 'manual':
        return tr(context, en: 'Manual', zh: '手动');
      case 'alipay':
        return tr(context, en: 'Alipay', zh: '支付宝');
      case 'wechatpay':
        return tr(context, en: 'WeChat Pay', zh: '微信支付');
      default:
        return source;
    }
  }

  String _bestTitle(String categoryName) {
    final tx = row.tx;
    final merchant = tx.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) return merchant;
    final memo = tx.memo?.trim();
    if (memo != null && memo.isNotEmpty) return memo;
    return categoryName;
  }

  @override
  Widget build(BuildContext context) {
    final tx = row.tx;
    final scheme = Theme.of(context).colorScheme;
    final isIncome = tx.direction == 'income';
    final isPending = tx.direction == 'pending';
    final accent = isPending
        ? Colors.orange
        : (isIncome ? Colors.green : scheme.error);
    final accentSoft = accent.withValues(alpha: 0.14);
    final categoryName = row.category == null
        ? tr(context, en: 'Uncategorized', zh: '未分类')
        : categoryLabel(context, row.category!.name);
    final directionLabel = switch (tx.direction) {
      'income' => tr(context, en: 'Income', zh: '收入'),
      'expense' => tr(context, en: 'Expense', zh: '支出'),
      'pending' => tr(context, en: 'Pending', zh: '待处理'),
      _ => tx.direction,
    };
    final title = _bestTitle(categoryName);

    Future<void> copyText(String value) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, en: 'Copied', zh: '已复制'),
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    }

    Widget chip({
      required IconData icon,
      required String text,
      Color? color,
    }) {
      final c = color ?? scheme.primary;
      final bg = Color.alphaBlend(
        c.withValues(alpha: 0.88),
        scheme.surface,
      );
      final fg = bg.computeLuminance() < 0.46 ? Colors.white : Colors.black87;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.22),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12.8,
              ),
            ),
          ],
        ),
      );
    }

    Widget kvRow({
      required IconData icon,
      required String label,
      required String value,
      bool copyable = false,
    }) {
      final shown = value.trim().isEmpty ? '-' : value.trim();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 88,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(
                  shown,
                  style: const TextStyle(
                    fontSize: 14.2,
                    fontWeight: FontWeight.w600,
                    height: 1.28,
                  ),
                ),
              ),
            ),
            if (copyable && shown != '-')
              IconButton(
                tooltip: tr(context, en: 'Copy', zh: '复制'),
                onPressed: () => copyText(shown),
                icon: const Icon(Icons.copy_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      );
    }

    Widget section({
      required IconData icon,
      required String title,
      required List<Widget> children,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Transaction Detail', zh: '账单详情')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
              gradient: LinearGradient(
                colors: [
                  accentSoft,
                  scheme.surfaceContainerHighest,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _fmtAmount(),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip(
                      icon: isPending
                          ? Icons.schedule_rounded
                          : (isIncome
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded),
                      text: directionLabel,
                      color: accent,
                    ),
                    chip(
                      icon: Icons.category_rounded,
                      text: categoryName,
                      color: scheme.secondary,
                    ),
                    chip(
                      icon: Icons.currency_exchange_rounded,
                      text: tx.currency.toUpperCase(),
                      color: scheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          section(
            icon: Icons.schedule_rounded,
            title: tr(context, en: 'Basic Info', zh: '基础信息'),
            children: [
              kvRow(
                icon: Icons.event_rounded,
                label: tr(context, en: 'Occurred At', zh: '发生时间'),
                value: _fmtDateTime(tx.occurredAt),
              ),
              kvRow(
                icon: Icons.storefront_rounded,
                label: tr(context, en: 'Merchant', zh: '商户'),
                value: tx.merchant ?? '',
              ),
              kvRow(
                icon: Icons.notes_rounded,
                label: tr(context, en: 'Memo', zh: '备注'),
                value: tx.memo ?? '',
              ),
            ],
          ),
          section(
            icon: Icons.source_rounded,
            title: tr(context, en: 'Source Info', zh: '来源信息'),
            children: [
              kvRow(
                icon: Icons.link_rounded,
                label: tr(context, en: 'Source', zh: '来源'),
                value: _sourceLabel(context, tx.source),
              ),
              kvRow(
                icon: Icons.tag_rounded,
                label: tr(context, en: 'Source ID', zh: '来源单号'),
                value: tx.sourceId ?? '',
                copyable: true,
              ),
              kvRow(
                icon: Icons.fingerprint_rounded,
                label: tr(context, en: 'ID', zh: '交易ID'),
                value: tx.id,
                copyable: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';

class TxTile extends StatelessWidget {
  final String id;
  final String time;
  final String title;
  final String? subtitle;
  final double amount;
  final bool isIncome;
  final bool isPending;
  final String currencySymbol;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onTap;

  const TxTile({
    super.key,
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isIncome,
    this.isPending = false,
    required this.currencySymbol,
    required this.onDelete,
    required this.onEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moneyColor = isPending
        ? Colors.orange
        : (isIncome ? scheme.tertiary : scheme.error);
    final amountPrefix = isPending ? '~' : (isIncome ? '+' : '-');

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      secondaryBackground: Container(
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        }

        return (await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(
                  tr(context, en: 'Delete transaction?', zh: '删除这条交易？'),
                ),
                content: Text(
                  tr(
                    context,
                    en: 'Delete $amountPrefix$currencySymbol${amount.toStringAsFixed(2)}?',
                    zh: '确定删除 ${isIncome ? '+' : '-'}$currencySymbol${amount.toStringAsFixed(2)} 吗？',
                  ),
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(tr(context, en: 'Cancel', zh: '取消')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(tr(context, en: 'Delete', zh: '删除')),
                  ),
                ],
              ),
            )) ??
            false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
        child: ListTile(
          dense: true,
          minVerticalPadding: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: moneyColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
          trailing: Text(
            '$amountPrefix$currencySymbol${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
              color: moneyColor,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

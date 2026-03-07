import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import '../../../l10n/tr.dart';
import '../../../l10n/category_i18n.dart';
import '../models.dart';
import 'day_header.dart';
import 'tx_tile.dart';

typedef TxId = String;

class LedgerTxListPanel extends StatelessWidget {
  final List<TxViewRow> txs;
  final bool selectMode;
  final Set<TxId> selectedIds;

  final void Function(TxId id) onEnterSelectWithId;
  final void Function(TxId id, bool selectedNow) onToggleSelected;

  final Future<void> Function(TxViewRow row) onEdit;
  final Future<void> Function(TxViewRow row) onDelete;

  const LedgerTxListPanel({
    super.key,
    required this.txs,
    required this.selectMode,
    required this.selectedIds,
    required this.onEnterSelectWithId,
    required this.onToggleSelected,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmtDay(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 64);

    // Build mixed list: day headers + tx items.
    final items = <Object>[];
    String? currentDay;
    for (final r in txs) {
      final day = _fmtDay(r.tx.occurredAt);
      if (day != currentDay) {
        currentDay = day;
        items.add(day);
      }
      items.add(r);
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: txs.isEmpty
            ? Center(child: Text(tr(context, en: 'No transactions yet', zh: '还没有记录')))
            : ListView.builder(
                key: const ValueKey('tx_list'),
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  if (item is String) {
                    return DayHeader(title: item);
                  }

                  final row = item as TxViewRow;
                  final tx = row.tx;

                  final isIncomeTx = tx.direction == 'income';
                  final amount = tx.amountCents / 100.0;
                  final time = _fmtTime(tx.occurredAt);

                  final rawCat = row.category?.name;
                  final categoryText = rawCat == null
                      ? tr(context, en: 'Uncategorized', zh: '未分类')
                      : categoryLabel(context, rawCat);

                  final content = (tx.merchant?.trim().isNotEmpty == true)
                      ? tx.merchant!.trim()
                      : (tx.memo?.trim().isNotEmpty == true)
                          ? tx.memo!.trim()
                          : categoryText;

                  final detail = (tx.merchant?.trim().isNotEmpty == true && tx.memo?.trim().isNotEmpty == true)
                      ? tx.memo!.trim()
                      : null;

                  final subtitle = detail == null ? categoryText : '$categoryText · $detail';
                  final selected = selectedIds.contains(tx.id);

                  return InkWell(
                    onLongPress: () => onEnterSelectWithId(tx.id),
                    onTap: !selectMode ? null : () => onToggleSelected(tx.id, selected),
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: selectMode ? 44 : 0),
                          child: IgnorePointer(
                            ignoring: selectMode,
                            child: TxTile(
                              id: tx.id,
                              time: time,
                              title: content,
                              subtitle: subtitle,
                              amount: amount,
                              isIncome: isIncomeTx,
                              currencySymbol: currencySymbol(tx.currency),
                              onEdit: () => onEdit(row),
                              onDelete: () => onDelete(row),
                            ),
                          ),
                        ),
                        if (selectMode)
                          Positioned(
                            left: -4,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Checkbox(
                                value: selected,
                                onChanged: (_) {},
                                fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return const Color(0xFF22C55E);
                                  }
                                  return Colors.transparent;
                                }),
                                checkColor: Colors.black,
                                side: const BorderSide(color: Colors.black, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import '../../../l10n/category_i18n.dart';
import '../../../l10n/tr.dart';
import '../ledger_list_entries.dart';
import '../models.dart';
import 'day_header.dart';
import 'panel_container.dart';
import 'tx_tile.dart';

class LedgerTxListArea extends StatelessWidget {
  final List<TxViewRow> txs;
  final List<LedgerListEntry> items;

  final bool selectMode;
  final Set<String> selectedIds;

  final String Function(DateTime dt) fmtTime;
  final void Function(String id) onEnterSelectWith;
  final void Function(String id) onToggleSelected;
  final void Function(TxViewRow row) onOpenTxDetail;

  final Future<void> Function(TxViewRow row) onEditTx;
  final Future<void> Function(String id) onDeleteTx;
  final Future<void> Function()? onRefresh;
  final Key? firstTransactionKey;

  const LedgerTxListArea({
    super.key,
    required this.txs,
    required this.items,
    required this.selectMode,
    required this.selectedIds,
    required this.fmtTime,
    required this.onEnterSelectWith,
    required this.onToggleSelected,
    required this.onOpenTxDetail,
    required this.onEditTx,
    required this.onDeleteTx,
    this.onRefresh,
    this.firstTransactionKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildList() {
      return Scrollbar(
        thumbVisibility: true,
        child: ListView.builder(
          key: const ValueKey('tx_list'),
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final firstTxId = txs.isEmpty ? null : txs.first.tx.id;
            final item = items[index];
            if (item is LedgerHeaderEntry) {
              return DayHeader(title: item.title);
            }

            final row = (item as LedgerTxEntry).row;
            final tx = row.tx;

            final isIncomeTx = tx.direction == 'income';
            final isPendingTx = tx.direction == 'pending';
            final amount = tx.amountCents / 100.0;
            final time = fmtTime(tx.occurredAt);

            final rawCat = row.category?.name;
            final categoryText = rawCat == null
                ? tr(context, en: 'Uncategorized', zh: '未分类')
                : categoryLabel(context, rawCat);

            final content = (tx.merchant?.trim().isNotEmpty == true)
                ? tx.merchant!.trim()
                : (tx.memo?.trim().isNotEmpty == true)
                ? tx.memo!.trim()
                : categoryText;

            final detail =
                (tx.merchant?.trim().isNotEmpty == true &&
                    tx.memo?.trim().isNotEmpty == true)
                ? tx.memo!.trim()
                : null;

            final directionHint = isPendingTx
                ? tr(context, en: 'Pending', zh: '待处理')
                : null;
            final subtitle = detail == null
                ? (directionHint == null
                      ? categoryText
                      : '$directionHint | $categoryText')
                : (directionHint == null
                      ? '$categoryText | $detail'
                      : '$directionHint | $categoryText | $detail');
            final selected = selectedIds.contains(tx.id);

            final tile = InkWell(
              onLongPress: () => onEnterSelectWith(tx.id),
              onTap: selectMode ? () => onToggleSelected(tx.id) : null,
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
                        isPending: isPendingTx,
                        currencySymbol: currencySymbol(tx.currency),
                        onEdit: () => onEditTx(row),
                        onDelete: () => onDeleteTx(tx.id),
                        onTap: selectMode ? null : () => onOpenTxDetail(row),
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
                          fillColor: WidgetStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return const Color(0xFF22C55E);
                            }
                            return Colors.transparent;
                          }),
                          checkColor: Colors.black,
                          side: const BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
            if (firstTransactionKey != null &&
                firstTxId != null &&
                tx.id == firstTxId) {
              return KeyedSubtree(key: firstTransactionKey, child: tile);
            }
            return tile;
          },
        ),
      );
    }

    Widget buildEmpty() {
      if (onRefresh == null) {
        return Center(
          child: Text(tr(context, en: 'No transactions yet', zh: '还没有记录')),
        );
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(tr(context, en: 'No transactions yet', zh: '还没有记录')),
          ),
        ],
      );
    }

    Widget child = txs.isEmpty ? buildEmpty() : buildList();
    if (onRefresh != null) {
      child = RefreshIndicator(onRefresh: onRefresh!, child: child);
    }

    return PanelContainer(child: child);
  }
}

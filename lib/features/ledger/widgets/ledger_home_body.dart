import 'package:flutter/material.dart';

import '../models.dart';
import 'ledger_tx_list_panel.dart';

class LedgerHomeBody extends StatelessWidget {
  const LedgerHomeBody({
    super.key,
    required this.txListAreaKey,
    required this.txs,
    required this.selectMode,
    required this.selectedIds,
    required this.onEnterSelectWithId,
    required this.onToggleSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final GlobalKey txListAreaKey;
  final List<TxViewRow> txs;
  final bool selectMode;
  final Set<String> selectedIds;
  final void Function(String id) onEnterSelectWithId;
  final void Function(String id, bool selectedNow) onToggleSelected;
  final Future<void> Function(TxViewRow row) onEdit;
  final Future<void> Function(TxViewRow row) onDelete;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: RepaintBoundary(
          key: txListAreaKey,
          child: Semantics(
            label: 'transactions_list_area',
            child: LedgerTxListPanel(
              txs: txs,
              selectMode: selectMode,
              selectedIds: selectedIds,
              onEnterSelectWithId: onEnterSelectWithId,
              onToggleSelected: onToggleSelected,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';

class LedgerHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LedgerHomeAppBar({
    super.key,
    required this.selectMode,
    required this.selectedCount,
    required this.onOpenDrawer,
    required this.onCancelSelect,
    required this.onDeleteSelected,
    required this.canDeleteSelected,
    required this.currentAccountName,
    required this.onSwitchAccount,
  });

  final bool selectMode;
  final int selectedCount;
  final VoidCallback onOpenDrawer;
  final VoidCallback onCancelSelect;
  final VoidCallback onDeleteSelected;
  final bool canDeleteSelected;
  final String currentAccountName;
  final VoidCallback onSwitchAccount;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: selectMode
          ? IconButton(
              tooltip: tr(context, en: 'Cancel', zh: '取消'),
              icon: const Icon(Icons.close),
              onPressed: onCancelSelect,
            )
          : IconButton(
              tooltip: tr(context, en: 'Menu', zh: '菜单'),
              icon: const Icon(Icons.menu_rounded),
              onPressed: onOpenDrawer,
            ),
      title: selectMode
          ? Text(
              tr(
                context,
                en: 'Selected $selectedCount',
                zh: '已选 $selectedCount',
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    currentAccountName.isEmpty
                        ? tr(context, en: 'Ledger', zh: '记账')
                        : '$currentAccountName · ${tr(context, en: 'Ledger', zh: '记账')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, en: 'Switch account', zh: '切换账户'),
                  onPressed: onSwitchAccount,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                ),
              ],
            ),
      actions: selectMode
          ? [
              IconButton(
                tooltip: tr(context, en: 'Delete', zh: '删除'),
                icon: const Icon(Icons.delete_forever),
                onPressed: canDeleteSelected ? onDeleteSelected : null,
              ),
            ]
          : null,
    );
  }
}

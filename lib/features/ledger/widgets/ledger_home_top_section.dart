import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';
import 'balance_card.dart';
import 'ledger_quick_actions.dart';
import 'ledger_search_panel.dart';

class HomeQuickActionDef {
  const HomeQuickActionDef({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
}

class LedgerHomeTopSection extends StatelessWidget {
  const LedgerHomeTopSection({
    super.key,
    required this.db,
    required this.balance,
    required this.currencySymbol,
    required this.isLow,
    required this.searchOpen,
    required this.onToggleSearch,
    required this.onOpenAdd,
    required this.slot3,
    required this.slot4,
    required this.filterState,
    required this.onFilterChanged,
  });

  final AppDatabase db;
  final double balance;
  final String currencySymbol;
  final bool isLow;
  final bool searchOpen;
  final VoidCallback onToggleSearch;
  final VoidCallback onOpenAdd;
  final HomeQuickActionDef slot3;
  final HomeQuickActionDef slot4;
  final LedgerFilterState filterState;
  final ValueChanged<LedgerFilterState> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 720;
          final panelWidth = isNarrow ? 126.0 : 134.0;
          final panelHeight = isNarrow ? 68.0 : 74.0;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: panelHeight,
                      child: BalanceCard(
                        balance: balance,
                        currencySymbol: currencySymbol,
                        isLow: isLow,
                        accentColor: isLow ? Colors.red : Colors.green,
                        compact: true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: panelWidth,
                    height: panelHeight,
                    child: LedgerQuickActions(
                      isSearchOpen: searchOpen,
                      onToggleSearch: onToggleSearch,
                      onOpenAdd: onOpenAdd,
                      slot3Icon: slot3.icon,
                      slot3Tooltip: slot3.tooltip,
                      onSlot3: slot3.onTap,
                      slot4Icon: slot4.icon,
                      slot4Tooltip: slot4.tooltip,
                      onSlot4: slot4.onTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: searchOpen
                    ? LedgerSearchPanel(
                        db: db,
                        value: filterState,
                        onChanged: onFilterChanged,
                      )
                    : const SizedBox.shrink(),
              ),
              if (!searchOpen)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr(
                        context,
                        en: 'Tip: open search to filter by date/type/keyword',
                        zh: '提示：打开搜索可按日期/类型/关键词筛选',
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

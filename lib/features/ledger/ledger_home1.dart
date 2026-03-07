import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import 'widgets/balance_card.dart';
import 'widgets/balance_alert.dart';
import '../../data/db/app_database.dart';
import '../../l10n/tr.dart';
import '../../l10n/category_i18n.dart';
import 'add_transaction_page.dart';
import 'models.dart';
import '../settings/settings_page.dart';
import 'widgets/day_header.dart';
import 'widgets/tx_tile.dart';
import '../reports/history_page.dart';
import '../reports/widgets/monthly_stats_sheet.dart';

class LedgerHome extends StatelessWidget {
  final AppDatabase db;
  final VoidCallback onToggleLocale;

  const LedgerHome({super.key, required this.db, required this.onToggleLocale});

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
    final query = (db.select(db.transactions)
          ..orderBy([
            (t) => d.OrderingTerm(expression: t.occurredAt, mode: d.OrderingMode.desc),
          ]))
        .join([
      d.leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);

    final stream = query.watch().map((rows) {
      return rows.map((r) {
        final tx = r.readTable(db.transactions);
        final cat = r.readTableOrNull(db.categories);
        return TxViewRow(tx: tx, category: cat);
      }).toList();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Ledger ✅', zh: '记账 ✅')),
        actions: [
          IconButton(
            tooltip: tr(context, en: 'Settings', zh: '设置'),
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          TextButton(
            onPressed: onToggleLocale,
            child: Text(Localizations.localeOf(context).languageCode == 'zh' ? 'EN' : '中'),
          ),
        ],
      ),
      body: StreamBuilder<List<TxViewRow>>(
        stream: stream,
        builder: (context, snapshot) {
          final txs = snapshot.data ?? const <TxViewRow>[];

          int income = 0;
          int expense = 0;
          for (final r in txs) {
            if (r.tx.direction == 'income') {
              income += r.tx.amountCents;
            } else {
              expense += r.tx.amountCents;
            }
          }
          final balance = (income - expense) / 100.0;

          final items = <ListItem>[];
          String? currentDay;
          for (final r in txs) {
            final day = _fmtDay(r.tx.occurredAt);
            if (day != currentDay) {
              currentDay = day;
              items.add(HeaderItem(day));
            }
            items.add(TxItem(r));
          }

          return Column(
            children: [
              BalanceCard(balance: balance),
              BalanceAlert(balance: balance),
              const Divider(height: 1),
              Expanded(
                child: txs.isEmpty
                    ? Center(child: Text(tr(context, en: 'No transactions yet', zh: '还没有记录')))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          if (item is HeaderItem) {
                            return DayHeader(title: item.title);
                          }

                          final txItem = item as TxItem;
                          final row = txItem.row;
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

                          return TxTile(
                            time: time,
                            title: content,
                            subtitle: subtitle,
                            amount: amount,
                            isIncome: isIncomeTx,
                            onDelete: () async {
                              await (db.delete(db.transactions)..where((t) => t.id.equals(tx.id))).go();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),

      // 你底部三按钮的导航（如果你已实现就保留；没有也不影响本次翻译修复）
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: const Border(top: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.white.withOpacity(0.92),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      ),
                      builder: (_) => MonthlyStatsSheet(db: db),
                    );
                  },
                  icon: const Icon(Icons.analytics_rounded),
                  label: Text(tr(context, en: 'Stats', zh: '统计')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage()));
                  },
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(tr(context, en: 'History', zh: '历史')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionPage(db: db)));
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(tr(context, en: 'Add', zh: '添加')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
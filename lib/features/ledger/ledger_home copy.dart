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

// ✅ 新增：识图批量导入页
import 'transaction_image_import_page.dart';

class LedgerHome extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onToggleLocale;

  const LedgerHome({super.key, required this.db, required this.onToggleLocale});

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  // 用于截图/识别交易列表区域（必须是 GlobalKey 才能拿到 currentContext）
  final GlobalKey _txListAreaKey = GlobalKey(debugLabel: 'tx_list_area');

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
    final db = widget.db;
    final onToggleLocale = widget.onToggleLocale;

    Future<int?> categoryIdForKey(String key) async {
      final q = (db.select(db.categories)..where((c) => c.name.equals(key)));
      final row = await q.getSingleOrNull();
      return row?.id;
    }

    Future<void> importFromImage() async {
      final drafts = await TransactionImageImportPage.open(context);
      if (drafts == null || drafts.isEmpty) return;

      int ok = 0;
      int fail = 0;

      // 批量写入：逐条插入（简单可靠）
      for (final t in drafts) {
        try {
          final catId = t.categoryKey == null ? null : await categoryIdForKey(t.categoryKey!);

          final txId = DateTime.now().microsecondsSinceEpoch.toString();
          // 如果你有多账户，这里应该换成你当前选择的 accountId
          // 如果你有多账户，这里应该换成你当前选择的 accountId
          const int accountId = 1;
          await db.into(db.transactions).insert(
            TransactionsCompanion(
              id: d.Value(txId),
              accountId: d.Value(accountId),

              direction: d.Value(t.isExpense ? 'expense' : 'income'),
              amountCents: d.Value(t.amountCents),
              occurredAt: d.Value(t.occurredAt),

              categoryId: catId == null ? const d.Value.absent() : d.Value(catId),
              merchant: t.merchant.trim().isEmpty ? const d.Value.absent() : d.Value(t.merchant.trim()),
              memo: (t.memo == null || t.memo!.trim().isEmpty)
                  ? const d.Value.absent()
                  : d.Value(t.memo!.trim()),
            ),
          );
          ok++;
        } catch (_) {
          fail++;
        }
      }

      if (!context.mounted) return;
      final msg = fail == 0
          ? tr(context, en: 'Imported $ok transactions', zh: '已导入 $ok 条记录')
          : tr(context, en: 'Imported $ok, failed $fail', zh: '已导入 $ok 条，失败 $fail 条');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

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
          // ✅ 新增：识图导入入口（也放在底部按钮里了，两处都能用）
          IconButton(
            tooltip: tr(context, en: 'Import from image', zh: '识图导入'),
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: importFromImage,
          ),
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

          final items = <_ListEntry>[];
          String? currentDay;
          for (final r in txs) {
            final day = _fmtDay(r.tx.occurredAt);
            if (day != currentDay) {
              currentDay = day;
              items.add(_HeaderEntry(day));
            }
            items.add(_TxEntry(r));
          }

          return Column(
            children: [
              BalanceCard(balance: balance),
              BalanceAlert(balance: balance),
              const Divider(height: 1),
              Expanded(
                child: RepaintBoundary(
                  key: _txListAreaKey,
                  child: Semantics(
                  label: 'transactions_list_area',
                  child: Container(
                    key: const ValueKey('tx_list_area'),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: txs.isEmpty
                        ? Center(
                            child: Text(
                              tr(context, en: 'No transactions yet', zh: '还没有记录'),
                            ),
                          )
                        : ListView.builder(
                            key: const ValueKey('tx_list'),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              if (item is _HeaderEntry) return DayHeader(title: item.title);
                              final txItem = item as _TxEntry;
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

                              final detail =
                                  (tx.merchant?.trim().isNotEmpty == true && tx.memo?.trim().isNotEmpty == true)
                                      ? tx.memo!.trim()
                                      : null;

                              final subtitle = detail == null ? categoryText : '$categoryText · $detail';

                              return TxTile(
                                id: tx.id,
                                time: time,
                                title: content,
                                subtitle: subtitle,
                                amount: amount,
                                isIncome: isIncomeTx,
                                onEdit: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionPage(
                                        db: db,
                                        initialTx: tx,
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () async {
                                  await (db.delete(db.transactions)..where((t) => t.id.equals(tx.id))).go();
                                },
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
            ],
          );
        },
      ),

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
                      enableDrag: true,
                      isDismissible: true,
                      backgroundColor: Colors.transparent,
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
                child: OutlinedButton.icon(
                  onPressed: importFromImage,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: Text(tr(context, en: 'Scan', zh: '识图')),
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

abstract class _ListEntry {
  const _ListEntry();
}

class _HeaderEntry extends _ListEntry {
  final String title;
  const _HeaderEntry(this.title);
}

class _TxEntry extends _ListEntry {
  final TxViewRow row;
  const _TxEntry(this.row);
}
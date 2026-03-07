import 'package:flutter/material.dart';

import '../../app/currency.dart';
import '../../l10n/category_i18n.dart';
import 'report_detail_texts.dart';
import 'models.dart';
import 'widgets/expense_pie.dart';
import 'widgets/income_expense_bar.dart';

class ReportDetailPage extends StatelessWidget {
  final MonthlyReport report;
  final String currencyCode;

  const ReportDetailPage({
    super.key,
    required this.report,
    required this.currencyCode,
  });

  String _two(int n) => n.toString().padLeft(2, '0');
  String _dayKey(DateTime dt) => '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  String _catLabel(BuildContext context, String key) {
    if (key == '__other__') return rdt(context, 'Other');
    return categoryLabel(context, key);
  }

  @override
  Widget build(BuildContext context) {
    final sym = currencySymbol(currencyCode);
    final net = report.netCents / 100.0;
    final netColor = net >= 0 ? Colors.green : Colors.red;

    final txs = List<MonthlyTx>.from(report.transactions)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final groups = <String, List<MonthlyTx>>{};
    for (final t in txs) {
      (groups[_dayKey(t.occurredAt)] ??= []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Text('${rdt(context, 'Report')} ${report.monthKey}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IncomeExpenseBar(
            incomeCents: report.incomeCents,
            expenseCents: report.expenseCents,
            expenseLabel: rdt(context, 'Expense'),
            incomeLabel: rdt(context, 'Income'),
            currencySymbol: sym,
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              net >= 0
                  ? '+$sym${net.toStringAsFixed(2)}'
                  : '-$sym${(-net).toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: netColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            rdt(context, 'Spending Summary'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ExpensePie(
            expenseByCategoryCents: report.expenseByCategoryCents,
            currencySymbol: sym,
          ),
          const SizedBox(height: 18),
          Text(
            rdt(context, 'Details'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                rdt(
                  context,
                  'No transaction details saved in this report yet.',
                ),
              ),
            )
          else
            ...keys.expand((day) {
              final list = groups[day]!;
              return [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...list.map((t) {
                  final isIncome = t.direction == 'income';
                  final isPending = t.direction == 'pending';
                  final amt = t.amountCents / 100.0;
                  final amtPrefix = isPending
                      ? '~$sym'
                      : (isIncome ? '+$sym' : '-$sym');
                  final amtStr = amtPrefix + amt.abs().toStringAsFixed(2);
                  final amtColor = isPending
                      ? Colors.orange
                      : (isIncome ? Colors.green : Colors.red);
                  final timeStr =
                      '${_two(t.occurredAt.hour)}:${_two(t.occurredAt.minute)}';
                  final title =
                      (t.merchant != null && t.merchant!.trim().isNotEmpty)
                      ? t.merchant!.trim()
                      : _catLabel(context, t.categoryName);
                  final subtitle = [
                    timeStr,
                    if (isPending) rdt(context, 'Pending'),
                    _catLabel(context, t.categoryName),
                    if (t.memo != null && t.memo!.trim().isNotEmpty)
                      t.memo!.trim(),
                  ].join(' | ');

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        isPending
                            ? Icons.schedule_rounded
                            : (isIncome
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward),
                        color: amtColor,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(subtitle),
                      trailing: Text(
                        amtStr,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: amtColor,
                        ),
                      ),
                    ),
                  );
                }),
              ];
            }),
        ],
      ),
    );
  }
}

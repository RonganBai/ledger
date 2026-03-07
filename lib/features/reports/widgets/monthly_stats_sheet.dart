import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import 'monthly_stats_sheet_texts.dart';
import '../models.dart';
import '../report_service.dart';
import 'balance_trend_line.dart';
import 'expense_pie.dart';
import 'income_expense_bar.dart';

class MonthlyStatsSheet extends StatefulWidget {
  final ReportService service;
  final String currencyCode;

  const MonthlyStatsSheet({
    super.key,
    required this.service,
    required this.currencyCode,
  });

  @override
  State<MonthlyStatsSheet> createState() => _MonthlyStatsSheetState();
}

class _MonthlyStatsSheetState extends State<MonthlyStatsSheet> {
  int _index = 0;
  late final PageController _page;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    _page.animateToPage(
      i,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      mst(context, '7D'),
      mst(context, 'Month'),
      mst(context, 'Year'),
    ];

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _SegTabs(tabs: tabs, index: _index, onChanged: _go),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PageView(
            controller: _page,
            onPageChanged: (i) => setState(() => _index = i),
            children: [
              _PeriodPage(
                reportFuture: widget.service.getReportLast7Days(),
                balanceTrendFuture: widget.service
                    .getDailyBalanceTrendLast7Days(),
                currencyCode: widget.currencyCode,
              ),
              _PeriodPage(
                reportFuture: widget.service.getReportForMonth(DateTime.now()),
                balanceTrendFuture: widget.service.getDailyBalanceTrendForMonth(
                  DateTime.now(),
                ),
                currencyCode: widget.currencyCode,
              ),
              _PeriodPage(
                reportFuture: widget.service.getReportForYear(
                  DateTime.now().year,
                ),
                balanceTrendFuture: widget.service
                    .getMonthlyBalanceTrendForYear(DateTime.now().year),
                currencyCode: widget.currencyCode,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegTabs extends StatelessWidget {
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;

  const _SegTabs({
    required this.tabs,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 120);

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / tabs.length;
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border, width: 1.2),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                left: tabWidth * index + 10,
                top: 4,
                bottom: 4,
                width: tabWidth - 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                children: List.generate(tabs.length, (i) {
                  final selected = index == i;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => onChanged(i),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? scheme.onPrimary
                                : scheme.onSurface.withValues(alpha: 160),
                          ),
                          child: Text(tabs[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeriodPage extends StatelessWidget {
  final Future<MonthlyReport> reportFuture;
  final Future<List<TrendPoint>> balanceTrendFuture;
  final String currencyCode;

  const _PeriodPage({
    required this.reportFuture,
    required this.balanceTrendFuture,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(currencyCode);

    return FutureBuilder<MonthlyReport>(
      future: reportFuture,
      builder: (context, rep) {
        if (!rep.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final r = rep.data!;

        final diffCents = r.incomeCents - r.expenseCents;
        final diffColor = diffCents >= 0 ? Colors.green : Colors.red;
        final diffAbs = (diffCents.abs() / 100.0).toStringAsFixed(2);
        final diffText = '${diffCents >= 0 ? '+' : '-'}$symbol$diffAbs';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: IncomeExpenseBar(
                      incomeCents: r.incomeCents,
                      expenseCents: r.expenseCents,
                      incomeLabel: mst(context, 'Income'),
                      expenseLabel: mst(context, 'Expense'),
                      currencySymbol: symbol,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        width: 1.2,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 140),
                      ),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mst(context, 'Net')),
                        const SizedBox(height: 4),
                        Text(
                          diffText,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: diffColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<TrendPoint>>(
                future: balanceTrendFuture,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return BalanceTrendLine(
                    data: snap.data!,
                    title: mst(context, 'Balance Trend'),
                    primaryLabel: mst(context, 'Balance'),
                    currencySymbol: symbol,
                  );
                },
              ),
              const SizedBox(height: 18),
              ExpensePie(
                expenseByCategoryCents: r.expenseByCategoryCents,
                currencySymbol: symbol,
              ),
            ],
          ),
        );
      },
    );
  }
}

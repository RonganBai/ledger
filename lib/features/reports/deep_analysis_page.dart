import 'dart:math' as math;

import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../../app/currency.dart';
import '../../data/db/app_database.dart';
import '../../l10n/category_i18n.dart';
import 'deep_analysis_texts.dart';
import 'widgets/balance_trend_line.dart';
import 'widgets/expense_pie.dart';

class DeepAnalysisPage extends StatefulWidget {
  final AppDatabase db;
  final int accountId;
  final String accountCurrency;

  const DeepAnalysisPage({
    super.key,
    required this.db,
    required this.accountId,
    required this.accountCurrency,
  });

  @override
  State<DeepAnalysisPage> createState() => _DeepAnalysisPageState();
}

class _DeepAnalysisPageState extends State<DeepAnalysisPage> {
  static const _allCat = '__all__';
  int _months = 12;
  String _peakCategory = _allCat;
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(rangeMonths: _months, peakCategory: _peakCategory);
  }

  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _nextMonth(DateTime d) => DateTime(d.year, d.month + 1, 1);

  String _mk(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  String _money(int cents) =>
      '${currencySymbol(widget.accountCurrency)}${(cents.abs() / 100.0).toStringAsFixed(2)}';

  String _rangeLabel() => '${_months}M';

  bool _inRange(DateTime t, DateTime from, DateTime toExclusive) =>
      !t.isBefore(from) && t.isBefore(toExclusive);

  int _focusMonthIndex(List<_MonthAgg> months) {
    if (months.isEmpty) return 0;
    if (months.length >= 2) return months.length - 2; // last full month
    return months.length - 1;
  }

  Future<_Data> _load({
    required int rangeMonths,
    required String peakCategory,
  }) async {
    final now = DateTime.now();
    final month0 = _monthStart(now);
    final fromMonth = DateTime(
      month0.year,
      month0.month - (rangeMonths - 1),
      1,
    );
    final peakFrom = _dayStart(now).subtract(const Duration(days: 59));
    final queryFrom = fromMonth.isBefore(peakFrom) ? fromMonth : peakFrom;
    final queryTo = _nextMonth(month0);

    final txs =
        await (widget.db.select(widget.db.transactions)
              ..where((t) => t.accountId.equals(widget.accountId))
              ..where((t) => t.occurredAt.isBetweenValues(queryFrom, queryTo))
              ..orderBy([(t) => d.OrderingTerm(expression: t.occurredAt)]))
            .get();

    final rangeTxCount = txs
        .where((t) => _inRange(t.occurredAt, fromMonth, queryTo))
        .length;

    final cats = await widget.db.select(widget.db.categories).get();
    final catNameById = {for (final c in cats) c.id: c.name};

    final months = <_MonthAgg>[];
    final byMonth = <String, _MonthAgg>{};
    for (int i = 0; i < rangeMonths; i++) {
      final m = DateTime(fromMonth.year, fromMonth.month + i, 1);
      final agg = _MonthAgg(m);
      months.add(agg);
      byMonth[_mk(m)] = agg;
    }

    final peakDaily = <DateTime, int>{};
    final peakCatTotals = <String, int>{};
    for (
      DateTime d = peakFrom;
      !d.isAfter(_dayStart(now));
      d = d.add(const Duration(days: 1))
    ) {
      peakDaily[d] = 0;
    }

    for (final tx in txs) {
      final agg = byMonth[_mk(tx.occurredAt)];
      if (tx.direction == 'income') {
        if (agg != null) agg.income += tx.amountCents;
        continue;
      }
      if (tx.direction != 'expense') {
        continue;
      }

      final cat = catNameById[tx.categoryId] ?? 'other';
      if (agg != null) {
        agg.expense += tx.amountCents;
        agg.byCat[cat] = (agg.byCat[cat] ?? 0) + tx.amountCents;
      }

      final d0 = _dayStart(tx.occurredAt);
      if (!d0.isBefore(peakFrom) && !d0.isAfter(_dayStart(now))) {
        peakCatTotals[cat] = (peakCatTotals[cat] ?? 0) + tx.amountCents;
        if (peakCategory == _allCat || peakCategory == cat) {
          peakDaily[d0] = (peakDaily[d0] ?? 0) + tx.amountCents;
        }
      }
    }

    final expenseTrend = months
        .map(
          (m) => TrendPoint(
            m.month.month.toString().padLeft(2, '0'),
            m.expense / 100.0,
            date: m.month,
          ),
        )
        .toList(growable: false);
    final balanceTrend = months
        .map((m) {
          final rate = m.income <= 0
              ? (m.expense <= 0 ? 0.0 : -100.0)
              : ((m.income - m.expense) * 100.0 / m.income);
          return TrendPoint(
            m.month.month.toString().padLeft(2, '0'),
            rate,
            date: m.month,
          );
        })
        .toList(growable: false);

    final peakEntries = peakDaily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final peakTrend = peakEntries
        .map(
          (e) => TrendPoint(
            '${e.key.month.toString().padLeft(2, '0')}/${e.key.day.toString().padLeft(2, '0')}',
            e.value / 100.0,
            date: e.key,
          ),
        )
        .toList(growable: false);

    int peak = 0;
    int sum = 0;
    DateTime? peakDate;
    for (final e in peakEntries) {
      sum += e.value;
      if (e.value >= peak) {
        peak = e.value;
        peakDate = e.key;
      }
    }
    final avg = peakEntries.isEmpty ? 0 : (sum / peakEntries.length).round();

    final curIdx = _focusMonthIndex(months);
    final cur = months[curIdx];
    final prev = curIdx > 0 ? months[curIdx - 1] : _MonthAgg(cur.month);
    final mom = prev.expense <= 0
        ? null
        : ((cur.expense - prev.expense) * 100.0 / prev.expense);

    final catChanges = _catChanges(cur, prev);
    final advice = _advice(months, curIdx, catChanges, peak, avg, peakDate);
    final peakCats = peakCatTotals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _Data(
      months: months,
      expenseTrend: expenseTrend,
      balanceTrend: balanceTrend,
      peakTrend: peakTrend,
      currentByCat: cur.byCat,
      catChanges: catChanges,
      suggestions: advice,
      peak: peak,
      avgDaily: avg,
      momExpense: mom,
      peakCats: peakCats.map((e) => e.key).toList(growable: false),
      rangeTxCount: rangeTxCount,
    );
  }

  List<_CatChange> _catChanges(_MonthAgg cur, _MonthAgg prev) {
    final curTotal = cur.expense <= 0 ? 1 : cur.expense;
    final prevTotal = prev.expense <= 0 ? 1 : prev.expense;
    final keys = <String>{...cur.byCat.keys, ...prev.byCat.keys};
    final out = keys
        .map(
          (k) => _CatChange(
            name: k,
            amount: cur.byCat[k] ?? 0,
            share: (cur.byCat[k] ?? 0) / curTotal,
            prevShare: (prev.byCat[k] ?? 0) / prevTotal,
          ),
        )
        .toList();
    out.sort((a, b) => b.amount.compareTo(a.amount));
    return out.take(6).toList(growable: false);
  }

  List<_Advice> _advice(
    List<_MonthAgg> months,
    int focusIndex,
    List<_CatChange> catChanges,
    int peak,
    int avg,
    DateTime? peakDate,
  ) {
    final out = <_Advice>[];
    final safeFocus = focusIndex.clamp(0, months.length - 1);
    final cur = months[safeFocus];
    final prevStart = math.max(0, safeFocus - 3);
    final prev3 = safeFocus > 0
        ? months.sublist(prevStart, safeFocus)
        : const <_MonthAgg>[];
    if (prev3.isNotEmpty) {
      final avgPrev =
          prev3.fold<int>(0, (p, e) => p + e.expense) / prev3.length;
      if (avgPrev > 0 && cur.expense > avgPrev * 1.15) {
        out.add(
          _Advice(
            icon: Icons.trending_up_rounded,
            titleEn: 'Spending increased quickly',
            titleZh: '\u652f\u51fa\u589e\u957f\u8fc7\u5feb',
          ),
        );
      }
    }
    final rate = cur.income <= 0
        ? -1.0
        : (cur.income - cur.expense) / cur.income;
    if (rate < 0) {
      out.add(
        _Advice(
          icon: Icons.warning_amber_rounded,
          titleEn: 'Income-expense balance is negative',
          titleZh: '\u6536\u652f\u5e73\u8861\u4e3a\u8d1f',
        ),
      );
    }
    if (catChanges.isNotEmpty && catChanges.first.share >= 0.45) {
      out.add(
        _Advice(
          icon: Icons.pie_chart_outline_rounded,
          titleEn: 'Category concentration is high',
          titleZh: '\u6d88\u8d39\u5206\u7c7b\u96c6\u4e2d\u5ea6\u8f83\u9ad8',
        ),
      );
    }
    if (avg > 0 && peak > (avg * 23 / 10).round()) {
      final d = peakDate == null
          ? ''
          : '${peakDate.year}-${peakDate.month.toString().padLeft(2, '0')}-${peakDate.day.toString().padLeft(2, '0')}';
      out.add(
        _Advice(
          icon: Icons.show_chart_rounded,
          titleEn: 'Peak spending day detected $d',
          titleZh: '\u68c0\u6d4b\u5230\u6d88\u8d39\u5cf0\u503c\u65e5 $d',
        ),
      );
    }
    if (out.isEmpty) {
      out.add(
        _Advice(
          icon: Icons.check_circle_outline_rounded,
          titleEn: 'Spending pattern is stable',
          titleZh: '\u6d88\u8d39\u7ed3\u6784\u8f83\u7a33\u5b9a',
        ),
      );
    }
    return out;
  }

  String _catLabel(BuildContext context, String key) {
    if (key == _allCat) {
      return dat(context, 'All categories');
    }
    return categoryLabel(context, key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(dat(context, 'Analysis'))),
      body: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          final d = snap.data!;
          final rangeIncome = d.months.fold<int>(0, (p, e) => p + e.income);
          final rangeExpense = d.months.fold<int>(0, (p, e) => p + e.expense);
          final net = rangeIncome - rangeExpense;
          final cs = Theme.of(context).colorScheme;
          final peakValue = d.peakCats.contains(_peakCategory)
              ? _peakCategory
              : _allCat;
          final peakTitle = peakValue == _allCat
              ? dat(context, 'Spending Peak Curve (Last 60 Days)')
              : '${dat(context, 'Spending Peak Curve (Last 60 Days)')} - ${_catLabel(context, peakValue)}';

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(dat(context, 'Range')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          children: [3, 6, 12]
                              .map((m) {
                                final selected = _months == m;
                                return ChoiceChip(
                                  label: Text('${m}M'),
                                  selected: selected,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? cs.onPrimaryContainer
                                        : cs.onSurface,
                                  ),
                                  backgroundColor: cs.surfaceContainerHighest,
                                  selectedColor: cs.primaryContainer,
                                  onSelected: (v) {
                                    if (!v) return;
                                    _months = m;
                                    _peakCategory = _allCat;
                                    _future = _load(
                                      rangeMonths: _months,
                                      peakCategory: _peakCategory,
                                    );
                                    setState(() {});
                                  },
                                );
                              })
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        label: dat(context, 'Income'),
                        value: _money(rangeIncome),
                        color: Colors.green,
                      ),
                      _Chip(
                        label: dat(context, 'Expense'),
                        value: _money(rangeExpense),
                        color: Colors.red,
                      ),
                      _Chip(
                        label: dat(context, 'Net'),
                        value: net >= 0 ? '+${_money(net)}' : '-${_money(net)}',
                        color: net >= 0 ? Colors.green : Colors.red,
                      ),
                      _Chip(
                        label: dat(context, 'MoM Expense (M-1 vs M-2)'),
                        value: d.momExpense == null
                            ? dat(context, 'N/A')
                            : '${d.momExpense! >= 0 ? '+' : ''}${d.momExpense!.toStringAsFixed(1)}%',
                        color: Colors.orange,
                      ),
                      _Chip(
                        label: dat(context, 'Tx Count'),
                        value: '${d.rangeTxCount}',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BalanceTrendLine(
                data: d.expenseTrend,
                title: dat(context, 'Monthly Expense Trend (${_rangeLabel()})'),
                primaryLabel: dat(context, 'Expense'),
                currencySymbol: currencySymbol(widget.accountCurrency),
              ),
              const SizedBox(height: 10),
              ExpensePie(
                expenseByCategoryCents: d.currentByCat,
                currencySymbol: currencySymbol(widget.accountCurrency),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dat(context, 'Category Share Change (vs last month)'),
                      ),
                      const SizedBox(height: 8),
                      ...d.catChanges.map((c) {
                        final delta = c.delta * 100;
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                categoryLabel(context, c.name),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text('${(c.share * 100).toStringAsFixed(1)}%'),
                            const SizedBox(width: 8),
                            Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BalanceTrendLine(
                data: d.balanceTrend,
                title: dat(
                  context,
                  'Income-Expense Balance Rate Trend (${_rangeLabel()})',
                ),
                primaryLabel: dat(context, 'Net / Income'),
                currencySymbol: '',
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _AnalysisSelectorField(
                    label: dat(context, 'Peak Curve Category Filter'),
                    valueText: _catLabel(context, peakValue),
                    onTap: () async {
                      final picked = await _showAnalysisSelectionSheet<String>(
                        context,
                        title: dat(context, 'Select Peak Curve Category'),
                        options: <String>[_allCat, ...d.peakCats]
                            .map(
                              (k) => (
                                value: k,
                                label: _catLabel(context, k),
                                icon: k == _allCat
                                    ? Icons.filter_alt_rounded
                                    : Icons.label_rounded,
                              ),
                            )
                            .toList(growable: false),
                        current: peakValue,
                      );
                      if (picked == null || picked == _peakCategory) return;
                      _peakCategory = picked;
                      _future = _load(
                        rangeMonths: _months,
                        peakCategory: _peakCategory,
                      );
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BalanceTrendLine(
                data: d.peakTrend,
                title: peakTitle,
                primaryLabel: dat(context, 'Daily Expense'),
                currencySymbol: currencySymbol(widget.accountCurrency),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dat(context, 'Spending Suggestions')),
                      const SizedBox(height: 6),
                      Text(
                        dat(
                          context,
                          'Peak: ${_money(d.peak)} | Avg daily: ${_money(d.avgDaily)}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...d.suggestions.map((s) {
                        return Row(
                          children: [
                            Icon(s.icon, size: 18),
                            const SizedBox(width: 6),
                            Expanded(child: Text(dat(context, s.titleEn))),
                          ],
                        );
                      }),
                    ],
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

class _AnalysisSelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback onTap;

  const _AnalysisSelectorField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.filter_alt_rounded),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showAnalysisSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, IconData icon})> options,
  required T current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: dat(context, 'Close'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final selected = o.value == current;
                  return ListTile(
                    leading: Icon(
                      o.icon,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      o.label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : null,
                    tileColor: selected
                        ? cs.primaryContainer.withValues(alpha: 0.55)
                        : Colors.transparent,
                    onTap: () => Navigator.of(sheetContext).pop(o.value),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label: $value', style: TextStyle(color: color)),
    );
  }
}

class _MonthAgg {
  final DateTime month;
  int income = 0;
  int expense = 0;
  final Map<String, int> byCat = <String, int>{};
  _MonthAgg(this.month);
}

class _CatChange {
  final String name;
  final int amount;
  final double share;
  final double prevShare;
  _CatChange({
    required this.name,
    required this.amount,
    required this.share,
    required this.prevShare,
  });
  double get delta => share - prevShare;
}

class _Advice {
  final IconData icon;
  final String titleEn;
  final String titleZh;
  _Advice({required this.icon, required this.titleEn, required this.titleZh});
}

class _Data {
  final List<_MonthAgg> months;
  final List<TrendPoint> expenseTrend;
  final List<TrendPoint> balanceTrend;
  final List<TrendPoint> peakTrend;
  final Map<String, int> currentByCat;
  final List<_CatChange> catChanges;
  final List<_Advice> suggestions;
  final int peak;
  final int avgDaily;
  final double? momExpense;
  final List<String> peakCats;
  final int rangeTxCount;

  _Data({
    required this.months,
    required this.expenseTrend,
    required this.balanceTrend,
    required this.peakTrend,
    required this.currentByCat,
    required this.catChanges,
    required this.suggestions,
    required this.peak,
    required this.avgDaily,
    required this.momExpense,
    required this.peakCats,
    required this.rangeTxCount,
  });
}

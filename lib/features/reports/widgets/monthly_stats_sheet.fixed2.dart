import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../reports/models.dart';
import '../../reports/report_service.dart';
import 'monthly_stats_sheet_fixed2_texts.dart';
import 'expense_pie.dart';
import 'income_expense_bar.dart';

/// 缁熻椤甸潰鍐呭锛堟櫘閫氶〉闈㈠唴瀹圭粍浠讹紝涓嶅啀鏄?BottomSheet锛夈€?///
/// 椤堕儴灏忓鑸細鏈?/ 鍛?/ 鏃ワ紙鏃ユ敮鎸?7鏃?/ 3鏃ュ垏鎹級
/// - 鏈堬細鏈湀鏁版嵁
/// - 鍛細鏈懆鏁版嵁锛堝懆涓€ ~ 涓嬪懆涓€锛?/// - 鏃ワ細鏈€杩?N 澶╂暟鎹紙鏀舵敮鍗犳瘮 + 鏀嚭鍗犳瘮锛? 姣忔棩浣欓鎶樼嚎
///
/// 涓轰簡涓嶇牬鍧忎綘椤圭洰涓棦鏈夊紩鐢紝杩欓噷浠嶄繚鐣欑被鍚?`MonthlyStatsSheet`銆?class MonthlyStatsSheet extends StatefulWidget {
  final AppDatabase db;
  const MonthlyStatsSheet({super.key, required this.db});

  @override
  State<MonthlyStatsSheet> createState() => _MonthlyStatsSheetState();
}

class _MonthlyStatsSheetState extends State<MonthlyStatsSheet> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  int _dayRange = 7;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
        const SizedBox(height: 8),
        _TopStatsTabs(
          controller: _tab,
          showDayToggle: _tab.index == 2,
          dayRange: _dayRange,
          onDayRangeChanged: (v) => setState(() => _dayRange = v),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tab,
            physics: const BouncingScrollPhysics(),
            children: [
              _MonthStatsView(db: widget.db),
              _WeekStatsView(db: widget.db),
              _DayStatsView(db: widget.db, rangeDays: _dayRange),
            ],
          ),
        ),
        ],
      ),
    );
  }
}

class _TopStatsTabs extends StatelessWidget {
  final TabController controller;
  final bool showDayToggle;
  final int dayRange;
  final ValueChanged<int> onDayRangeChanged;

  const _TopStatsTabs({
    required this.controller,
    required this.showDayToggle,
    required this.dayRange,
    required this.onDayRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainerHighest.withValues(alpha: 160)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: TabBar(
                controller: controller,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(blurRadius: 12, spreadRadius: 1, color: Color(0x14000000)),
                  ],
                ),
                labelColor: cs.onSurface,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: '鏈?),
                  Tab(text: '鍛?),
                  Tab(text: '鏃?),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: showDayToggle
                ? Container(
                    key: const ValueKey('dayToggle'),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest.withValues(alpha: 160)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PillToggle(
                          text: mst2(context, '7D'),
                          selected: dayRange == 7,
                          onTap: () => onDayRangeChanged(7),
                        ),
                        const SizedBox(width: 6),
                        _PillToggle(
                          text: mst2(context, '3D'),
                          selected: dayRange == 3,
                          onTap: () => onDayRangeChanged(3),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('noToggle')),
          ),
        ],
      ),
    );
  }
}

class _PillToggle extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _PillToggle({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _MonthStatsView extends StatelessWidget {
  final AppDatabase db;
  const _MonthStatsView({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyReport>(
      future: ReportService.buildForMonth(db, DateTime.now()),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final r = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ReportBody(
              title: mst2(context, 'This Month (${r.monthKey})'),
              report: r,
              emptyExpenseHint:
              mst2(context, 'No expense category data this month'),
            ),
          ],
        );
      },
    );
  }
}

class _WeekStatsView extends StatelessWidget {
  final AppDatabase db;
  const _WeekStatsView({required this.db});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyReport>(
      future: ReportService.buildForWeek(db, DateTime.now()),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final r = snap.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _ReportBody(
              title: mst2(context, 'This Week (${r.monthKey})'),
              report: r,
              emptyExpenseHint:
              mst2(context, 'No expense category data this week'),
            ),
          ],
        );
      },
    );
  }
}

class _DayData {
  final MonthlyReport report;
  final List<int> balancesCents;
  _DayData({required this.report, required this.balancesCents});
}

class _DayStatsView extends StatelessWidget {
  final AppDatabase db;
  final int rangeDays;
  const _DayStatsView({required this.db, required this.rangeDays});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DayData>(
      future: Future.wait([
        ReportService.buildForLastDays(db, rangeDays),
        ReportService.dailyBalanceLastDays(db, rangeDays),
      ]).then((list) {
        return _DayData(
          report: list[0] as MonthlyReport,
          balancesCents: list[1] as List<int>,
        );
      }),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final data = snap.data!;
        final r = data.report;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              mst2(context, 'Daily Balance (${r.monthKey})'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _BalanceLineChartCard(balancesCents: data.balancesCents, days: rangeDays),
            const SizedBox(height: 16),
            _ReportBody(
              title: mst2(context, 'Last $rangeDays Days (${r.monthKey})'),
              report: r,
              emptyExpenseHint: mst2(context, 'No expense category data in last $rangeDays days'),
            ),
          ],
        );
      },
    );
  }
}

class _ReportBody extends StatelessWidget {
  final String title;
  final MonthlyReport report;
  final String emptyExpenseHint;

  const _ReportBody({
    required this.title,
    required this.report,
    required this.emptyExpenseHint,
  });

  String _money(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final r = report;
    final net = r.netCents / 100.0;
    final netColor = net >= 0 ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),
        IncomeExpenseBar(
          incomeCents: r.incomeCents,
          expenseCents: r.expenseCents,
          expenseLabel: mst2(context, 'Expense'),
          incomeLabel: mst2(context, 'Income'),
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: net.abs()),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final text = net >= 0 ? '+\$${_money(v)}' : '-\$${_money(v)}';
            return Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: netColor),
            );
          },
        ),
        const SizedBox(height: 14),
        if (r.expenseByCategoryCents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(emptyExpenseHint, style: const TextStyle(fontWeight: FontWeight.w700)),
          )
        else
          ExpensePie(expenseByCategoryCents: r.expenseByCategoryCents),
      ],
    );
  }
}

class _BalanceLineChartCard extends StatelessWidget {
  final List<int> balancesCents;
  final int days;
  const _BalanceLineChartCard({required this.balancesCents, required this.days});

  String _money(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final points = balancesCents.map((e) => e / 100.0).toList(growable: false);
    final minV = points.isEmpty ? 0.0 : points.reduce(math.min);
    final maxV = points.isEmpty ? 0.0 : points.reduce(math.max);
    final last = points.isEmpty ? 0.0 : points.last;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(width: 1.2, color: Theme.of(context).dividerColor.withValues(alpha: 110)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mst2(context, 'Balance Trend'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '\$${_money(last)}',
                  style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mst2(
                context,
                'Last $days day(s)  •  min \$${_money(minV)}  max \$${_money(maxV)}',
              ),
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: CustomPaint(
                painter: _BalanceLinePainter(points: points, axisColor: cs.outlineVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceLinePainter extends CustomPainter {
  final List<double> points;
  final Color axisColor;

  _BalanceLinePainter({required this.points, required this.axisColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = axisColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), paintAxis);

    if (points.isEmpty) return;

    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);

    const padding = EdgeInsets.fromLTRB(12, 12, 12, 12);
    final w = size.width - padding.left - padding.right;
    final h = size.height - padding.top - padding.bottom;

    Offset mapPoint(int i, double v) {
      final x = padding.left + (points.length == 1 ? 0.0 : (i / (points.length - 1)) * w);
      final t = (v - minV) / range;
      final y = padding.top + (1.0 - t) * h;
      return Offset(x, y);
    }

    // 涓嚎
    final midY = padding.top + h / 2;
    canvas.drawLine(Offset(padding.left, midY), Offset(padding.left + w, midY), paintAxis);

    // 鎶樼嚎锛堜笉鎸囧畾涓婚鑹茬殑璇濋粯璁よ摑鑹插嵆鍙級
    final linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final p0 = mapPoint(0, points[0]);
    final path = Path()..moveTo(p0.dx, p0.dy);
    for (int i = 1; i < points.length; i++) {
      final p = mapPoint(i, points[i]);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    // 鐐?    final dotPaint = Paint()..color = Colors.blue;
    for (int i = 0; i < points.length; i++) {
      final p = mapPoint(i, points[i]);
      canvas.drawCircle(p, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceLinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.axisColor != axisColor;
  }
}


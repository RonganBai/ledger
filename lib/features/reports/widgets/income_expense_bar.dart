import 'package:flutter/material.dart';

class IncomeExpenseBar extends StatelessWidget {
  final int incomeCents;
  final int expenseCents;
  final String incomeLabel;
  final String expenseLabel;
  final String currencySymbol;
  final Duration duration;

  const IncomeExpenseBar({
    super.key,
    required this.incomeCents,
    required this.expenseCents,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.currencySymbol,
    this.duration = const Duration(milliseconds: 1100),
  });

  String _money(double v) => v.toStringAsFixed(2);
  double _clamp01(double v) => v.clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final income = incomeCents.toDouble();
    final expense = expenseCents.toDouble();
    final total = income + expense;

    final expenseRatio = total <= 0 ? 0.5 : (expense / total);
    final splitTarget = expenseRatio.clamp(0.0, 1.0);

    const barHeight = 18.0;
    const radius = 14.0;
    const dividerW = 2.0;

    final redBg = Colors.red.withValues(alpha: 90);
    final greenBg = Colors.green.withValues(alpha: 90);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, tRaw, _) {
        final t = _clamp01(tRaw);
        final sweep = (t < 0.85)
            ? t
            : (0.85 + (Curves.easeOutBack.transform(_clamp01((t - 0.85) / 0.15)) * 0.15));

        final moveT = Curves.easeOutCubic.transform(_clamp01(t));
        final split = (0.5 + (splitTarget - 0.5) * moveT).clamp(0.0, 1.0);

        final shownExpense = (expenseCents / 100.0) * sweep;
        final shownIncome = (incomeCents / 100.0) * sweep;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    expenseLabel,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    incomeLabel,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(width: 1.2, color: Theme.of(context).dividerColor.withValues(alpha: 110)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: SizedBox(
                  height: barHeight,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final leftW = w * split;
                      final rightW = (w - leftW).clamp(0.0, w);

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: _clamp01(sweep),
                                child: Stack(
                                  children: [
                                    Positioned(left: 0, top: 0, bottom: 0, width: leftW, child: Container(color: redBg)),
                                    Positioned(left: leftW, top: 0, bottom: 0, width: rightW, child: Container(color: greenBg)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: _clamp01(sweep),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: (leftW - dividerW / 2).clamp(0.0, w - dividerW),
                                      top: 0,
                                      bottom: 0,
                                      width: dividerW,
                                      child: Container(color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '-$currencySymbol${_money(shownExpense)}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
                  ),
                ),
                Expanded(
                  child: Text(
                    '+$currencySymbol${_money(shownIncome)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

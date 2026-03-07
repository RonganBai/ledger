import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'expense_pie_texts.dart';
import '../../../l10n/category_i18n.dart';

class ExpensePie extends StatefulWidget {
  final Map<String, int> expenseByCategoryCents;
  final String currencySymbol;

  const ExpensePie({
    super.key,
    required this.expenseByCategoryCents,
    this.currencySymbol = r'$',
  });

  @override
  State<ExpensePie> createState() => _ExpensePieState();
}

class _ExpensePieState extends State<ExpensePie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _lastSig;

  String _signature(Map<String, int> m) {
    if (m.isEmpty) return '';
    final keys = m.keys.toList()..sort();
    final b = StringBuffer();
    for (final k in keys) {
      b.write(k);
      b.write('=');
      b.write(m[k] ?? 0);
      b.write(';');
    }
    return b.toString();
  }

  List<Color> _evenPalette(int n) {
    if (n <= 0) return const [];
    const s = 0.7;
    const v = 0.8;
    return List.generate(n, (i) {
      final hue = (360.0 * i / n) % 360.0;
      return HSVColor.fromAHSV(1.0, hue, s, v).toColor();
    });
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _lastSig = _signature(widget.expenseByCategoryCents);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(covariant ExpensePie oldWidget) {
    super.didUpdateWidget(oldWidget);

    final sig = _signature(widget.expenseByCategoryCents);
    if (sig != _lastSig) {
      _lastSig = sig;
      if (mounted) _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.expenseByCategoryCents;

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          ept(context, 'No expense category data this month'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (p, e) => p + e.value);
    if (total <= 0) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          ept(context, 'No expenses this month'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    const maxSlices = 10;
    const otherKey = '__other__';

    final shown = entries.take(maxSlices).toList();
    final rest = entries.skip(maxSlices).toList();
    if (rest.isNotEmpty) {
      final restSum = rest.fold<int>(0, (p, e) => p + e.value);
      shown.add(MapEntry(otherKey, restSum));
    }

    final n = shown.length;
    final colors = _evenPalette(n);

    final slices = <_PieSlice>[];
    for (int i = 0; i < n; i++) {
      final e = shown[i];
      final value = e.value.toDouble();
      final pct = value / total;
      final label = e.key == otherKey
          ? ept(context, 'Other')
          : categoryLabel(context, e.key);

      slices.add(
        _PieSlice(
          key: e.key,
          label: label,
          value: value,
          fraction: pct,
          color: colors[i],
        ),
      );
    }

    final anim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    final cardColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = Color.alphaBlend(
      (isDark
          ? Colors.black.withValues(alpha: 46)
          : Colors.black.withValues(alpha: 15)),
      cardColor,
    );

    final holeColor = cardColor;

    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              width: 1.2,
              color: Theme.of(context).dividerColor.withValues(alpha: 110),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ept(context, 'Expense Breakdown'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 220,
                  child: CustomPaint(
                    painter: _SweepPiePainter(
                      slices: slices,
                      progress: anim.value,
                      startAngleRad: -math.pi / 2,
                      counterClockwise: true,
                      centerHoleRadiusFactor: 0.40,
                      showPercentText: true,
                      dividerWidth: 3.0,
                      dividerColor: Colors.white.withValues(
                        alpha: isDark ? 140 : 230,
                      ),
                      backgroundColor: backgroundColor,
                      holeColor: holeColor,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 8),
                ...slices.map((s) {
                  final pct = s.fraction * 100.0;
                  final amount = s.value / 100.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${s.label}  ${pct.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${widget.currencySymbol}${amount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PieSlice {
  final String key;
  final String label;
  final double value;
  final double fraction;
  final Color color;

  _PieSlice({
    required this.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });
}

class _SweepPiePainter extends CustomPainter {
  final List<_PieSlice> slices;
  final double progress;
  final double startAngleRad;
  final bool counterClockwise;
  final double centerHoleRadiusFactor;

  final bool showPercentText;

  final double dividerWidth;
  final Color dividerColor;

  final Color backgroundColor;
  final Color holeColor;

  _SweepPiePainter({
    required this.slices,
    required this.progress,
    required this.startAngleRad,
    required this.counterClockwise,
    required this.centerHoleRadiusFactor,
    required this.showPercentText,
    required this.dividerWidth,
    required this.dividerColor,
    required this.backgroundColor,
    required this.holeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final outerR = math.min(size.width, size.height) * 0.42;
    final innerR = outerR * centerHoleRadiusFactor;

    final bgPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = backgroundColor;
    canvas.drawCircle(center, outerR, bgPaint);

    final rect = Rect.fromCircle(center: center, radius: outerR);

    final totalSweep = 2 * math.pi * progress;

    final dir = counterClockwise ? -1.0 : 1.0;

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dividerWidth
      ..color = dividerColor;

    double used = 0.0;
    double angleCursor = startAngleRad;

    for (final s in slices) {
      final fullSweep = (2 * math.pi) * s.fraction;

      final remaining = totalSweep - used;
      if (remaining <= 0) break;

      final drawSweep = math.min(fullSweep, remaining);
      if (drawSweep <= 0) break;

      final start = angleCursor;

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = s.color;

      canvas.drawArc(rect, start, dir * drawSweep, true, fillPaint);
      canvas.drawArc(rect, start, dir * drawSweep, true, borderPaint);

      final shouldShow =
          showPercentText && s.fraction >= 0.05 && drawSweep >= 0.18;
      if (shouldShow) {
        final midAngle = start + dir * (drawSweep / 2);
        final textR = (innerR + outerR) / 2;

        final textPos = Offset(
          center.dx + textR * math.cos(midAngle),
          center.dy + textR * math.sin(midAngle),
        );

        final text = '${(s.fraction * 100).toStringAsFixed(0)}%';

        final strokeTp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2
                ..color = Colors.black.withValues(alpha: 153),
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();

        final fillTp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();

        final w = math.max(strokeTp.width, fillTp.width);
        final h = math.max(strokeTp.height, fillTp.height);
        final offset = textPos - Offset(w / 2, h / 2);

        strokeTp.paint(canvas, offset);
        fillTp.paint(canvas, offset);
      }

      used += fullSweep;
      angleCursor += dir * fullSweep;
    }

    final holePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = holeColor;
    canvas.drawCircle(center, innerR, holePaint);
  }

  @override
  bool shouldRepaint(covariant _SweepPiePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.slices != slices ||
        oldDelegate.counterClockwise != counterClockwise ||
        oldDelegate.startAngleRad != startAngleRad ||
        oldDelegate.dividerWidth != dividerWidth ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.holeColor != holeColor;
  }
}

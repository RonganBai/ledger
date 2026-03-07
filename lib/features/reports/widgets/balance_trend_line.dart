import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrendPoint {
  final String label;
  final double value;
  final DateTime? date;

  const TrendPoint(this.label, this.value, {this.date});
}

class BalanceTrendLine extends StatefulWidget {
  final List<TrendPoint> data;
  final String title;
  final String primaryLabel;
  final String currencySymbol;

  const BalanceTrendLine({
    super.key,
    required this.data,
    this.title = 'Balance Trend',
    this.primaryLabel = 'Balance',
    this.currencySymbol = r'$',
  });

  @override
  State<BalanceTrendLine> createState() => _BalanceTrendLineState();
}

class _BalanceTrendLineState extends State<BalanceTrendLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant BalanceTrendLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox(height: 220);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const lineBlue = Color(0xFF3B82F6);

    double minV = widget.data.first.value;
    double maxV = widget.data.first.value;
    for (final p in widget.data) {
      minV = math.min(minV, p.value);
      maxV = math.max(maxV, p.value);
    }
    if ((maxV - minV).abs() < 0.001) {
      maxV += 1;
      minV -= 1;
    }

    final axisColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.60);
    final axisLabelColor = isDark
        ? Colors.white.withValues(alpha: 0.96)
        : Colors.black54;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.26)
        : Colors.black.withValues(alpha: 0.18);

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: lineBlue,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.primaryLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isDark ? Colors.white : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 130,
              child: AnimatedBuilder(
                animation: _curve,
                builder: (context, child) => CustomPaint(
                  painter: _SimpleLinePainter(
                    data: widget.data,
                    minV: minV,
                    maxV: maxV,
                    currencySymbol: widget.currencySymbol,
                    progress: _curve.value,
                    lineColor: lineBlue,
                    axisColor: axisColor,
                    axisLabelColor: axisLabelColor,
                    gridColor: gridColor,
                  ),
                  child: child,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleLinePainter extends CustomPainter {
  final List<TrendPoint> data;
  final double minV;
  final double maxV;
  final String currencySymbol;
  final double progress;
  final Color lineColor;
  final Color axisColor;
  final Color axisLabelColor;
  final Color gridColor;

  const _SimpleLinePainter({
    required this.data,
    required this.minV,
    required this.maxV,
    required this.currencySymbol,
    required this.progress,
    required this.lineColor,
    required this.axisColor,
    required this.axisLabelColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 44.0;
    const rightPad = 10.0;
    const topPad = 10.0;
    const bottomPad = 24.0;

    final w = (size.width - leftPad - rightPad).clamp(1.0, double.infinity);
    final h = (size.height - topPad - bottomPad).clamp(1.0, double.infinity);

    final gridPaint = Paint()..color = gridColor;
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final t = i / 4;
      final y = topPad + h * t;
      canvas.drawLine(Offset(leftPad, y), Offset(leftPad + w, y), gridPaint);

      final v = maxV - (maxV - minV) * t;
      final label = _money(v);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 11, color: axisLabelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - 8 - tp.width, y - tp.height / 2));
    }

    canvas.drawLine(
      Offset(leftPad, topPad),
      Offset(leftPad, topPad + h),
      axisPaint,
    );
    canvas.drawLine(
      Offset(leftPad, topPad + h),
      Offset(leftPad + w, topPad + h),
      axisPaint,
    );

    final n = data.length;
    final stepX = n <= 1 ? 0.0 : (w / (n - 1));

    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = leftPad + stepX * i;
      final y = _mapY(data[i].value, topPad, h);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.save();
    final clipRight = leftPad + w * progress.clamp(0.0, 1.0);
    canvas.clipRect(Rect.fromLTRB(leftPad, 0, clipRight + 2, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    for (int i = 0; i < n; i++) {
      final x = leftPad + stepX * i;
      final y = _mapY(data[i].value, topPad, h);
      if (x <= clipRight) {
        canvas.drawCircle(Offset(x, y), 3, Paint()..color = lineColor);
      }
    }
    canvas.restore();

    final show = _sampleTickIndexes(n);
    for (final i in show) {
      final x = leftPad + stepX * i;
      canvas.drawLine(
        Offset(x, topPad + h),
        Offset(x, topPad + h + 4),
        axisPaint,
      );
      final label = data[i].label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 11, color: axisLabelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (x - tp.width / 2).clamp(0.0, size.width - tp.width),
          topPad + h + 6,
        ),
      );
    }
  }

  List<int> _sampleTickIndexes(int n) {
    if (n <= 1) return const [0];
    if (n <= 7) return List<int>.generate(n, (i) => i);
    return [
      0,
      (n * 0.25).round(),
      (n * 0.5).round(),
      (n * 0.75).round(),
      n - 1,
    ];
  }

  double _mapY(double v, double top, double h) {
    final t = ((v - minV) / (maxV - minV)).clamp(0.0, 1.0);
    return top + h * (1 - t);
  }

  String _money(double v) {
    final sign = v < 0 ? '-' : '';
    final abs = v.abs();
    if (abs >= 1000000) {
      return '$sign$currencySymbol${(abs / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '$sign$currencySymbol${(abs / 1000).toStringAsFixed(1)}k';
    }
    return '$sign$currencySymbol${abs.toStringAsFixed(0)}';
  }

  @override
  bool shouldRepaint(covariant _SimpleLinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.minV != minV ||
        oldDelegate.maxV != maxV ||
        oldDelegate.currencySymbol != currencySymbol ||
        oldDelegate.progress != progress ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.axisLabelColor != axisLabelColor ||
        oldDelegate.gridColor != gridColor;
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import 'home_tutorial_controller.dart';

class CoachOverlay extends StatelessWidget {
  final Rect? targetRect;
  final String title;
  final String message;
  final int index;
  final int total;
  final bool isLastStep;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final String backLabel;
  final String skipLabel;
  final String nextLabel;
  final String doneLabel;
  final CoachHintAnimation hintAnimation;
  final bool captureTargetTap;
  final VoidCallback? onTargetTap;
  final CoachPanelPosition panelPosition;

  const CoachOverlay({
    super.key,
    required this.targetRect,
    required this.title,
    required this.message,
    required this.index,
    required this.total,
    required this.isLastStep,
    required this.onSkip,
    required this.onNext,
    this.onPrevious,
    required this.backLabel,
    required this.skipLabel,
    required this.nextLabel,
    required this.doneLabel,
    this.hintAnimation = CoachHintAnimation.none,
    this.captureTargetTap = true,
    this.onTargetTap,
    this.panelPosition = CoachPanelPosition.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rect = targetRect;
    final adaptiveInset = rect == null
        ? 0.0
        : (rect.shortestSide * 0.18).clamp(6.0, 14.0);
    final highlightRect = rect?.inflate(adaptiveInset);
    const highlightRadius = 16.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScrimWithHolePainter(
                  holeRect: highlightRect,
                  holeRadius: highlightRadius,
                  scrimColor: Colors.black.withValues(alpha: 0.62),
                ),
              ),
            ),
          ),
          if (highlightRect != null)
            Positioned.fromRect(
              rect: highlightRect,
              child: captureTargetTap
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTargetTap ?? onNext,
                      child: _HighlightBox(
                        hintAnimation: hintAnimation,
                        highlightRadius: highlightRadius,
                      ),
                    )
                  : IgnorePointer(
                      ignoring: true,
                      child: _HighlightBox(
                        hintAnimation: hintAnimation,
                        highlightRadius: highlightRadius,
                      ),
                    ),
            ),
          Align(
            alignment: panelPosition == CoachPanelPosition.top
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            child: SafeArea(
              top: panelPosition == CoachPanelPosition.top,
              bottom: panelPosition != CoachPanelPosition.top,
              minimum: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '$index / $total',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                          const Spacer(),
                          if (onPrevious != null)
                            TextButton(
                              onPressed: onPrevious,
                              child: Text(backLabel),
                            ),
                          TextButton(onPressed: onSkip, child: Text(skipLabel)),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: onNext,
                            child: Text(isLastStep ? doneLabel : nextLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  final double highlightRadius;
  final CoachHintAnimation hintAnimation;

  const _HighlightBox({
    required this.highlightRadius,
    required this.hintAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(highlightRadius),
        border: Border.all(color: cs.primary, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          const SizedBox.expand(),
          if (hintAnimation != CoachHintAnimation.none)
            Positioned.fill(
              child: IgnorePointer(
                child: _HintAnimationLayer(type: hintAnimation),
              ),
            ),
        ],
      ),
    );
  }
}

class _HintAnimationLayer extends StatefulWidget {
  final CoachHintAnimation type;

  const _HintAnimationLayer({required this.type});

  @override
  State<_HintAnimationLayer> createState() => _HintAnimationLayerState();
}

class _HintAnimationLayerState extends State<_HintAnimationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        switch (widget.type) {
          case CoachHintAnimation.swipeRight:
            return _buildSwipeHint(
              context,
              t: t,
              color: cs.primary,
              icon: Icons.swipe_rounded,
              direction: 1,
            );
          case CoachHintAnimation.swipeLeft:
            return _buildSwipeHint(
              context,
              t: t,
              color: cs.primary,
              icon: Icons.swipe_rounded,
              direction: -1,
            );
          case CoachHintAnimation.edgeSwipeRight:
            return _buildSwipeHint(
              context,
              t: t,
              color: cs.primary,
              icon: Icons.keyboard_double_arrow_right_rounded,
              direction: 1,
              fromEdge: true,
            );
          case CoachHintAnimation.longPress:
            return _buildLongPressHint(context, t: t, color: cs.primary);
          case CoachHintAnimation.none:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildSwipeHint(
    BuildContext context, {
    required double t,
    required Color color,
    required IconData icon,
    required int direction,
    bool fromEdge = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final centerY = constraints.maxHeight * 0.5;
        final start = fromEdge ? (-w * 0.38) : (-w * 0.22);
        final end = fromEdge ? (w * 0.20) : (w * 0.22);
        final from = direction > 0 ? start : end;
        final to = direction > 0 ? end : start;
        final dx = lerpDouble(from, to, t) ?? 0;
        return Stack(
          children: [
            Positioned(
              left: (w * 0.5) - 40,
              right: (w * 0.5) - 40,
              top: centerY - 1,
              child: Container(height: 2, color: color.withValues(alpha: 0.3)),
            ),
            Positioned(
              left: (w * 0.5) - 16 + dx,
              top: centerY - 16,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Transform.flip(
                  flipX: direction < 0,
                  child: Icon(icon, size: 20, color: color),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLongPressHint(
    BuildContext context, {
    required double t,
    required Color color,
  }) {
    final scale = 0.84 + (0.28 * t);
    final alpha = 0.32 + (0.25 * (1 - t));
    return Center(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: alpha),
            border: Border.all(color: color.withValues(alpha: 0.75), width: 2),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.touch_app_rounded, color: color, size: 22),
        ),
      ),
    );
  }
}

class _ScrimWithHolePainter extends CustomPainter {
  final Rect? holeRect;
  final double holeRadius;
  final Color scrimColor;

  const _ScrimWithHolePainter({
    required this.holeRect,
    required this.holeRadius,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (holeRect == null) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = scrimColor
          ..isAntiAlias = true,
      );
      return;
    }

    final scrimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(
        RRect.fromRectAndRadius(holeRect!, Radius.circular(holeRadius)),
      );

    canvas.drawPath(
      scrimPath,
      Paint()
        ..color = scrimColor
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _ScrimWithHolePainter oldDelegate) {
    return oldDelegate.holeRect != holeRect ||
        oldDelegate.holeRadius != holeRadius ||
        oldDelegate.scrimColor != scrimColor;
  }
}

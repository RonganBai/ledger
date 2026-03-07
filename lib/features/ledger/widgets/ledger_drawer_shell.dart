import 'dart:ui';

import 'package:flutter/material.dart';

/// A lightweight drawer "shell" that provides:
/// - Drag-to-open (edge only when closed)
/// - Drag-to-close (scrim + drawer surface)
/// - Backdrop blur + scrim
/// - A sliding Material drawer panel (like a sheet covering content)
///
/// It intentionally does NOT decide what the drawer or content is.
class LedgerDrawerShell extends StatefulWidget {
  const LedgerDrawerShell({
    super.key,
    required this.controller,
    required this.drawerWidth,
    required this.drawer,
    required this.content,
    required this.onTapScrim,
    this.edgeTriggerWidth = 70,
    this.canOpen = true,
    this.duration = const Duration(milliseconds: 360),
    this.curve = Curves.easeOutCubic,
    this.blurSigma = 10,
    this.scrimOpacity = 0.20,
    this.drawerRadius = 24,
    this.drawerElevation = 12,
  });

  /// 0.0 (closed) ~ 1.0 (open)
  final AnimationController controller;

  final double drawerWidth;

  final Widget drawer;
  final Widget content;

  final VoidCallback onTapScrim;

  /// When the drawer is closed, only drags that START within this width (from left edge)
  /// can open the drawer.
  final double edgeTriggerWidth;

  /// If false, the drawer cannot be opened by dragging (closing is still allowed if open).
  final bool canOpen;

  final Duration duration;
  final Curve curve;

  final double blurSigma;
  final double scrimOpacity;

  final double drawerRadius;
  final double drawerElevation;

  @override
  State<LedgerDrawerShell> createState() => _LedgerDrawerShellState();
}

class _LedgerDrawerShellState extends State<LedgerDrawerShell> {
  bool _dragging = false;

  void _animateTo(double v) {
    widget.controller.animateTo(v, duration: widget.duration, curve: widget.curve);
  }

  void _onDragStart(DragStartDetails d) {
    final t = widget.controller.value;

    // If open -> allow drag close from anywhere (scrim/drawer will receive gestures).
    if (t > 0) {
      _dragging = true;
      return;
    }

    // Closed: only allow edge drag open.
    if (!widget.canOpen) {
      _dragging = false;
      return;
    }

    final dx = d.globalPosition.dx;
    if (dx > widget.edgeTriggerWidth) {
      _dragging = false;
      return;
    }
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final delta = d.delta.dx / widget.drawerWidth;
    widget.controller.value = (widget.controller.value + delta).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;

    final v = d.primaryVelocity ?? 0.0;
    if (v.abs() > 500) {
      if (v < 0) {
        _animateTo(0.0);
      } else {
        _animateTo(1.0);
      }
      return;
    }
    if (widget.controller.value >= 0.5) {
      _animateTo(1.0);
    } else {
      _animateTo(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final t = widget.controller.value;
        final slideX = -widget.drawerWidth + widget.drawerWidth * t;

        return Stack(
          children: [
            widget.content,

            // Scrim + blur (only when open)
            if (t > 0)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTapScrim,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.blurSigma * t,
                      sigmaY: widget.blurSigma * t,
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(widget.scrimOpacity * t),
                    ),
                  ),
                ),
              ),

            // Drawer panel
            Positioned(
              left: slideX,
              top: 0,
              bottom: 0,
              width: widget.drawerWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                child: Material(
                  color: cs.surface,
                  elevation: widget.drawerElevation,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(widget.drawerRadius),
                    ),
                  ),
                  child: widget.drawer,
                ),
              ),
            ),

            // Edge opener (only when fully closed, so it won't steal tx swipe gestures)
            if (t == 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: widget.edgeTriggerWidth,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                ),
              ),
          ],
        );
      },
    );
  }
}

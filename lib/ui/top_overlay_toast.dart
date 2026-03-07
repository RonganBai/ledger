import 'dart:async';
import 'package:flutter/material.dart';

class TopOverlayToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    IconData icon = Icons.info_outline,
  }) {
    // 先关掉上一个
    hide();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) {
        final topPadding = MediaQuery.of(ctx).padding.top;
        return _ToastWidget(
          top: topPadding + 12,
          message: message,
          icon: icon,
          onClose: hide,
        );
      },
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, () => hide());
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final double top;
  final String message;
  final IconData icon;
  final VoidCallback onClose;

  const _ToastWidget({
    required this.top,
    required this.message,
    required this.icon,
    required this.onClose,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      left: 12,
      right: 12,
      top: widget.top,
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 18,
                        spreadRadius: 0,
                        offset: Offset(0, 8),
                        color: Color(0x33000000),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.close, size: 18, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

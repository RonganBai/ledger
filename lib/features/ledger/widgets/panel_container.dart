import 'package:flutter/material.dart';

class PanelContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const PanelContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 10),
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 64);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
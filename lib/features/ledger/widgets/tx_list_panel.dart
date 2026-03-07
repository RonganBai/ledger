import 'package:flutter/material.dart';

/// A rounded "bill list" panel that holds the transaction list.
/// The list content should have some padding so tiles don't touch edges.
class TxListPanel extends StatelessWidget {
  const TxListPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 16),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

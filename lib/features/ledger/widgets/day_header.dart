import 'package:flutter/material.dart';

class DayHeader extends StatelessWidget {
  final String title;
  const DayHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
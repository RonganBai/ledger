import 'package:flutter/material.dart';

class LedgerBalanceCard extends StatelessWidget {
  final double balance;

  const LedgerBalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final isNegative = balance < 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNegative
              ? Colors.red.withValues(alpha: 120)
              : scheme.primary.withValues(alpha: 120),
        ),
      ),
      child: Column(
        children: [
          const Text(
            "BALANCE",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "\$${balance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNegative ? "Negative" : "Positive",
            style: TextStyle(
              color: isNegative ? Colors.red : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          )
        ],
      ),
    );
  }
}
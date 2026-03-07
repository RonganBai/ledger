import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final String currencySymbol;

  /// The accent color used for border/gradient (e.g., green normally, red when low balance).
  final Color? accentColor;
  final bool isLow;
  final bool compact;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.currencySymbol,
    required this.isLow,
    this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 390.0).clamp(0.85, 1.15);
    final mainColor = accentColor ?? Colors.green;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleSize = (compact ? 12.0 : 14.0) * scale;
    final valueSize = (compact ? 30.0 : 34.0) * scale;
    final padV = (compact ? 5.0 : 22.0) * scale;
    final padH = (compact ? 14.0 : 18.0) * scale;
    final radius = (compact ? 16.0 : 20.0) * scale;
    final gap1 = (compact ? 2.0 : 10.0) * scale;
    final gap2 = (compact ? 1.0 : 6.0) * scale;
    final statusSize = (compact ? 11.0 : 12.0) * scale;

    final titleColor = isDark ? Colors.white : Colors.black87;
    final valueColor = isDark ? Colors.white : Colors.black;
    final statusColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black54;

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  mainColor.withValues(alpha: 0.32),
                  mainColor.withValues(alpha: 0.18),
                ]
              : [
                  mainColor.withValues(alpha: 0.18),
                  mainColor.withValues(alpha: 0.08),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? mainColor.withValues(alpha: 0.78)
              : mainColor.withValues(alpha: 0.45),
          width: isDark ? 1.6 : 1.2,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: padV, horizontal: padH),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              tr(context, en: 'BALANCE', zh: '当前余额'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: titleColor,
              ),
            ),
            SizedBox(height: gap1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$currencySymbol${balance.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: valueSize,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ),
            SizedBox(height: gap2),
            Text(
              isLow
                  ? tr(context, en: 'Balance Critical', zh: '余额告急')
                  : tr(context, en: 'Healthy', zh: '余额健康'),
              style: TextStyle(
                fontSize: statusSize,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

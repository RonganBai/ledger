import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/settings.dart';
import '../../../l10n/tr.dart';

class BalanceAlert extends StatelessWidget {
  final double balance;
  const BalanceAlert({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    // 屏幕自适应缩放
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / 390.0).clamp(0.85, 1.15);

    return FutureBuilder(
      future: Future.wait([
        Settings.getMinBalance(),
        Settings.getMaxBalance(),
      ]),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();

        final data = snap.data!;
        final double? minB = data[0] as double?;
        final double? maxB = data[1] as double?;

        String? msg;
        late final Color baseColor;
        IconData icon = Icons.info_outline_rounded;

        if (minB != null && balance < minB) {
          msg = tr(context,
              en: 'Balance is below your minimum limit',
              zh: '余额低于你设置的最低值');
          baseColor = Colors.red;
          icon = Icons.warning_amber_rounded;
        } else if (maxB != null && balance > maxB) {
          msg = tr(context,
              en: 'Balance is above your maximum limit',
              zh: '余额高于你设置的最高值');
          baseColor = Colors.orange;
          icon = Icons.trending_up_rounded;
        } else {
          return const SizedBox.shrink();
        }

        final radius = 16.0 * scale;
        final fontSize = 14.0 * scale;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 14 * scale),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: EdgeInsets.symmetric(
              vertical: 14 * scale,
              horizontal: 16 * scale,
            ),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: baseColor.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: baseColor,
                  size: 22 * scale,
                ),
                SizedBox(width: 10 * scale),
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.black, // ✅ 黑色文字更清晰
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
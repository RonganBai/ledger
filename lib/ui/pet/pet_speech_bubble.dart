import 'package:flutter/material.dart';
import 'pet_controller.dart';

class PetSpeechBubble extends StatelessWidget {
  final String text;
  final PetSide side;
  final double maxWidth;

  const PetSpeechBubble({
    super.key,
    required this.text,
    required this.side,
    this.maxWidth = 200,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 8),
            color: Colors.black26,
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.2,
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final tail = CustomPaint(
      size: const Size(16, 12),
      painter: _TailPainter(
        color: Colors.white.withValues(alpha: 0.96),
        side: side,
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: side == PetSide.left
          ? [tail, const SizedBox(width: 4), bubble]
          : [bubble, const SizedBox(width: 4), tail],
    );
  }
}

class _TailPainter extends CustomPainter {
  final Color color;
  final PetSide side;

  _TailPainter({required this.color, required this.side});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();

    if (side == PetSide.left) {
      // 尾巴朝左
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      // 尾巴朝右
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height)
        ..close();
    }

    // ✅ 1️⃣ 先填充
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);

    // ✅ 2️⃣ 再画描边
    final strokePaint = Paint()
      ..color = Colors.black54  // 描边颜色
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;      // 描边粗细

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.side != side;
  }
}
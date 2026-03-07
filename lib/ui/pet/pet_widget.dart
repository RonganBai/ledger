import 'package:flutter/material.dart';
import 'pet_controller.dart';
import 'dart:ui';
import 'pet_config.dart';

class PetWidget extends StatefulWidget {
  final PetState state;
  final PetSide side;

  const PetWidget({
    super.key,
    required this.state,
    required this.side,
  });

  @override
  State<PetWidget> createState() => _PetWidgetState();
}

class _PetWidgetState extends State<PetWidget>
    with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat(reverse: true);

  late final AnimationController _action =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      );

  @override
  void didUpdateWidget(covariant PetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == PetState.action) {
      _action
        ..stop()
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: PetConfig.I, // ✅ 监听配置变化（外观切换立刻生效）
      builder: (context, _) {
        final isDragging = widget.state == PetState.dragging;
        final isSnapping = widget.state == PetState.snapping;

        final skin = PetConfig.I.skin;
        final scaleSize = PetConfig.I.sizeScale;
        final base = widget.side == PetSide.right ? skin.right : skin.left;
        final asset = isDragging ? skin.drag : base;

        final child = SizedBox(
          width: 80 * scaleSize,
          height: 120 * scaleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ✅ 阴影层：同一张图，黑色+模糊+轻微偏移
              Transform.translate(
                offset: const Offset(0, 6),
                child: Opacity(
                  opacity: 0.35,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.black,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        asset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ 正常宠物图
              Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ],
          ),
        );

        return AnimatedBuilder(
          animation: Listenable.merge([_idle, _action]),
          builder: (context, _) {
            final breathe = 1.0 + (_idle.value * 0.05);
            final bob = (_idle.value * 3.0);
            final dragRot = isDragging ? (_idle.value - 0.5) * 0.25 : 0.0;

            final actionJump = widget.state == PetState.action
                ? (-12.0 * Curves.easeOut.transform(_action.value))
                : 0.0;

            return Transform.translate(
              offset: Offset(0, bob + actionJump),
              child: Transform.rotate(
                angle: dragRot,
                child: Transform.scale(
                  scale: breathe,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: isSnapping ? 1.06 : 1.0,
                    child: child,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'pet_bus.dart';
import 'pet_config.dart';
import 'pet_controller.dart';
import 'pet_speech_bubble.dart';
import 'pet_widget.dart';

class PetOverlay extends StatefulWidget {
  const PetOverlay({super.key});

  @override
  State<PetOverlay> createState() => _PetOverlayState();
}

class _PetOverlayState extends State<PetOverlay> with TickerProviderStateMixin {
  final PetController c = PetController();

  @override
  void initState() {
    super.initState();
    PetBus.controller = c;
  }

  @override
  void dispose() {
    if (PetBus.controller == c) PetBus.controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return AnimatedBuilder(
      animation: PetConfig.I,
      builder: (context, _) {
        final scale = PetConfig.I.sizeScale;
        final petSize = Size(80 * scale, 120 * scale);

        return SizedBox.expand(
          child: Stack(
            children: [
              ValueListenableBuilder<Offset>(
                valueListenable: c.pos,
                builder: (context, p, _) {
                  return Positioned(
                    left: p.dx,
                    top: p.dy,
                    child: ValueListenableBuilder<PetState>(
                      valueListenable: c.state,
                      builder: (context, st, _) {
                        return ValueListenableBuilder<PetSide>(
                          valueListenable: c.side,
                          builder: (context, s, _) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: c.speech,
                              builder: (context, text, _) {
                                final bubbleLeft = s == PetSide.left ? petSize.width : null;
                                final bubbleRight = s == PetSide.right ? petSize.width : null;
                                final showBubble = text != null && st != PetState.dragging;

                                return GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: c.onPanStart,
                                  onPanUpdate: (d) => c.onPanUpdate(d, screen, petSize),
                                  onPanEnd: (_) => c.onPanEnd(this, screen, petSize),
                                  onTap: () async {
                                    if (c.consumeDragMoved()) return;
                                    await c.triggerAction(const Duration(milliseconds: 220));
                                    c.say("你好呀～今天记账了吗？");
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      PetWidget(state: st, side: s),
                                      Positioned(
                                        left: bubbleLeft,
                                        right: bubbleRight,
                                        top: 6,
                                        child: AnimatedOpacity(
                                          opacity: showBubble ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 160),
                                          child: AnimatedScale(
                                            scale: showBubble ? 1.0 : 0.92,
                                            duration: const Duration(milliseconds: 160),
                                            child: showBubble
                                                ? PetSpeechBubble(text: text ?? '', side: s)
                                                : const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

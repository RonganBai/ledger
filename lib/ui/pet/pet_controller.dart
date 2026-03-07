import 'package:flutter/material.dart';

enum PetState { idle, dragging, snapping, action }
enum PetSide { left, right }

class PetController {
  final ValueNotifier<Offset> pos = ValueNotifier(const Offset(0, 220));
  final ValueNotifier<PetState> state = ValueNotifier(PetState.idle);
  final ValueNotifier<PetSide> side = ValueNotifier(PetSide.left);

  bool consumeDragMoved() {
    final v = _dragMoved;
    _dragMoved = false;
    return v;
  }
  /// ✅ 气泡文字：null = 不显示
  final ValueNotifier<String?> speech = ValueNotifier<String?>(null);

  double snapPadding = 0;
  Duration snapDuration = const Duration(milliseconds: 260);
  Curve snapCurve = Curves.easeOutBack;

  bool _dragMoved = false;
  Offset _dragStart = Offset.zero;
  Offset _posStart = Offset.zero;

  int _speechToken = 0; // 用于“重复点击刷新倒计时”

  void onPanStart(DragStartDetails d) {
    state.value = PetState.dragging;
    _dragMoved = false;
    _dragStart = d.globalPosition;
    _posStart = pos.value;

    // 拖动时隐藏气泡
    hideSpeech();
  }

  void onPanUpdate(DragUpdateDetails d, Size screen, Size petSize) {
    final delta = d.globalPosition - _dragStart;
    if (delta.distance > 6) _dragMoved = true;

    final raw = _posStart + delta;
    pos.value = Offset(
      raw.dx.clamp(0.0, screen.width - petSize.width),
      raw.dy.clamp(0.0, screen.height - petSize.height),
    );
  }

  Future<void> onPanEnd(
    TickerProvider vsync,
    Size screen,
    Size petSize,
  ) async {
    state.value = PetState.snapping;

    final current = pos.value;
    final centerX = current.dx + petSize.width / 2;
    final snapLeft = centerX < screen.width / 2;
    side.value = snapLeft ? PetSide.left : PetSide.right;

    final targetX = snapLeft
        ? snapPadding
        : (screen.width - petSize.width - snapPadding);

    final target = Offset(targetX, current.dy);

    final controller = AnimationController(vsync: vsync, duration: snapDuration);
    final anim = Tween<Offset>(begin: current, end: target).animate(
      CurvedAnimation(parent: controller, curve: snapCurve),
    );

    void listener() => pos.value = anim.value;
    anim.addListener(listener);

    await controller.forward();
    anim.removeListener(listener);
    controller.dispose();

    state.value = PetState.idle;
  }

  Future<void> triggerAction(Duration duration) async {
    state.value = PetState.action;
    await Future.delayed(duration);
    state.value = PetState.idle;
  }

  bool get dragMoved => _dragMoved;

  /// ✅ 显示气泡若干秒后自动消失（重复调用会刷新计时）
  void say(String text, {Duration duration = const Duration(seconds: 5)}) async {
    _speechToken++;
    final token = _speechToken;

    speech.value = text;

    await Future.delayed(duration);
    if (token == _speechToken) {
      speech.value = null;
    }
  }

  void hideSpeech() {
    _speechToken++;
    speech.value = null;
  }
}
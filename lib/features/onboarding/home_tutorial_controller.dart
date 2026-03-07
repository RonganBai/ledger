import 'package:flutter/widgets.dart';

typedef HomeTutorialStepHook = Future<void> Function();
typedef HomeTutorialFinish = Future<void> Function({required bool skipped});

enum CoachHintAnimation {
  none,
  swipeLeft,
  swipeRight,
  longPress,
  edgeSwipeRight,
}

enum CoachPanelPosition { top, bottom }

class HomeTutorialStep {
  final String id;
  final String groupId;
  final GlobalKey? anchorKey;
  final GlobalKey? secondaryAnchorKey;
  final String title;
  final String message;
  // Relative adjustments based on anchor widget size (not fixed pixels).
  final double highlightDxFactor;
  final double highlightDyFactor;
  final double highlightScale;
  final CoachHintAnimation hintAnimation;
  final bool captureTargetTap;
  final HomeTutorialStepHook? onTargetTap;
  final CoachPanelPosition panelPosition;
  final bool requireAction;
  final HomeTutorialStepHook? onBeforeEnter;

  const HomeTutorialStep({
    required this.id,
    this.groupId = '',
    required this.title,
    required this.message,
    this.anchorKey,
    this.secondaryAnchorKey,
    this.highlightDxFactor = 0,
    this.highlightDyFactor = 0,
    this.highlightScale = 1,
    this.hintAnimation = CoachHintAnimation.none,
    this.captureTargetTap = true,
    this.onTargetTap,
    this.panelPosition = CoachPanelPosition.bottom,
    this.requireAction = false,
    this.onBeforeEnter,
  });
}

class HomeTutorialController extends ChangeNotifier {
  HomeTutorialController({this.onFinish});

  final HomeTutorialFinish? onFinish;

  List<HomeTutorialStep> _steps = const <HomeTutorialStep>[];
  bool _running = false;
  int _index = -1;

  bool get isRunning => _running;
  int get index => _index;
  int get totalSteps => _steps.length;
  List<HomeTutorialStep> get steps => _steps;
  HomeTutorialStep? get currentStep =>
      (_running && _index >= 0 && _index < _steps.length)
      ? _steps[_index]
      : null;
  bool get isLastStep => _running && _index == _steps.length - 1;

  Future<void> start(List<HomeTutorialStep> steps) async {
    if (steps.isEmpty) return;
    _steps = List<HomeTutorialStep>.unmodifiable(steps);
    _running = true;
    _index = 0;
    await _enterCurrentStep();
    notifyListeners();
  }

  Future<void> next() async {
    if (!_running) return;
    if (_index >= _steps.length - 1) {
      await _finish(skipped: false);
      return;
    }
    _index += 1;
    await _enterCurrentStep();
    notifyListeners();
  }

  Future<void> previous() async {
    if (!_running || _index <= 0) return;
    _index -= 1;
    await _enterCurrentStep();
    notifyListeners();
  }

  Future<void> goTo(int targetIndex) async {
    if (!_running) return;
    if (targetIndex < 0 || targetIndex >= _steps.length) return;
    _index = targetIndex;
    await _enterCurrentStep();
    notifyListeners();
  }

  Future<void> skip() async {
    if (!_running) return;
    await _finish(skipped: true);
  }

  Future<void> complete() async {
    if (!_running) return;
    await _finish(skipped: false);
  }

  Future<void> _enterCurrentStep() async {
    final step = currentStep;
    if (step?.onBeforeEnter != null) {
      await step!.onBeforeEnter!.call();
    }
  }

  Future<void> _finish({required bool skipped}) async {
    _running = false;
    _index = -1;
    notifyListeners();
    if (onFinish != null) {
      await onFinish!.call(skipped: skipped);
    }
  }
}

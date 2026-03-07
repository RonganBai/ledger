import 'package:shared_preferences/shared_preferences.dart';

class OnboardingManager {
  static const int _homeTutorialVersion = 1;
  static String get _homeTutorialKey =>
      'onboarding_home_v${_homeTutorialVersion}_done';

  Future<bool> shouldShowHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_homeTutorialKey) ?? false);
  }

  Future<void> markHomeTutorialDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_homeTutorialKey, true);
  }

  Future<void> resetHomeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_homeTutorialKey);
  }
}

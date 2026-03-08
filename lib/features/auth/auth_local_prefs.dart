import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalPrefsData {
  final bool autoLoginEnabled;
  final DateTime? autoLoginUntil;
  final List<String> rememberedEmails;
  final String? lastEmail;

  const AuthLocalPrefsData({
    required this.autoLoginEnabled,
    required this.autoLoginUntil,
    required this.rememberedEmails,
    required this.lastEmail,
  });
}

class AuthLocalPrefs {
  static const String _kAutoLoginEnabled = 'auth_auto_login_enabled';
  static const String _kAutoLoginUntilMs = 'auth_auto_login_until_ms';
  static const String _kRememberedEmails = 'auth_remembered_emails';
  static const String _kLastEmail = 'auth_last_email';

  static Future<AuthLocalPrefsData> read() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool(_kAutoLoginEnabled) ?? false;
    final untilMs = sp.getInt(_kAutoLoginUntilMs);
    final until = untilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(untilMs);
    final emails = (sp.getStringList(_kRememberedEmails) ?? const <String>[])
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList(growable: false);
    final lastEmail = sp.getString(_kLastEmail)?.trim();
    return AuthLocalPrefsData(
      autoLoginEnabled: enabled,
      autoLoginUntil: until,
      rememberedEmails: emails,
      lastEmail: (lastEmail == null || lastEmail.isEmpty) ? null : lastEmail,
    );
  }

  static Future<void> recordSuccessfulLogin({
    required String email,
    required bool autoLogin30Days,
  }) async {
    final normalized = email.trim();
    if (normalized.isEmpty) return;
    final sp = await SharedPreferences.getInstance();

    await sp.setString(_kLastEmail, normalized);

    final list = (sp.getStringList(_kRememberedEmails) ?? <String>[])
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toList(growable: true);
    list.removeWhere((e) => e.toLowerCase() == normalized.toLowerCase());
    list.insert(0, normalized);
    if (list.length > 20) {
      list.removeRange(20, list.length);
    }
    await sp.setStringList(_kRememberedEmails, list);

    await sp.setBool(_kAutoLoginEnabled, autoLogin30Days);
    if (autoLogin30Days) {
      final until = DateTime.now().add(const Duration(days: 30));
      await sp.setInt(_kAutoLoginUntilMs, until.millisecondsSinceEpoch);
    } else {
      await sp.remove(_kAutoLoginUntilMs);
    }
  }

  static Future<bool> shouldKeepExistingSession() async {
    final data = await read();
    if (!data.autoLoginEnabled) return false;
    final until = data.autoLoginUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }
}

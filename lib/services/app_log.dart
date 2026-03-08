import 'package:flutter/foundation.dart';

class AppLog {
  static String _ts() => DateTime.now().toIso8601String();

  static void i(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[${_ts()}] [INFO] [$tag] $message');
  }

  static void w(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[${_ts()}] [WARN] [$tag] $message');
  }

  static void e(String tag, Object error, [StackTrace? st]) {
    if (kReleaseMode) return;
    debugPrint('[${_ts()}] [ERROR] [$tag] $error');
    if (st != null) {
      debugPrint('$st');
    }
  }
}

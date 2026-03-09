import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

final ValueNotifier<String> appVersionText = ValueNotifier<String>('v-');

Future<void> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.trim();
    final build = info.buildNumber.trim();
    appVersionText.value = build.isEmpty ? 'v$version' : 'v$version+$build';
  } catch (_) {
    appVersionText.value = 'v-';
  }
}


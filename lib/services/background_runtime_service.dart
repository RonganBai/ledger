import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_log.dart';

@pragma('vm:entry-point')
class BackgroundRuntimeService {
  static const _channelId = 'ledger_background_runtime';
  static const _channelName = 'Ledger Background Runtime';
  static const _channelDesc = 'Keeps Ledger running in background';
  static const _notificationId = 901;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initializeAndStart({bool startNow = false}) async {
    if (!Platform.isAndroid) {
      AppLog.i('BackgroundService', 'Skip init: non-Android platform');
      return;
    }
    try {
      await _ensureAndroidNotificationChannel();
      final service = FlutterBackgroundService();
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          autoStartOnBoot: false,
          isForegroundMode: true,
          foregroundServiceNotificationId: _notificationId,
          initialNotificationTitle: 'Ledger 正在后台运行',
          initialNotificationContent: '保持账单与任务能力可用',
          notificationChannelId: _channelId,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      );

      final running = await service.isRunning();
      if (startNow && !running) {
        await service.startService();
      }
      AppLog.i(
        'BackgroundService',
        'Configured. startNow=$startNow running=${await service.isRunning()}',
      );
    } catch (e, st) {
      AppLog.e('BackgroundService', e, st);
      AppLog.w(
        'BackgroundService',
        'Background service init failed, continue without it',
      );
    }
  }

  static Future<void> _ensureAndroidNotificationChannel() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.low,
    );
    await android.createNotificationChannel(channel);
    AppLog.i('BackgroundService', 'Notification channel ensured: $_channelId');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();

    service.on('stopService').listen((_) {
      service.stopSelf();
    });

    Timer.periodic(const Duration(minutes: 15), (timer) async {
      if (service is AndroidServiceInstance) {
        final isForeground = await service.isForegroundService();
        if (isForeground) {
          service.setForegroundNotificationInfo(
            title: 'Ledger 正在后台运行',
            content:
                '最近心跳: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          );
        }
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }
}

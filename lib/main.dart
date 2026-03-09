import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/app_version.dart';
import 'data/db/app_database.dart';
import 'features/reports/report_service.dart';
import 'services/app_log.dart';
import 'services/background_runtime_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.i('Bootstrap', 'App startup begin');
  await loadAppVersion();
  var supabaseReady = false;

  try {
    await Supabase.initialize(
      url: 'https://bgtkgcnivqvkjhurtthm.supabase.co',
      anonKey: 'sb_publishable_Pq1nkxrmB5Ils-eiBImp_A_7PUVBJxv',
    );
    supabaseReady = true;
    AppLog.i('Supabase', 'Initialize success');
  } catch (e, st) {
    AppLog.e('Supabase', e, st);
    AppLog.w('Supabase', 'Initialize failed, continue without cloud features');
  }

  final db = AppDatabase();
  AppLog.i('Database', 'Local DB initialized');
  try {
    await BackgroundRuntimeService.initializeAndStart(startNow: false);
    AppLog.i('BackgroundService', 'Background runtime initialized');
  } catch (e, st) {
    AppLog.e('BackgroundService', e, st);
    AppLog.w(
      'BackgroundService',
      'Continue app launch without background service',
    );
  }

  runApp(MyApp(db: db));
  AppLog.i('Bootstrap', 'runApp completed');

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (supabaseReady) {
      final client = Supabase.instance.client;
      AppLog.i('Supabase', 'REST url=${client.rest.url}');
      AppLog.i(
        'Supabase',
        'Current session state=${client.auth.currentSession == null ? 'signed_out' : 'signed_in'}',
      );

      try {
        final res = await client.from('accounts').select('id').limit(1);
        AppLog.i('Supabase', 'accounts table probe success: rows=${res.length}');
      } catch (e, st) {
        AppLog.w(
          'Supabase',
          'accounts table probe failed (may be RLS/network/config): $e',
        );
        AppLog.e('Supabase', e, st);
      }
    }

    try {
      final accounts = await (db.select(
        db.accounts,
      )..where((a) => a.isActive.equals(true))).get();
      for (final a in accounts) {
        await ReportService.archiveLastMonthIfNeeded(db, accountId: a.id);
      }
      AppLog.i(
        'ReportService',
        'archiveLastMonthIfNeeded completed. activeAccounts=${accounts.length}',
      );
    } catch (e, st) {
      AppLog.e('ReportService', e, st);
    }
  });
}

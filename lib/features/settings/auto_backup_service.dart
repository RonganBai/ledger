import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../services/app_log.dart';
import 'import_export_service.dart';

class AutoBackupService {
  AutoBackupService._();

  static final AutoBackupService I = AutoBackupService._();
  static const String _dailyFolderName = 'ledger_backups/daily';

  Future<void> runDailyBackupIfNeeded(
    AppDatabase db, {
    int retentionDays = 14,
  }) async {
    final today = _yyyyMmDd(DateTime.now().toUtc());
    final folder = await _dailyBackupFolder();
    final todayFile = File(
      '${folder.path}${Platform.pathSeparator}backup_$today.json',
    );

    if (await todayFile.exists()) {
      await _cleanupOldBackups(folder, retentionDays: retentionDays);
      return;
    }

    final svc = ImportExportService(db);
    final jsonString = await svc.exportFullBackupJsonString();
    await _writeAtomic(todayFile, jsonString);
    await _cleanupOldBackups(folder, retentionDays: retentionDays);
    AppLog.i('AutoBackup', 'Daily backup created: ${todayFile.path}');
  }

  Future<Directory> _dailyBackupFolder() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(
      '${dir.path}${Platform.pathSeparator}${_dailyFolderName.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  Future<void> _cleanupOldBackups(
    Directory folder, {
    required int retentionDays,
  }) async {
    final files = await folder
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return;

    files.sort((a, b) => b.path.compareTo(a.path));
    final maxKeep = retentionDays < 1 ? 1 : retentionDays;
    for (int i = maxKeep; i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {
        // keep non-fatal cleanup failures silent
      }
    }
  }

  Future<void> _writeAtomic(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  String _yyyyMmDd(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}';
  }
}

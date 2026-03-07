import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'import_export_service.dart';
import '../../data/db/app_database.dart';

class AutoBackupService {
  AutoBackupService._();
  static final I = AutoBackupService._();

  Timer? _debounce;

  /// 自动备份文件：更新 App 不会丢（Documents 目录）
  Future<File> _autoLatestFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'ledger_backups'));
    if (!await folder.exists()) await folder.create(recursive: true);
    return File(p.join(folder.path, 'auto_latest.json'));
  }

  /// 触发一次“延迟写入”（防抖：多次编辑只写一次）
  void scheduleBackup(AppDatabase db, {Duration debounce = const Duration(milliseconds: 800)}) {
    _debounce?.cancel();
    _debounce = Timer(debounce, () async {
      await writeLatestNow(db);
    });
  }

  /// 立即写入 latest（复用你现有的导出 JSON）
  Future<void> writeLatestNow(AppDatabase db) async {
    final svc = ImportExportService(db);
    final jsonString = await svc.exportFullBackupJsonString();
    final file = await _autoLatestFile();
    await _writeAtomic(file, jsonString);

    // ✅ 加在这里（写入完成之后）
    final len = await file.length();
    // ignore: avoid_print
    print('[AutoBackup] saved: ${file.path} (${len} bytes)');
  }

  Future<Map<String, dynamic>?> readLatest() async {
    final file = await _autoLatestFile();
    if (!await file.exists()) return null;
    final s = await file.readAsString();
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<void> _writeAtomic(File file, String content) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  void dispose() {
    _debounce?.cancel();
  }
}
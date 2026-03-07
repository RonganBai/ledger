import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class BackupService {
  BackupService._();
  static final I = BackupService._();

  // 你可以改成你自己的 schema 版本
  static const int backupSchemaVersion = 1;

  Future<Directory> _backupDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docDir.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> writeLatest(Map<String, dynamic> payload) async {
    final dir = await _backupDir();
    final file = File(p.join(dir.path, 'latest.json'));
    await _writeAtomicJson(file, payload);
  }

  Future<void> writeMonthlySnapshot(String ym, Map<String, dynamic> payload) async {
    final dir = await _backupDir();
    final monthlyDir = Directory(p.join(dir.path, 'monthly'));
    if (!await monthlyDir.exists()) await monthlyDir.create(recursive: true);

    final file = File(p.join(monthlyDir.path, '$ym.json'));
    await _writeAtomicJson(file, payload);
  }

  Future<Map<String, dynamic>?> readLatest() async {
    final dir = await _backupDir();
    final file = File(p.join(dir.path, 'latest.json'));
    if (!await file.exists()) return null;
    final s = await file.readAsString();
    return jsonDecode(s) as Map<String, dynamic>;
  }

  Future<void> _writeAtomicJson(File file, Map<String, dynamic> payload) async {
    final data = <String, dynamic>{
      'schemaVersion': backupSchemaVersion,
      'savedAt': DateTime.now().toIso8601String(),
      ...payload,
    };

    final tmp = File('${file.path}.tmp');
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    await tmp.writeAsString(jsonStr, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }
}
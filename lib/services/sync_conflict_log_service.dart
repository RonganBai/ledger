import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncConflictEvent {
  final DateTime time;
  final String direction;
  final String reason;
  final String localTxId;
  final String cloudTxId;
  final String detail;

  const SyncConflictEvent({
    required this.time,
    required this.direction,
    required this.reason,
    required this.localTxId,
    required this.cloudTxId,
    required this.detail,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'time': time.toUtc().toIso8601String(),
    'direction': direction,
    'reason': reason,
    'local_tx_id': localTxId,
    'cloud_tx_id': cloudTxId,
    'detail': detail,
  };

  static SyncConflictEvent fromJson(Map<String, dynamic> json) {
    return SyncConflictEvent(
      time: DateTime.tryParse('${json['time'] ?? ''}') ?? DateTime.now(),
      direction: '${json['direction'] ?? ''}',
      reason: '${json['reason'] ?? ''}',
      localTxId: '${json['local_tx_id'] ?? ''}',
      cloudTxId: '${json['cloud_tx_id'] ?? ''}',
      detail: '${json['detail'] ?? ''}',
    );
  }
}

class SyncConflictLogService {
  static const String _kKey = 'sync_conflict_events_v1';
  static const int _maxEvents = 200;

  Future<List<SyncConflictEvent>> readEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? const <String>[];
    final out = <SyncConflictEvent>[];
    for (final entry in raw) {
      try {
        out.add(
          SyncConflictEvent.fromJson(jsonDecode(entry) as Map<String, dynamic>),
        );
      } catch (_) {
        // ignore malformed rows
      }
    }
    return out;
  }

  Future<void> append(SyncConflictEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? <String>[];
    raw.insert(0, jsonEncode(event.toJson()));
    if (raw.length > _maxEvents) {
      raw.removeRange(_maxEvents, raw.length);
    }
    await prefs.setStringList(_kKey, raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

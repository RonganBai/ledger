import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/sync_conflict_log_service.dart';

class SyncConflictLogPage extends StatefulWidget {
  const SyncConflictLogPage({super.key});

  @override
  State<SyncConflictLogPage> createState() => _SyncConflictLogPageState();
}

class _SyncConflictLogPageState extends State<SyncConflictLogPage> {
  final SyncConflictLogService _service = SyncConflictLogService();
  bool _loading = true;
  List<SyncConflictEvent> _events = const <SyncConflictEvent>[];

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final events = await _service.readEvents();
    if (!mounted) return;
    setState(() {
      _events = events;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Clear conflict log?', '清空冲突日志？')),
        content: Text(
          _t('This only clears local conflict history view.', '这只会清空本地冲突历史展示。'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Clear', '清空')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.clear();
    if (!mounted) return;
    setState(() => _events = const <SyncConflictEvent>[]);
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final l = dt.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Sync Conflict Log', '同步冲突日志')),
        actions: [
          IconButton(
            tooltip: _t('Refresh', '刷新'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: _t('Clear', '清空'),
            onPressed: _events.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? Center(child: Text(_t('No conflict records yet.', '当前没有冲突记录。')))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _events.length,
              separatorBuilder: (_, unused) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = _events[i];
                final color = e.direction == 'local_to_cloud'
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary;
                final dirText = e.direction == 'local_to_cloud'
                    ? _t('Local -> Cloud', '本地 -> 云端')
                    : _t('Cloud -> Local', '云端 -> 本地');
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dirText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              _fmt(e.time),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${_t('Reason', '原因')}: ${e.reason}'),
                        Text('${_t('Local Tx', '本地账单')}: ${e.localTxId}'),
                        Text('${_t('Cloud Tx', '云端账单')}: ${e.cloudTxId}'),
                        if (e.detail.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(e.detail),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_service.dart';

class AdminUserDetailPage extends StatefulWidget {
  final String userId;

  const AdminUserDetailPage({super.key, required this.userId});

  @override
  State<AdminUserDetailPage> createState() => _AdminUserDetailPageState();
}

class _AdminUserDetailPageState extends State<AdminUserDetailPage> {
  final AdminService _service = AdminService();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  AdminUserDetail? _detail;

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.getUserDetail(widget.userId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _changeRole(AdminUserSummary user) async {
    final action = user.isAdmin
        ? _t('demote this user to normal user', '将该用户降级为普通用户')
        : _t('promote this user to admin', '将该用户升级为管理员');
    final confirmed = await _confirmAction(
      title: user.isAdmin
          ? _t('Confirm Demotion', '确认降级')
          : _t('Confirm Promotion', '确认升级'),
      message:
          '${_t('Target', '目标用户')}: ${user.email}\n${_t('Name', '名称')}: ${user.displayName}\n${_t('Action', '操作')}: $action',
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (user.isAdmin) {
        await _service.revokeAdmin(user.userId);
      } else {
        await _service.grantAdmin(user.userId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isAdmin
                ? _t('Admin permission removed.', '管理员权限已移除。')
                : _t('Admin permission granted.', '管理员权限已授予。'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeUserState(AdminUserSummary user) async {
    final disable = !user.isDisabled;
    String? reason;
    if (disable) {
      reason = await _askDisableReason();
      if (reason == null) return;
    }
    final confirmed = await _confirmAction(
      title: disable
          ? _t('Confirm Disable', '确认禁用')
          : _t('Confirm Restore', '确认恢复'),
      message:
          '${_t('Target', '目标用户')}: ${user.email}\n${_t('Name', '名称')}: ${user.displayName}\n${_t('Action', '操作')}: ${disable ? _t('Disable user access', '禁用该用户访问') : _t('Restore user access', '恢复该用户访问')}',
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (disable) {
        await _service.disableUser(user.userId, reason: reason);
      } else {
        await _service.restoreUser(user.userId);
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            disable
                ? _t('User has been disabled.', '用户已被禁用。')
                : _t('User access has been restored.', '用户访问已恢复。'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markResolved(AdminFeedbackItem feedback) async {
    if (feedback.isResolved) return;
    final confirmed = await _confirmAction(
      title: _t('Mark Feedback Resolved', '标记反馈为已处理'),
      message:
          '${_t('Feedback from', '反馈来自')}: ${feedback.displayNameSnapshot}\n${_t('Submitted', '提交时间')}: ${_formatTime(feedback.createdAt)}',
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.markFeedbackResolved(feedback.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Feedback marked as resolved.', '反馈已标记为已处理。')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t('Confirm', '确认')),
          ),
        ],
      ),
    );
  }

  Future<String?> _askDisableReason() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Disable Reason', '禁用原因')),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: _t(
              'Optional reason shown in system logs',
              '可选，记录到系统日志中的原因',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(_t('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: Text(_t('Continue', '继续')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  String _humanizeError(Object error) {
    final raw = error.toString();
    if (raw.contains('cannot_revoke_self')) {
      return _t(
        'The current admin account cannot demote itself.',
        '当前管理员账号不能降级自己。',
      );
    }
    if (raw.contains('cannot_revoke_last_admin')) {
      return _t(
        'The last active admin cannot be removed.',
        '系统最后一个管理员不能被移除。',
      );
    }
    if (raw.contains('cannot_disable_self')) {
      return _t(
        'The current admin account cannot disable itself.',
        '当前管理员账号不能禁用自己。',
      );
    }
    if (raw.contains('cannot_disable_last_admin')) {
      return _t(
        'The last active admin cannot be disabled.',
        '系统最后一个管理员不能被禁用。',
      );
    }
    if (raw.contains('forbidden')) {
      return _t(
        'Only active admins can use this page.',
        '只有有效管理员可以使用此页面。',
      );
    }
    return raw;
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '-';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }

  Color _statusColor(BuildContext context, bool active) {
    final cs = Theme.of(context).colorScheme;
    return active ? cs.primaryContainer : cs.errorContainer;
  }

  Color _statusTextColor(BuildContext context, bool active) {
    final cs = Theme.of(context).colorScheme;
    return active ? cs.onPrimaryContainer : cs.onErrorContainer;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('User Detail', '用户详情')),
        actions: [
          IconButton(
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
          ? Center(
              child: Text(
                _error ?? _t('No user detail available.', '暂无用户详情。'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              detail.user.displayName,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (detail.user.isCurrentUser)
                              Chip(
                                label: Text(
                                  _t('Current Admin', '当前管理员'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _statusTextColor(context, true),
                                  ),
                                ),
                                backgroundColor: _statusColor(context, true),
                              ),
                            Chip(
                              label: Text(
                                detail.user.isAdmin
                                    ? _t('Admin', '管理员')
                                    : _t('User', '普通用户'),
                              ),
                            ),
                            Chip(
                              label: Text(
                                detail.user.isDisabled
                                    ? _t('Disabled', '已禁用')
                                    : _t('Enabled', '正常'),
                                style: TextStyle(
                                  color: _statusTextColor(
                                    context,
                                    !detail.user.isDisabled,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              backgroundColor: _statusColor(
                                context,
                                !detail.user.isDisabled,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          '${_t('Email', '邮箱')}: ${detail.user.email}',
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          '${_t('Masked Email', '脱敏邮箱')}: ${detail.user.maskedEmail}',
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          '${_t('User ID', '用户 ID')}: ${detail.user.userId}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_t('Created', '注册时间')}: ${_formatTime(detail.user.createdAt)}',
                        ),
                        if ((detail.user.disabledReason ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${_t('Disable Reason', '禁用原因')}: ${detail.user.disabledReason}',
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: 220,
                              child: FilledButton(
                                onPressed:
                                    _saving ||
                                        (detail.user.isCurrentUser &&
                                            detail.user.isAdmin)
                                    ? null
                                    : () => _changeRole(detail.user),
                                child: Text(
                                  detail.user.isCurrentUser &&
                                          detail.user.isAdmin
                                      ? _t('Current Admin', '当前管理员')
                                      : detail.user.isAdmin
                                      ? _t('Demote to User', '降级为普通用户')
                                      : _t('Promote to Admin', '升级为管理员'),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: OutlinedButton(
                                onPressed:
                                    _saving || detail.user.isCurrentUser
                                    ? null
                                    : () => _changeUserState(detail.user),
                                child: Text(
                                  detail.user.isDisabled
                                      ? _t('Restore User', '恢复用户')
                                      : _t('Disable User', '禁用用户'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: _t('Today Feedback', '今日反馈'),
                        value: '${detail.todayFeedbackCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: _t('All Feedback', '累计反馈'),
                        value: '${detail.recentFeedbackCount}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: _t('Pending', '未处理'),
                        value: '${detail.pendingFeedbackCount}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _t('Recent Feedback', '最近反馈'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (detail.feedbacks.isEmpty)
                  Text(_t('No feedback yet.', '暂无反馈。'))
                else
                  ...detail.feedbacks.map(
                    (feedback) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    feedback.displayNameSnapshot,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    feedback.isResolved
                                        ? _t('Resolved', '已处理')
                                        : _t('Pending', '未处理'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_t('Submitted', '提交时间')}: ${_formatTime(feedback.createdAt)}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_t('Masked Email', '脱敏邮箱')}: ${feedback.maskedEmailSnapshot}',
                            ),
                            const SizedBox(height: 8),
                            Text(feedback.content),
                            if (feedback.resolvedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${_t('Resolved At', '处理时间')}: ${_formatTime(feedback.resolvedAt)}',
                              ),
                            ],
                            if (!feedback.isResolved) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonal(
                                  onPressed: _saving
                                      ? null
                                      : () => _markResolved(feedback),
                                  child: Text(
                                    _t('Mark Resolved', '标记已处理'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _t('Audit Logs', '操作记录'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (detail.auditLogs.isEmpty)
                  Text(_t('No audit logs yet.', '暂无操作记录。'))
                else
                  ...detail.auditLogs.map(
                    (log) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(_labelForAction(log.action)),
                        subtitle: Text(
                          '${log.actorDisplayName}  ${_t('at', '于')}  ${_formatTime(log.createdAt)}',
                        ),
                        trailing: Text(
                          log.targetDisplayName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _labelForAction(String action) {
    switch (action) {
      case 'grant_admin':
        return _t('Granted admin permission', '授予管理员权限');
      case 'revoke_admin':
        return _t('Revoked admin permission', '撤销管理员权限');
      case 'disable_user':
        return _t('Disabled user', '禁用用户');
      case 'restore_user':
        return _t('Restored user', '恢复用户');
      case 'resolve_feedback':
        return _t('Resolved feedback', '处理反馈');
      default:
        return action;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

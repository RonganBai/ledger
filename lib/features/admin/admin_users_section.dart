import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_service.dart';
import 'admin_shared.dart';
import 'admin_user_detail_page.dart';

class AdminUsersSection extends StatefulWidget {
  final bool blockedMode;

  const AdminUsersSection({
    super.key,
    required this.blockedMode,
  });

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  static const int _pageSize = 20;

  final AdminService _service = AdminService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;
  bool _hasMore = true;
  DateTime? _cursor;
  String? _error;
  String _roleFilter = 'all';
  String _feedbackFilter = 'all';
  Timer? _searchDebounce;
  List<AdminUserSummary> _users = const <AdminUserSummary>[];

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_handleScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _service.listUsers(
        pageSize: _pageSize,
        cursor: reset ? null : _cursor,
        query: _searchCtrl.text,
        roleFilter: widget.blockedMode ? 'all' : _roleFilter,
        disabledFilter: widget.blockedMode ? 'disabled' : 'all',
        feedbackFilter: _feedbackFilter,
      );
      if (!mounted) return;
      setState(() {
        _users = reset
            ? result.users
            : <AdminUserSummary>[..._users, ...result.users];
        _cursor = result.nextCursor;
        _hasMore = result.hasMore && result.nextCursor != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(_load(reset: false));
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_load(reset: true)),
    );
  }

  Future<void> _openDetail(AdminUserSummary user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailPage(userId: user.userId),
      ),
    );
    if (!mounted) return;
    await _load(reset: true);
  }

  Future<void> _changeRole(AdminUserSummary user) async {
    final confirmed = await _confirmAction(
      title: user.isAdmin
          ? _t('Confirm Demotion', '确认降级')
          : _t('Confirm Promotion', '确认升级'),
      message:
          '${_t('Target', '目标用户')}: ${user.email}\n${_t('Name', '名称')}: ${user.displayName}',
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
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
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
          '${_t('Target', '目标用户')}: ${user.email}\n${_t('Name', '名称')}: ${user.displayName}',
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
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                enabled: !_saving,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  hintText: _t(
                    'Search by email, nickname or masked email',
                    '按邮箱、昵称或脱敏邮箱搜索',
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
              ),
              const SizedBox(height: 12),
              if (!widget.blockedMode)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDropdownFilter(
                        value: _roleFilter,
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(_t('All Roles', '全部角色')),
                          ),
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text(_t('Admins', '管理员')),
                          ),
                          DropdownMenuItem(
                            value: 'user',
                            child: Text(_t('Users', '普通用户')),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _roleFilter = value!);
                          unawaited(_load(reset: true));
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildDropdownFilter(
                        value: _feedbackFilter,
                        items: <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(_t('All Feedback', '全部反馈')),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text(_t('Pending Feedback', '未处理反馈')),
                          ),
                          DropdownMenuItem(
                            value: 'resolved',
                            child: Text(_t('No Pending', '无待处理')),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _feedbackFilter = value!);
                          unawaited(_load(reset: true));
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.blockedMode
                          ? _t('No blocked users found.', '暂无被封禁用户。')
                          : _t(
                              'No users matched the current search and filters.',
                              '当前搜索和筛选条件下没有匹配的用户。',
                            ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _users.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _users.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final user = _users[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdminUserCard(
                          user: user,
                          t: _t,
                          saving: _saving,
                          onTap: () => _openDetail(user),
                          onToggleRole:
                              user.isCurrentUser && user.isAdmin
                              ? null
                              : () => _changeRole(user),
                          onToggleDisabled: user.isCurrentUser
                              ? null
                              : () => _changeUserState(user),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        items: items,
        onChanged: _saving ? null : onChanged,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

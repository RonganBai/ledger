import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/db/app_database.dart';
import '../../l10n/tr.dart';
import '../ledger/widgets/account_manage_page.dart';
import 'account_profile_service.dart';
import 'account_security_page.dart';

class AccountManagementPage extends StatefulWidget {
  final AppDatabase db;
  final bool isGuestMode;
  final Future<void> Function(Account created)? onAccountCreated;
  final Future<void> Function(Account oldAccount, Account newAccount)?
  onAccountUpdated;
  final Future<void> Function(Account deleted)? onAccountDeleted;

  const AccountManagementPage({
    super.key,
    required this.db,
    required this.isGuestMode,
    this.onAccountCreated,
    this.onAccountUpdated,
    this.onAccountDeleted,
  });

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final _nameCtrl = TextEditingController();
  final AccountProfileService _service = AccountProfileService();

  String? _gender;
  int? _birthYear;
  int? _birthMonth;
  bool _loading = true;
  bool _saving = false;
  bool _editingProfile = false;
  DateTime? _lastSyncedAt;
  String? _error;

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _service.loadCurrentProfile();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = p?.displayName ?? '';
        _gender = p?.gender;
        _birthYear = p?.birthYear;
        _birthMonth = p?.birthMonth;
        _lastSyncedAt = p?.updatedAt;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _nameCtrl.text.trim();
    if (displayName.isEmpty) {
      setState(() => _error = _t('Please enter username.', '请输入用户名。'));
      return;
    }
    if (widget.isGuestMode) {
      setState(
        () => _error = _t('Guest mode cannot sync profile.', '访客模式无法同步个人信息。'),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.saveCurrentProfile(
        AccountProfile(
          displayName: displayName,
          gender: _gender,
          birthYear: _birthYear,
          birthMonth: _birthMonth,
        ),
      );
      if (!mounted) return;
      setState(() {
        _editingProfile = false;
        _lastSyncedAt = DateTime.now();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('Profile saved', '个人信息已保存'))));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      if (e.code == '42501') {
        setState(
          () => _error = _t(
            'Profile save was blocked by database RLS policy. Please apply profile table policies in Supabase.',
            '个人信息保存被数据库 RLS 策略拦截，请先在 Supabase 配置个人信息表策略。',
          ),
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _genderLabel() {
    switch (_gender) {
      case 'male':
        return _t('Male', '男');
      case 'female':
        return _t('Female', '女');
      case 'other':
        return _t('Other', '其他');
      default:
        return _t('Not set', '未设置');
    }
  }

  String _birthLabel() {
    if (_birthYear == null && _birthMonth == null) {
      return _t('Not set', '未设置');
    }
    if (_birthYear != null && _birthMonth != null) {
      return '$_birthYear-${_birthMonth.toString().padLeft(2, '0')}';
    }
    return '${_birthYear ?? '--'}-${_birthMonth?.toString().padLeft(2, '0') ?? '--'}';
  }

  String _fmtDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    final l = dt.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    final years = List<int>.generate(121, (i) => nowYear - i);

    return Scaffold(
      appBar: AppBar(title: Text(_t('Account Management', '账户管理'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _t('Personal Information', '个人信息'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                      () => _editingProfile = !_editingProfile,
                                    ),
                              icon: Icon(
                                _editingProfile
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.edit_rounded,
                              ),
                              label: Text(
                                _editingProfile
                                    ? _t('Done Editing', '完成编辑')
                                    : _t('Edit Profile', '编辑个人信息'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.person_rounded),
                          title: Text(_t('Username', '用户名')),
                          subtitle: Text(
                            _nameCtrl.text.trim().isEmpty
                                ? _t('Not set', '未设置')
                                : _nameCtrl.text.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.wc_rounded),
                          title: Text(_t('Gender', '性别')),
                          subtitle: Text(
                            _genderLabel(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_rounded),
                          title: Text(_t('Birth Year-Month', '出生年月')),
                          subtitle: Text(
                            _birthLabel(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cloud_done_rounded),
                          title: Text(_t('Last Synced', '最后同步时间')),
                          subtitle: Text(
                            _lastSyncedAt == null
                                ? _t('Not synced yet', '尚未同步')
                                : _fmtDateTime(_lastSyncedAt!),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: _editingProfile
                              ? Padding(
                                  key: const ValueKey('editing_hint'),
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    _t(
                                      'Editing mode: update fields below and save.',
                                      '编辑模式：在下方修改后点击保存。',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: _editingProfile
                              ? Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _nameCtrl,
                                      decoration: InputDecoration(
                                        labelText: _t('Username', '用户名'),
                                        prefixIcon: const Icon(
                                          Icons.person_rounded,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue: _gender,
                                      decoration: InputDecoration(
                                        labelText: _t('Gender', '性别'),
                                        prefixIcon: const Icon(
                                          Icons.wc_rounded,
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text(_t('Male', '男')),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text(_t('Female', '女')),
                                        ),
                                        DropdownMenuItem(
                                          value: 'other',
                                          child: Text(_t('Other', '其他')),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _gender = v),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            initialValue: _birthYear,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                'Birth Year',
                                                '出生年份',
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.calendar_today_rounded,
                                              ),
                                            ),
                                            items: years
                                                .map(
                                                  (y) => DropdownMenuItem<int>(
                                                    value: y,
                                                    child: Text('$y'),
                                                  ),
                                                )
                                                .toList(growable: false),
                                            onChanged: (v) =>
                                                setState(() => _birthYear = v),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            initialValue: _birthMonth,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                              labelText: _t(
                                                'Birth Month',
                                                '出生月份',
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.date_range_rounded,
                                              ),
                                            ),
                                            items:
                                                List<int>.generate(
                                                      12,
                                                      (i) => i + 1,
                                                    )
                                                    .map(
                                                      (m) =>
                                                          DropdownMenuItem<int>(
                                                            value: m,
                                                            child: Text(
                                                              m.toString(),
                                                            ),
                                                          ),
                                                    )
                                                    .toList(growable: false),
                                            onChanged: (v) =>
                                                setState(() => _birthMonth = v),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: _saving ? null : _saveProfile,
                                      icon: const Icon(Icons.save_rounded),
                                      label: Text(
                                        _saving
                                            ? _t('Saving...', '保存中...')
                                            : _t('Save Profile', '保存个人信息'),
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        title: Text(_t('Manage Accounts', '管理账户')),
                        subtitle: Text(
                          _t(
                            'Create, edit, sort and archive bill accounts',
                            '创建、编辑、排序和归档账单账户',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AccountManagePage(
                              db: widget.db,
                              onAccountCreated: widget.onAccountCreated,
                              onAccountUpdated: widget.onAccountUpdated,
                              onAccountDeleted: widget.onAccountDeleted,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.shield_rounded),
                        title: Text(_t('Account Security', '账户安全')),
                        subtitle: Text(
                          _t('Change password and bound email', '修改密码和绑定邮箱'),
                        ),
                        trailing: Icon(
                          widget.isGuestMode
                              ? Icons.block_rounded
                              : Icons.chevron_right,
                        ),
                        enabled: !widget.isGuestMode,
                        onTap: widget.isGuestMode
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AccountSecurityPage(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

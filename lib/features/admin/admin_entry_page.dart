import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../data/db/app_database.dart';
import '../../features/ledger/ledger_home.dart';
import '../../l10n/tr.dart';
import '../../services/admin_service.dart';
import 'admin_dashboard_page.dart';

class AdminEntryPage extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final bool isGuestMode;
  final VoidCallback? onExitGuestMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;
  final String? themeBackgroundImagePath;
  final ValueChanged<String?> onThemeBackgroundImageChanged;
  final double themeBackgroundMist;
  final ValueChanged<double> onThemeBackgroundMistChanged;

  const AdminEntryPage({
    super.key,
    required this.db,
    required this.onToggleLocale,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.isGuestMode,
    this.onExitGuestMode,
    required this.themeStyle,
    required this.onThemeStyleChanged,
    required this.themeBackgroundImagePath,
    required this.onThemeBackgroundImageChanged,
    required this.themeBackgroundMist,
    required this.onThemeBackgroundMistChanged,
  });

  @override
  State<AdminEntryPage> createState() => _AdminEntryPageState();
}

class _AdminEntryPageState extends State<AdminEntryPage> {
  final AdminService _adminService = AdminService();
  final TextEditingController _pinCtrl = TextEditingController();

  bool _loading = true;
  bool _isAdmin = false;
  bool _pinVerified = false;
  String? _error;

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isAdmin = await _adminService.isCurrentUserAdmin();
      if (!mounted) return;
      setState(() => _isAdmin = isAdmin);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
        _error = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openLedger() async {
    final parentNavigator = Navigator.of(context);
    await parentNavigator.push(
      MaterialPageRoute(
        builder: (_) => LedgerHome(
          db: widget.db,
          onReturnToAdminEntry: () {
            if (parentNavigator.canPop()) {
              parentNavigator.pop();
            }
          },
          onToggleLocale: widget.onToggleLocale,
          onToggleTheme: widget.onToggleTheme,
          isDarkMode: widget.isDarkMode,
          isGuestMode: widget.isGuestMode,
          onExitGuestMode: widget.onExitGuestMode,
          themeStyle: widget.themeStyle,
          onThemeStyleChanged: widget.onThemeStyleChanged,
          themeBackgroundImagePath: widget.themeBackgroundImagePath,
          onThemeBackgroundImageChanged: widget.onThemeBackgroundImageChanged,
          themeBackgroundMist: widget.themeBackgroundMist,
          onThemeBackgroundMistChanged: widget.onThemeBackgroundMistChanged,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openAdmin() async {
    await Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) => AdminDashboardPage(
          onToggleLocale: widget.onToggleLocale,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
  }

  void _verifyPin() {
    if (_adminService.verifyPin(_pinCtrl.text)) {
      setState(() {
        _pinVerified = true;
        _error = null;
      });
      return;
    }
    setState(() => _error = _t('Incorrect admin PIN.', '管理员密码错误。'));
  }

  Widget _buildAdminChoice() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Admin Entry', '管理员入口')),
        actions: [
          IconButton(
            tooltip: _t('Logout', '退出登录'),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: _EntryCard(
                    icon: Icons.wallet_rounded,
                    title: _t('Ledger App', '记账应用'),
                    subtitle: _t('Use the normal ledger workspace', '进入普通记账界面'),
                    onTap: _openLedger,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _EntryCard(
                    icon: Icons.admin_panel_settings_rounded,
                    title: _t('Admin Console', '管理后台'),
                    subtitle: _t(
                      'Manage users and admin permissions',
                      '管理用户和管理员权限',
                    ),
                    onTap: _openAdmin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinPage() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('Admin Verification', '管理员验证')),
        actions: [
          IconButton(
            tooltip: _t('Logout', '退出登录'),
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t(
                      'Enter the 4-digit admin PIN to continue.',
                      '请输入 4 位管理员密码继续。',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: _t('Admin PIN', '管理员密码'),
                      prefixIcon: const Icon(Icons.lock_rounded),
                    ),
                    onSubmitted: (_) => _verifyPin(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _verifyPin,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: Text(_t('Confirm', '确认')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_isAdmin) {
      return LedgerHome(
        db: widget.db,
        onToggleLocale: widget.onToggleLocale,
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
        isGuestMode: widget.isGuestMode,
        onExitGuestMode: widget.onExitGuestMode,
        themeStyle: widget.themeStyle,
        onThemeStyleChanged: widget.onThemeStyleChanged,
        themeBackgroundImagePath: widget.themeBackgroundImagePath,
        onThemeBackgroundImageChanged: widget.onThemeBackgroundImageChanged,
        themeBackgroundMist: widget.themeBackgroundMist,
        onThemeBackgroundMistChanged: widget.onThemeBackgroundMistChanged,
      );
    }
    return _pinVerified ? _buildAdminChoice() : _buildPinPage();
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import 'admin_feedback_section.dart';
import 'admin_overview_section.dart';
import 'admin_users_section.dart';

enum AdminSection { overview, permissions, blocked, feedback }

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback? onToggleLocale;

  const AdminDashboardPage({super.key, this.onToggleLocale});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection _section = AdminSection.overview;
  int _reloadSeed = 0;

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  void _refreshCurrentSection() {
    setState(() => _reloadSeed++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForSection(_section)),
        actions: [
          if (widget.onToggleLocale != null)
            IconButton(
              tooltip: _t('Switch Language', '切换语言'),
              onPressed: widget.onToggleLocale,
              icon: const Icon(Icons.translate_rounded),
            ),
          IconButton(
            tooltip: _t('Refresh', '刷新'),
            onPressed: _refreshCurrentSection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AdminSection>(
                segments: [
                  ButtonSegment<AdminSection>(
                    value: AdminSection.overview,
                    label: Text(_t('Dashboard', '总览')),
                    icon: const Icon(Icons.dashboard_rounded),
                  ),
                  ButtonSegment<AdminSection>(
                    value: AdminSection.permissions,
                    label: Text(_t('Permissions', '用户权限')),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                  ),
                  ButtonSegment<AdminSection>(
                    value: AdminSection.blocked,
                    label: Text(_t('Blocked Users', '用户封禁')),
                    icon: const Icon(Icons.block_rounded),
                  ),
                  ButtonSegment<AdminSection>(
                    value: AdminSection.feedback,
                    label: Text(_t('Feedback', '用户反馈')),
                    icon: const Icon(Icons.feedback_rounded),
                  ),
                ],
                selected: <AdminSection>{_section},
                showSelectedIcon: false,
                onSelectionChanged: (value) {
                  setState(() => _section = value.first);
                },
              ),
            ),
          ),
          Expanded(child: _buildSectionBody()),
        ],
      ),
    );
  }

  Widget _buildSectionBody() {
    switch (_section) {
      case AdminSection.overview:
        return AdminOverviewSection(
          key: ValueKey<String>('overview-$_reloadSeed'),
        );
      case AdminSection.permissions:
        return AdminUsersSection(
          key: ValueKey<String>('permissions-$_reloadSeed'),
          blockedMode: false,
        );
      case AdminSection.blocked:
        return AdminUsersSection(
          key: ValueKey<String>('blocked-$_reloadSeed'),
          blockedMode: true,
        );
      case AdminSection.feedback:
        return AdminFeedbackSection(
          key: ValueKey<String>('feedback-$_reloadSeed'),
        );
    }
  }

  String _titleForSection(AdminSection section) {
    switch (section) {
      case AdminSection.overview:
        return _t('Admin Dashboard', '管理员后台');
      case AdminSection.permissions:
        return _t('User Permissions', '用户权限');
      case AdminSection.blocked:
        return _t('Blocked Users', '用户封禁');
      case AdminSection.feedback:
        return _t('User Feedback', '用户反馈');
    }
  }
}

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';

class LedgerSideMenu extends StatelessWidget {
  final WidgetBuilder statsPageBuilder;
  final VoidCallback? onOpenStats;
  final VoidCallback onSwitchAccount;
  final VoidCallback onManageAccounts;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onOpenRecurring;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenExternalImport;
  final VoidCallback onOpenSettings;
  final VoidCallback? onReplayTutorial;
  final VoidCallback onToggleTheme;
  final VoidCallback? onLogout;
  final bool isDarkMode;

  const LedgerSideMenu({
    super.key,
    required this.statsPageBuilder,
    this.onOpenStats,
    required this.onSwitchAccount,
    required this.onManageAccounts,
    required this.onOpenHistory,
    required this.onOpenAnalysis,
    required this.onOpenRecurring,
    required this.onOpenCategories,
    required this.onOpenExternalImport,
    required this.onOpenSettings,
    this.onReplayTutorial,
    required this.onToggleTheme,
    this.onLogout,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget groupTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget tile({
      required IconData icon,
      required String title,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 22, color: cs.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    Widget card({required List<Widget> children}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Material(
          color: cs.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 96,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      groupTitle(tr(context, en: 'Accounts', zh: '账户')),
                      card(
                        children: [
                          tile(
                            icon: Icons.swap_horiz_rounded,
                            title: tr(
                              context,
                              en: 'Switch Account',
                              zh: '切换账户',
                            ),
                            onTap: onSwitchAccount,
                          ),
                          tile(
                            icon: Icons.account_balance_wallet_rounded,
                            title: tr(
                              context,
                              en: 'Manage Accounts',
                              zh: '账户管理',
                            ),
                            onTap: onManageAccounts,
                          ),
                        ],
                      ),
                      groupTitle(tr(context, en: 'Navigate', zh: '导航')),
                      card(
                        children: [
                          tile(
                            icon: Icons.analytics_rounded,
                            title: tr(context, en: 'Stats', zh: '统计'),
                            onTap: () {
                              if (onOpenStats != null) {
                                onOpenStats!.call();
                                return;
                              }
                              Navigator.of(context).maybePop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: statsPageBuilder),
                              );
                            },
                          ),
                          tile(
                            icon: Icons.calendar_month_rounded,
                            title: tr(context, en: 'History', zh: '历史'),
                            onTap: onOpenHistory,
                          ),
                          tile(
                            icon: Icons.insights_rounded,
                            title: tr(context, en: 'Analysis', zh: '分析'),
                            onTap: onOpenAnalysis,
                          ),
                          tile(
                            icon: Icons.repeat_rounded,
                            title: tr(context, en: 'Recurring', zh: '周期交易'),
                            onTap: onOpenRecurring,
                          ),
                          tile(
                            icon: Icons.category_outlined,
                            title: tr(context, en: 'Categories', zh: '分类管理'),
                            onTap: onOpenCategories,
                          ),
                          tile(
                            icon: Icons.upload_file_rounded,
                            title: tr(
                              context,
                              en: 'Import External Bills',
                              zh: '导入外部账单',
                            ),
                            onTap: onOpenExternalImport,
                          ),
                        ],
                      ),
                      groupTitle(tr(context, en: 'Preferences', zh: '偏好')),
                      card(
                        children: [
                          if (onReplayTutorial != null)
                            tile(
                              icon: Icons.school_rounded,
                              title: tr(
                                context,
                                en: 'Replay Tutorial',
                                zh: '重新播放新手教程',
                              ),
                              onTap: onReplayTutorial!,
                            ),
                          tile(
                            icon: Icons.settings_rounded,
                            title: tr(context, en: 'Settings', zh: '设置'),
                            onTap: onOpenSettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggleTheme,
                      icon: Icon(
                        isDarkMode
                            ? Icons.wb_sunny_rounded
                            : Icons.dark_mode_rounded,
                      ),
                      label: Text(tr(context, en: 'Theme', zh: '主题')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(tr(context, en: 'Sign Out', zh: '登出')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

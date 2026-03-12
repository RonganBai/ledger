import 'package:flutter/material.dart';

import '../../../app/app_version.dart';
import 'ledger_side_menu_texts.dart';

class LedgerSideMenu extends StatelessWidget {
  final WidgetBuilder statsPageBuilder;
  final VoidCallback? onOpenStats;
  final VoidCallback onOpenAccountManagement;
  final VoidCallback onSwitchAccount;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAnalysis;
  final VoidCallback onOpenRecurring;
  final VoidCallback onOpenCategories;
  final VoidCallback onOpenExternalImport;
  final VoidCallback onOpenSettings;
  final VoidCallback? onReplayTutorial;
  final VoidCallback onToggleTheme;
  final VoidCallback? onBackToAdmin;
  final VoidCallback? onLogout;
  final bool isDarkMode;

  const LedgerSideMenu({
    super.key,
    required this.statsPageBuilder,
    this.onOpenStats,
    required this.onOpenAccountManagement,
    required this.onSwitchAccount,
    required this.onOpenHistory,
    required this.onOpenAnalysis,
    required this.onOpenRecurring,
    required this.onOpenCategories,
    required this.onOpenExternalImport,
    required this.onOpenSettings,
    this.onReplayTutorial,
    required this.onToggleTheme,
    this.onBackToAdmin,
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
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 4),
                        child: ValueListenableBuilder<String>(
                          valueListenable: appVersionText,
                          builder: (context, version, _) => Text(
                            'Current Version: $version',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                      groupTitle(lsmt(context, 'Accounts')),
                      card(
                        children: [
                          tile(
                            icon: Icons.person_outline_rounded,
                            title: lsmt(context, 'Account Management'),
                            onTap: onOpenAccountManagement,
                          ),
                          tile(
                            icon: Icons.swap_horiz_rounded,
                            title: lsmt(context, 'Switch Account'),
                            onTap: onSwitchAccount,
                          ),
                        ],
                      ),
                      groupTitle(lsmt(context, 'Navigate')),
                      card(
                        children: [
                          tile(
                            icon: Icons.analytics_rounded,
                            title: lsmt(context, 'Stats'),
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
                            title: lsmt(context, 'History'),
                            onTap: onOpenHistory,
                          ),
                          tile(
                            icon: Icons.insights_rounded,
                            title: lsmt(context, 'Analysis'),
                            onTap: onOpenAnalysis,
                          ),
                          tile(
                            icon: Icons.repeat_rounded,
                            title: lsmt(context, 'Recurring'),
                            onTap: onOpenRecurring,
                          ),
                          tile(
                            icon: Icons.category_outlined,
                            title: lsmt(context, 'Categories'),
                            onTap: onOpenCategories,
                          ),
                          tile(
                            icon: Icons.upload_file_rounded,
                            title: lsmt(context, 'Import External Bills'),
                            onTap: onOpenExternalImport,
                          ),
                        ],
                      ),
                      groupTitle(lsmt(context, 'Preferences')),
                      card(
                        children: [
                          if (onReplayTutorial != null)
                            tile(
                              icon: Icons.school_rounded,
                              title: lsmt(context, 'Replay Tutorial'),
                              onTap: onReplayTutorial!,
                            ),
                          tile(
                            icon: Icons.settings_rounded,
                            title: lsmt(context, 'Settings'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (onBackToAdmin != null) ...[
                          FilledButton.icon(
                            onPressed: onBackToAdmin,
                            icon: const Icon(
                              Icons.admin_panel_settings_rounded,
                            ),
                            label: Text(lsmt(context, 'Back to Admin')),
                          ),
                          const SizedBox(height: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: onToggleTheme,
                          icon: Icon(
                            isDarkMode
                                ? Icons.wb_sunny_rounded
                                : Icons.dark_mode_rounded,
                          ),
                          label: Text(lsmt(context, 'Theme')),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout_rounded),
                          label: Text(lsmt(context, 'Sign Out')),
                        ),
                      ],
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

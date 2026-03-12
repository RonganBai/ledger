import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_service.dart';

String humanizeAdminError(BuildContext context, Object error) {
  final raw = error.toString();
  String t(String en, String zh) => tr(context, en: en, zh: zh);
  if (raw.contains('cannot_revoke_self')) {
    return t(
      'The current admin account cannot demote itself.',
      '当前管理员账号不能降级自己。',
    );
  }
  if (raw.contains('cannot_revoke_last_admin')) {
    return t(
      'The last active admin cannot be removed.',
      '系统最后一个管理员不能被移除。',
    );
  }
  if (raw.contains('cannot_disable_self')) {
    return t(
      'The current admin account cannot disable itself.',
      '当前管理员账号不能禁用自己。',
    );
  }
  if (raw.contains('cannot_disable_last_admin')) {
    return t(
      'The last active admin cannot be disabled.',
      '系统最后一个管理员不能被禁用。',
    );
  }
  if (raw.contains('forbidden')) {
    return t(
      'Only active admins can use this page.',
      '只有有效管理员可以使用此页面。',
    );
  }
  if (raw.contains('user_not_found')) {
    return t('The target user was not found.', '目标用户不存在。');
  }
  return raw;
}

String formatAdminTime(DateTime? value) {
  if (value == null) return '-';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
}

class AdminUserCard extends StatelessWidget {
  final AdminUserSummary user;
  final String Function(String en, String zh) t;
  final bool saving;
  final VoidCallback onTap;
  final VoidCallback? onToggleRole;
  final VoidCallback? onToggleDisabled;

  const AdminUserCard({
    super.key,
    required this.user,
    required this.t,
    required this.saving,
    required this.onTap,
    required this.onToggleRole,
    required this.onToggleDisabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roleBg = user.isAdmin
        ? cs.primaryContainer
        : cs.surfaceContainerHighest;
    final roleFg = user.isAdmin ? cs.onPrimaryContainer : cs.onSurface;
    final statusBg = user.isDisabled
        ? cs.errorContainer
        : cs.secondaryContainer;
    final statusFg = user.isDisabled
        ? cs.onErrorContainer
        : cs.onSecondaryContainer;
    final displayName = user.displayName.trim();
    final email = user.email.trim();
    final showEmailSubtitle =
        email.isNotEmpty && displayName.toLowerCase() != email.toLowerCase();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (showEmailSubtitle) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (user.isCurrentUser)
                    Chip(label: Text(t('Current Admin', '当前管理员'))),
                  Chip(
                    backgroundColor: roleBg,
                    label: Text(
                      user.isAdmin ? t('Admin', '管理员') : t('User', '普通用户'),
                      style: TextStyle(
                        color: roleFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    backgroundColor: statusBg,
                    label: Text(
                      user.isDisabled ? t('Disabled', '已禁用') : t('Enabled', '正常'),
                      style: TextStyle(
                        color: statusFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${t('Pending Feedback', '待处理反馈')}: ${user.unresolvedFeedbackCount}',
              ),
              if (user.latestFeedbackAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${t('Latest Feedback', '最近反馈')}: ${formatAdminTime(user.latestFeedbackAt)}',
                ),
              ],
              const SizedBox(height: 4),
              Text('${t('User ID', '用户 ID')}: ${user.userId}'),
              const SizedBox(height: 4),
              Text('${t('Created', '注册时间')}: ${formatAdminTime(user.createdAt)}'),
              if ((user.disabledReason ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${t('Disable Reason', '禁用原因')}: ${user.disabledReason}'),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: FilledButton(
                      onPressed: saving ? null : onToggleRole,
                      style: user.isAdmin
                          ? FilledButton.styleFrom(
                              backgroundColor: cs.errorContainer,
                              foregroundColor: cs.onErrorContainer,
                            )
                          : null,
                      child: Text(
                        user.isCurrentUser && user.isAdmin
                            ? t('Current Admin', '当前管理员')
                            : user.isAdmin
                            ? t('Demote to User', '降级为普通用户')
                            : t('Promote to Admin', '升级为管理员'),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: OutlinedButton(
                      onPressed: saving ? null : onToggleDisabled,
                      child: Text(
                        user.isCurrentUser
                            ? t('Current Account', '当前账号')
                            : user.isDisabled
                            ? t('Restore User', '恢复用户')
                            : t('Disable User', '禁用用户'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

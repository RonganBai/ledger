import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_service.dart';

class UserAccessBlockedException implements Exception {
  final String message;

  const UserAccessBlockedException(this.message);

  @override
  String toString() => message;
}

class UserAccessService {
  static String? _pendingBlockedNoticeMessage;

  final SupabaseClient _client;
  final AdminService _adminService;

  UserAccessService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client,
      _adminService = AdminService(client: client);

  Future<CurrentUserAdminState?> getCurrentUserState() {
    return _adminService.getCurrentUserAdminState();
  }

  static String? consumePendingBlockedNotice() {
    final message = _pendingBlockedNoticeMessage;
    _pendingBlockedNoticeMessage = null;
    return message;
  }

  Future<void> ensureCurrentUserEnabled({
    bool signOutIfDisabled = false,
  }) async {
    final state = await getCurrentUserState();
    if (state == null || !state.isDisabled) return;

    final blockedMessage =
        state.disabledReason?.trim().isNotEmpty == true
        ? 'This account has been disabled. Reason: ${state.disabledReason}'
        : 'This account has been disabled by an administrator.';

    if (signOutIfDisabled) {
      _pendingBlockedNoticeMessage = blockedMessage;
      await _client.auth.signOut();
    }

    throw UserAccessBlockedException(blockedMessage);
  }
}

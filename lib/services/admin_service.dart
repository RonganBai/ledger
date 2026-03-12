import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTrendPoint {
  final String label;
  final int count;

  const AdminTrendPoint({required this.label, required this.count});

  factory AdminTrendPoint.fromJson(Map<String, dynamic> json) {
    return AdminTrendPoint(
      label: _readString(json, 'label'),
      count: _readInt(json, 'count'),
    );
  }
}

class AdminDashboardMetrics {
  final int pendingFeedbackCount;
  final int suspiciousUserCount;
  final int totalRequestCount;
  final int requestDelta;
  final int totalUserCount;
  final int disabledUserCount;
  final int adminUserCount;
  final List<AdminTrendPoint> trend;

  const AdminDashboardMetrics({
    required this.pendingFeedbackCount,
    required this.suspiciousUserCount,
    required this.totalRequestCount,
    required this.requestDelta,
    required this.totalUserCount,
    required this.disabledUserCount,
    required this.adminUserCount,
    required this.trend,
  });

  factory AdminDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return AdminDashboardMetrics(
      pendingFeedbackCount: _readInt(
        json,
        'pending_feedback_count',
        'pendingFeedbackCount',
      ),
      suspiciousUserCount: _readInt(
        json,
        'suspicious_user_count',
        'suspiciousUserCount',
      ),
      totalRequestCount: _readInt(
        json,
        'total_request_count',
        'totalRequestCount',
      ),
      requestDelta: _readInt(json, 'request_delta', 'requestDelta'),
      totalUserCount: _readInt(json, 'total_user_count', 'totalUserCount'),
      disabledUserCount: _readInt(
        json,
        'disabled_user_count',
        'disabledUserCount',
      ),
      adminUserCount: _readInt(json, 'admin_user_count', 'adminUserCount'),
      trend: _readList(json, 'trend')
          .whereType<Map>()
          .map((row) => AdminTrendPoint.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false),
    );
  }
}

class AdminUserSummary {
  final String userId;
  final String email;
  final String displayName;
  final String maskedEmail;
  final bool isAdmin;
  final bool isDisabled;
  final String? disabledReason;
  final int unresolvedFeedbackCount;
  final DateTime? latestFeedbackAt;
  final bool isCurrentUser;
  final DateTime? createdAt;

  const AdminUserSummary({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.maskedEmail,
    required this.isAdmin,
    required this.isDisabled,
    required this.disabledReason,
    required this.unresolvedFeedbackCount,
    required this.latestFeedbackAt,
    required this.isCurrentUser,
    required this.createdAt,
  });

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) {
    return AdminUserSummary(
      userId: _readString(json, 'user_id', 'userId'),
      email: _readString(json, 'email'),
      displayName: _readString(json, 'display_name', 'displayName'),
      maskedEmail: _readString(json, 'masked_email', 'maskedEmail'),
      isAdmin: _readBool(json, 'is_admin', 'isAdmin'),
      isDisabled: _readBool(json, 'is_disabled', 'isDisabled'),
      disabledReason: _readNullableString(
        json,
        'disabled_reason',
        'disabledReason',
      ),
      unresolvedFeedbackCount: _readInt(
        json,
        'unresolved_feedback_count',
        'unresolvedFeedbackCount',
      ),
      latestFeedbackAt: _readDateTime(
        json,
        'latest_feedback_at',
        'latestFeedbackAt',
      ),
      isCurrentUser: _readBool(json, 'is_current_user', 'isCurrentUser'),
      createdAt: _readDateTime(json, 'created_at', 'createdAt'),
    );
  }
}

class AdminFeedbackItem {
  final String id;
  final String userId;
  final String status;
  final String content;
  final String displayNameSnapshot;
  final String maskedEmailSnapshot;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const AdminFeedbackItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.content,
    required this.displayNameSnapshot,
    required this.maskedEmailSnapshot,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  bool get isResolved => status == 'resolved';

  factory AdminFeedbackItem.fromJson(Map<String, dynamic> json) {
    return AdminFeedbackItem(
      id: _readString(json, 'id'),
      userId: _readString(json, 'user_id', 'userId'),
      status: _readString(json, 'status'),
      content: _readString(json, 'content'),
      displayNameSnapshot: _readString(
        json,
        'display_name_snapshot',
        'displayNameSnapshot',
      ),
      maskedEmailSnapshot: _readString(
        json,
        'masked_email_snapshot',
        'maskedEmailSnapshot',
      ),
      createdAt: _readDateTime(json, 'created_at', 'createdAt'),
      resolvedAt: _readDateTime(json, 'resolved_at', 'resolvedAt'),
      resolvedBy: _readNullableString(json, 'resolved_by', 'resolvedBy'),
    );
  }
}

class AdminFeedbackListItem {
  final String feedbackId;
  final String userId;
  final String userDisplayName;
  final String userEmail;
  final String userMaskedEmail;
  final String status;
  final String content;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const AdminFeedbackListItem({
    required this.feedbackId,
    required this.userId,
    required this.userDisplayName,
    required this.userEmail,
    required this.userMaskedEmail,
    required this.status,
    required this.content,
    required this.createdAt,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  bool get isResolved => status == 'resolved';

  factory AdminFeedbackListItem.fromJson(Map<String, dynamic> json) {
    return AdminFeedbackListItem(
      feedbackId: _readString(json, 'feedback_id', 'feedbackId'),
      userId: _readString(json, 'user_id', 'userId'),
      userDisplayName: _readString(
        json,
        'user_display_name',
        'userDisplayName',
      ),
      userEmail: _readString(json, 'user_email', 'userEmail'),
      userMaskedEmail: _readString(
        json,
        'user_masked_email',
        'userMaskedEmail',
      ),
      status: _readString(json, 'status'),
      content: _readString(json, 'content'),
      createdAt: _readDateTime(json, 'created_at', 'createdAt'),
      resolvedAt: _readDateTime(json, 'resolved_at', 'resolvedAt'),
      resolvedBy: _readNullableString(json, 'resolved_by', 'resolvedBy'),
    );
  }
}

class AdminAuditLogItem {
  final String id;
  final String actorUserId;
  final String targetUserId;
  final String actorDisplayName;
  final String targetDisplayName;
  final String action;
  final Map<String, dynamic> detail;
  final DateTime? createdAt;

  const AdminAuditLogItem({
    required this.id,
    required this.actorUserId,
    required this.targetUserId,
    required this.actorDisplayName,
    required this.targetDisplayName,
    required this.action,
    required this.detail,
    required this.createdAt,
  });

  factory AdminAuditLogItem.fromJson(Map<String, dynamic> json) {
    return AdminAuditLogItem(
      id: _readString(json, 'id'),
      actorUserId: _readString(json, 'actor_user_id', 'actorUserId'),
      targetUserId: _readString(json, 'target_user_id', 'targetUserId'),
      actorDisplayName: _readString(
        json,
        'actor_display_name',
        'actorDisplayName',
      ),
      targetDisplayName: _readString(
        json,
        'target_display_name',
        'targetDisplayName',
      ),
      action: _readString(json, 'action'),
      detail: _readMap(json, 'detail'),
      createdAt: _readDateTime(json, 'created_at', 'createdAt'),
    );
  }
}

class AdminUserDetail {
  final AdminUserSummary user;
  final int todayFeedbackCount;
  final int recentFeedbackCount;
  final int pendingFeedbackCount;
  final List<AdminFeedbackItem> feedbacks;
  final List<AdminAuditLogItem> auditLogs;

  const AdminUserDetail({
    required this.user,
    required this.todayFeedbackCount,
    required this.recentFeedbackCount,
    required this.pendingFeedbackCount,
    required this.feedbacks,
    required this.auditLogs,
  });

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) {
    final userMap = _readMap(json, 'user');
    final stats = _readMap(json, 'stats');
    final feedbacks = _readList(json, 'feedbacks')
        .whereType<Map>()
        .map((row) => AdminFeedbackItem.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final auditLogs = _readList(json, 'audit_logs', 'auditLogs')
        .whereType<Map>()
        .map((row) => AdminAuditLogItem.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return AdminUserDetail(
      user: AdminUserSummary.fromJson(userMap),
      todayFeedbackCount: _readInt(
        stats,
        'today_feedback_count',
        'todayFeedbackCount',
      ),
      recentFeedbackCount: _readInt(
        stats,
        'recent_feedback_count',
        'recentFeedbackCount',
      ),
      pendingFeedbackCount: _readInt(
        stats,
        'pending_feedback_count',
        'pendingFeedbackCount',
      ),
      feedbacks: feedbacks,
      auditLogs: auditLogs,
    );
  }
}

class AdminUserPage {
  final List<AdminUserSummary> users;
  final bool hasMore;
  final DateTime? nextCursor;

  const AdminUserPage({
    required this.users,
    required this.hasMore,
    required this.nextCursor,
  });
}

class AdminFeedbackPage {
  final List<AdminFeedbackListItem> items;
  final bool hasMore;
  final DateTime? nextCursor;

  const AdminFeedbackPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
  });
}

class CurrentUserAdminState {
  final String userId;
  final String email;
  final bool isAdmin;
  final bool isDisabled;
  final String? disabledReason;

  const CurrentUserAdminState({
    required this.userId,
    required this.email,
    required this.isAdmin,
    required this.isDisabled,
    required this.disabledReason,
  });

  factory CurrentUserAdminState.fromJson(Map<String, dynamic> json) {
    return CurrentUserAdminState(
      userId: _readString(json, 'user_id', 'userId'),
      email: _readString(json, 'email'),
      isAdmin: _readBool(json, 'is_admin', 'isAdmin'),
      isDisabled: _readBool(json, 'is_disabled', 'isDisabled'),
      disabledReason: _readNullableString(
        json,
        'disabled_reason',
        'disabledReason',
      ),
    );
  }
}

class AdminService {
  static const String _table = 'ledger_admins';
  static const String _adminPin = '3810';
  final SupabaseClient _client;

  AdminService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<bool> isCurrentUserAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final row = await _client
        .from(_table)
        .select('user_id,is_active')
        .eq('user_id', user.id)
        .eq('is_active', true)
        .maybeSingle();
    return row != null;
  }

  bool verifyPin(String pin) => pin.trim() == _adminPin;

  Future<CurrentUserAdminState?> getCurrentUserAdminState() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client.rpc('get_current_user_admin_state');
    if (data == null) return null;
    if (data is! Map) {
      throw StateError('Unexpected current user state response');
    }
    return CurrentUserAdminState.fromJson(Map<String, dynamic>.from(data));
  }

  Future<AdminDashboardMetrics> getDashboardMetrics() async {
    final data = await _client.rpc('admin_dashboard_metrics');
    if (data is! Map) {
      throw StateError('Unexpected dashboard metrics response');
    }
    return AdminDashboardMetrics.fromJson(Map<String, dynamic>.from(data));
  }

  Future<AdminUserPage> listUsers({
    int pageSize = 20,
    DateTime? cursor,
    String query = '',
    String roleFilter = 'all',
    String disabledFilter = 'all',
    String feedbackFilter = 'all',
  }) async {
    final data = await _client.rpc(
      'admin_list_users',
      params: <String, dynamic>{
        'page_size': pageSize,
        'cursor': cursor?.toUtc().toIso8601String(),
        'query': query.trim().isEmpty ? null : query.trim(),
        'role_filter': roleFilter,
        'disabled_filter': disabledFilter,
        'feedback_filter': feedbackFilter,
      },
    );
    if (data is! List) {
      throw StateError('Unexpected admin list response');
    }
    final users = data
        .whereType<Map>()
        .map((row) => AdminUserSummary.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return AdminUserPage(
      users: users,
      hasMore: users.length >= pageSize,
      nextCursor: users.isEmpty ? null : users.last.createdAt,
    );
  }

  Future<AdminFeedbackPage> listFeedbacks({
    int pageSize = 20,
    DateTime? cursor,
    String query = '',
    String statusFilter = 'all',
  }) async {
    final data = await _client.rpc(
      'admin_list_feedbacks',
      params: <String, dynamic>{
        'page_size': pageSize,
        'cursor': cursor?.toUtc().toIso8601String(),
        'query': query.trim().isEmpty ? null : query.trim(),
        'status_filter': statusFilter,
      },
    );
    if (data is! List) {
      throw StateError('Unexpected feedback list response');
    }
    final items = data
        .whereType<Map>()
        .map(
          (row) =>
              AdminFeedbackListItem.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    return AdminFeedbackPage(
      items: items,
      hasMore: items.length >= pageSize,
      nextCursor: items.isEmpty ? null : items.last.createdAt,
    );
  }

  Future<AdminUserDetail> getUserDetail(String userId) async {
    final data = await _client.rpc(
      'admin_get_user_detail',
      params: <String, dynamic>{'p_target_user_id': userId},
    );
    if (data is! Map) {
      throw StateError('Unexpected user detail response');
    }
    return AdminUserDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> grantAdmin(String userId) async {
    await _client.rpc(
      'admin_grant_role',
      params: <String, dynamic>{'target_user_id': userId},
    );
  }

  Future<void> revokeAdmin(String userId) async {
    await _client.rpc(
      'admin_revoke_role',
      params: <String, dynamic>{'target_user_id': userId},
    );
  }

  Future<void> disableUser(String userId, {String? reason}) async {
    await _client.rpc(
      'admin_disable_user',
      params: <String, dynamic>{
        'target_user_id': userId,
        'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      },
    );
  }

  Future<void> restoreUser(String userId) async {
    await _client.rpc(
      'admin_restore_user',
      params: <String, dynamic>{'target_user_id': userId},
    );
  }

  Future<void> markFeedbackResolved(String feedbackId) async {
    await _client.rpc(
      'admin_mark_feedback_resolved',
      params: <String, dynamic>{'feedback_id': feedbackId},
    );
  }

  Future<List<AdminAuditLogItem>> listAuditLogs({
    String? targetUserId,
    int pageSize = 20,
    DateTime? cursor,
  }) async {
    final data = await _client.rpc(
      'admin_list_audit_logs',
      params: <String, dynamic>{
        'p_target_user_id': targetUserId,
        'page_size': pageSize,
        'cursor': cursor?.toUtc().toIso8601String(),
      },
    );
    if (data is! List) {
      throw StateError('Unexpected audit log response');
    }
    return data
        .whereType<Map>()
        .map((row) => AdminAuditLogItem.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

String _readString(Map<String, dynamic> json, String key, [String? altKey]) {
  return (json[key] ?? (altKey == null ? null : json[altKey]) ?? '').toString();
}

String? _readNullableString(
  Map<String, dynamic> json,
  String key, [
  String? altKey,
]) {
  final value = json[key] ?? (altKey == null ? null : json[altKey]);
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

bool _readBool(Map<String, dynamic> json, String key, [String? altKey]) {
  final value = json[key] ?? (altKey == null ? null : json[altKey]);
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1';
}

int _readInt(Map<String, dynamic> json, String key, [String? altKey]) {
  final value = json[key] ?? (altKey == null ? null : json[altKey]);
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime? _readDateTime(
  Map<String, dynamic> json,
  String key, [
  String? altKey,
]) {
  final value = json[key] ?? (altKey == null ? null : json[altKey]);
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> _readMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _readList(Map<String, dynamic> json, String key, [String? altKey]) {
  final value = json[key] ?? (altKey == null ? null : json[altKey]);
  if (value is List) return value;
  return const <dynamic>[];
}

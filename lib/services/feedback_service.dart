import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/settings/account_profile_service.dart';
import 'user_access_service.dart';
import 'user_identity_formatter.dart';

class FeedbackQuota {
  final int usedCount;
  final int maxCount;

  const FeedbackQuota({required this.usedCount, this.maxCount = 5});

  int get remainingCount => maxCount - usedCount < 0 ? 0 : maxCount - usedCount;
}

class FeedbackSubmissionResult {
  final int remainingCount;

  const FeedbackSubmissionResult({required this.remainingCount});
}

class FeedbackService {
  static const String _table = 'ledger_feedback_submissions';
  final SupabaseClient _client;
  final AccountProfileService _profileService;
  final UserAccessService _accessService;

  FeedbackService({
    SupabaseClient? client,
    AccountProfileService? profileService,
    UserAccessService? accessService,
  }) : _client = client ?? Supabase.instance.client,
       _profileService = profileService ?? AccountProfileService(),
       _accessService = accessService ?? UserAccessService(client: client);

  Future<FeedbackQuota> loadQuota() async {
    final session = _requireSession();
    final user = session.user;
    await _accessService.ensureCurrentUserEnabled(signOutIfDisabled: true);

    final quotaDate = _quotaDateUtc8(DateTime.now().toUtc());
    final rows = await _client
        .from(_table)
        .select('id')
        .eq('user_id', user.id)
        .eq('quota_date_utc8', quotaDate);
    return FeedbackQuota(usedCount: rows.length);
  }

  Future<FeedbackSubmissionResult> submit({required String content}) async {
    final session = _requireSession();
    final user = session.user;
    await _accessService.ensureCurrentUserEnabled(signOutIfDisabled: true);

    final profile = await _profileService.loadCurrentProfile();
    final payload = <String, dynamic>{
      'content': content.trim(),
      'displayName': resolveDisplayName(
        displayName: profile?.displayName,
        email: user.email,
      ),
      'maskedEmail': maskEmail(user.email ?? ''),
    };

    // FunctionsClient may retain a stale auth header across app lifecycle changes.
    // Refresh it from the current session right before invoking the edge function.
    _client.functions.setAuth(session.accessToken);
    final response = await _client.functions.invoke(
      'submit-feedback',
      body: payload,
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected feedback response');
    }
    final remaining = (data['remainingCount'] as num?)?.toInt();
    if (remaining == null) {
      throw StateError('Missing remaining count');
    }
    return FeedbackSubmissionResult(remainingCount: remaining);
  }

  Session _requireSession() {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('No active session');
    }
    return session;
  }

  String _quotaDateUtc8(DateTime utcNow) {
    final utc8 = utcNow.add(const Duration(hours: 8));
    final month = utc8.month.toString().padLeft(2, '0');
    final day = utc8.day.toString().padLeft(2, '0');
    return '${utc8.year}-$month-$day';
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/tr.dart';
import '../../services/feedback_service.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _contentCtrl = TextEditingController();
  final FeedbackService _service = FeedbackService();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  FeedbackQuota _quota = const FeedbackQuota(usedCount: 0);

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quota = await _service.loadQuota();
      if (!mounted) return;
      setState(() => _quota = quota);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeFeedbackError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      setState(() => _error = _t('Please enter feedback content.', '请输入反馈内容。'));
      return;
    }
    if (_quota.remainingCount <= 0) {
      setState(
        () => _error = _t('Today\'s quota has been used up.', '今天的反馈次数已用完。'),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await _service.submit(content: content);
      if (!mounted) return;
      _contentCtrl.clear();
      setState(() {
        _quota = FeedbackQuota(
          usedCount: _quota.maxCount - result.remainingCount,
          maxCount: _quota.maxCount,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Feedback sent successfully. Remaining today: ${result.remainingCount}',
              '反馈发送成功，今日剩余 ${result.remainingCount} 次。',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _humanizeFeedbackError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _humanizeFeedbackError(Object error) {
    if (error is StateError) {
      return _t(
        'Your login session has expired. Please sign in again and retry.',
        '当前登录状态已失效，请重新登录后再试。',
      );
    }
    if (error is FunctionException) {
      if (error.status == 401) {
        return _t(
          'Feedback authorization failed. Please sign out and sign in again.',
          '反馈鉴权失败，请退出后重新登录再试。',
        );
      }
      if (error.status == 429) {
        return _t(
          'Today\'s feedback quota has been used up.',
          '今天的反馈次数已用完。',
        );
      }
    }
    return '$error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('User Feedback', '用户反馈'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        _t(
                          'Daily quota: ${_quota.remainingCount}/${_quota.maxCount} remaining (refresh at UTC+8)',
                          '每日反馈剩余 ${_quota.remainingCount}/${_quota.maxCount} 次（UTC+8 刷新）',
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _contentCtrl,
                      enabled: !_submitting,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        alignLabelWithHint: true,
                        labelText: _t('Feedback Content', '反馈内容'),
                        hintText: _t(
                          'Please describe the problem or suggestion in detail.',
                          '请详细描述问题或建议。',
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting
                            ? _t('Sending...', '发送中...')
                            : _t('Send Feedback', '发送反馈'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

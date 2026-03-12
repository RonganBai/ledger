import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_service.dart';
import 'admin_shared.dart';
import 'admin_user_detail_page.dart';

class AdminFeedbackSection extends StatefulWidget {
  const AdminFeedbackSection({super.key});

  @override
  State<AdminFeedbackSection> createState() => _AdminFeedbackSectionState();
}

class _AdminFeedbackSectionState extends State<AdminFeedbackSection> {
  static const int _pageSize = 20;

  final AdminService _service = AdminService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;
  bool _hasMore = true;
  DateTime? _cursor;
  String? _error;
  String _statusFilter = 'all';
  Timer? _searchDebounce;
  List<AdminFeedbackListItem> _items = const <AdminFeedbackListItem>[];

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_handleScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _cursor = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _service.listFeedbacks(
        pageSize: _pageSize,
        cursor: reset ? null : _cursor,
        query: _searchCtrl.text,
        statusFilter: _statusFilter,
      );
      if (!mounted) return;
      setState(() {
        _items = reset
            ? result.items
            : <AdminFeedbackListItem>[..._items, ...result.items];
        _cursor = result.nextCursor;
        _hasMore = result.hasMore && result.nextCursor != null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _handleScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.pixels >= position.maxScrollExtent - 280) {
      unawaited(_load(reset: false));
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 280),
      () => unawaited(_load(reset: true)),
    );
  }

  Future<void> _markResolved(AdminFeedbackListItem item) async {
    if (item.isResolved) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.markFeedbackResolved(item.feedbackId);
      await _load(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDetail(AdminFeedbackListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailPage(userId: item.userId),
      ),
    );
    if (!mounted) return;
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                enabled: !_saving,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  hintText: _t(
                    'Search by user, email or feedback content',
                    '按用户、邮箱或反馈内容搜索',
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {});
                  _onSearchChanged(value);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox.shrink(),
                    items: <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(_t('All Feedback', '全部反馈')),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text(_t('Pending', '未处理')),
                      ),
                      DropdownMenuItem(
                        value: 'resolved',
                        child: Text(_t('Resolved', '已处理')),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            setState(() => _statusFilter = value!);
                            unawaited(_load(reset: true));
                          },
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_t('No feedback found.', '暂无反馈记录。')),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _items.length + (_loadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final item = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openDetail(item),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.userDisplayName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          item.isResolved
                                              ? _t('Resolved', '已处理')
                                              : _t('Pending', '未处理'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.userDisplayName.toLowerCase() !=
                                      item.userEmail.toLowerCase()) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.userEmail,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(item.content),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_t('Submitted', '提交时间')}: ${formatAdminTime(item.createdAt)}',
                                  ),
                                  if (item.resolvedAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_t('Resolved At', '处理时间')}: ${formatAdminTime(item.resolvedAt)}',
                                    ),
                                  ],
                                  if (!item.isResolved) ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.tonal(
                                        onPressed: _saving
                                            ? null
                                            : () => _markResolved(item),
                                        child: Text(
                                          _t('Mark Resolved', '标记已处理'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';
import '../../../l10n/category_i18n.dart';

@immutable
class LedgerFilterState {
  final String keyword;
  final DateTimeRange? range;
  final int? categoryId;

  const LedgerFilterState({this.keyword = '', this.range, this.categoryId});

  bool get hasAny =>
      keyword.trim().isNotEmpty || range != null || categoryId != null;

  LedgerFilterState copyWith({
    String? keyword,
    DateTimeRange? range,
    int? categoryId,
    bool clearRange = false,
    bool clearCategory = false,
  }) {
    return LedgerFilterState(
      keyword: keyword ?? this.keyword,
      range: clearRange ? null : (range ?? this.range),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    );
  }
}

/// Search + filters card used on LedgerHome.
class LedgerSearchPanel extends StatefulWidget {
  final AppDatabase db;
  final LedgerFilterState value;
  final ValueChanged<LedgerFilterState> onChanged;
  final Key? panelKey;
  final Key? keywordFieldKey;
  final Key? resetButtonKey;
  final VoidCallback? onResetPressed;
  final VoidCallback? onExportPressed;

  const LedgerSearchPanel({
    super.key,
    required this.db,
    required this.value,
    required this.onChanged,
    this.panelKey,
    this.keywordFieldKey,
    this.resetButtonKey,
    this.onResetPressed,
    this.onExportPressed,
  });

  @override
  State<LedgerSearchPanel> createState() => _LedgerSearchPanelState();
}

class _LedgerSearchPanelState extends State<LedgerSearchPanel> {
  static const String _kSavedViews = 'ledger_saved_filter_views_v1';
  late final TextEditingController _keywordCtrl;
  late LedgerFilterState _state;
  List<_SavedFilterView> _savedViews = const <_SavedFilterView>[];

  @override
  void initState() {
    super.initState();
    _state = widget.value;
    _keywordCtrl = TextEditingController(text: _state.keyword);
    _keywordCtrl.addListener(() {
      final v = _keywordCtrl.text;
      if (v == _state.keyword) return;
      _emit(_state.copyWith(keyword: v));
    });
    unawaited(_loadSavedViews());
  }

  @override
  void didUpdateWidget(covariant LedgerSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent may reset filters; sync text controller.
    if (widget.value.keyword != _state.keyword) {
      _keywordCtrl.text = widget.value.keyword;
      _keywordCtrl.selection = TextSelection.collapsed(
        offset: _keywordCtrl.text.length,
      );
    }
    _state = widget.value;
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _emit(LedgerFilterState next) {
    setState(() => _state = next);
    widget.onChanged(next);
  }

  Future<void> _loadSavedViews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSavedViews) ?? const <String>[];
    final views = <_SavedFilterView>[];
    for (final item in raw) {
      try {
        views.add(
          _SavedFilterView.fromJson(jsonDecode(item) as Map<String, dynamic>),
        );
      } catch (_) {
        // ignore malformed row
      }
    }
    if (!mounted) return;
    setState(() => _savedViews = views);
  }

  Future<void> _saveSavedViews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _savedViews
        .map((e) => jsonEncode(e.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_kSavedViews, raw);
  }

  Future<void> _saveCurrentView() async {
    if (!_state.hasAny) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, en: 'Save Filter View', zh: '保存筛选视图')),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: tr(context, en: 'View Name', zh: '视图名称'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, en: 'Cancel', zh: '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(tr(context, en: 'Save', zh: '保存')),
          ),
        ],
      ),
    );
    if (!mounted || name == null || name.isEmpty) return;

    final next = List<_SavedFilterView>.from(_savedViews);
    next.removeWhere((e) => e.name == name);
    next.insert(0, _SavedFilterView(name: name, filter: _state));
    if (next.length > 12) {
      next.removeRange(12, next.length);
    }
    setState(() => _savedViews = next);
    await _saveSavedViews();
  }

  Future<void> _pickSavedView() async {
    if (_savedViews.isEmpty) return;
    final picked = await showModalBottomSheet<_SavedFilterView>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            itemCount: _savedViews.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = _savedViews[i];
              return ListTile(
                title: Text(v.name),
                subtitle: Text(
                  _savedViewSummary(v.filter),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: tr(context, en: 'Delete', zh: '删除'),
                  onPressed: () async {
                    final next = List<_SavedFilterView>.from(_savedViews)
                      ..removeAt(i);
                    if (!mounted) return;
                    setState(() => _savedViews = next);
                    await _saveSavedViews();
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                onTap: () => Navigator.of(context).pop(v),
              );
            },
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    _keywordCtrl.text = picked.filter.keyword;
    _emit(picked.filter);
  }

  String _savedViewSummary(LedgerFilterState f) {
    final parts = <String>[];
    if (f.keyword.trim().isNotEmpty) {
      parts.add('kw:${f.keyword.trim()}');
    }
    if (f.range != null) {
      parts.add(_fmtRangeLabel(context, f.range));
    }
    if (f.categoryId != null) {
      parts.add(tr(context, en: 'Category set', zh: '已选分类'));
    }
    return parts.join(' | ');
  }

  String _fmtRangeLabel(BuildContext context, DateTimeRange? r) {
    if (r == null) return tr(context, en: 'Date', zh: '日期');
    String two(int v) => v.toString().padLeft(2, '0');
    String fmt(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
    return '${fmt(r.start)} ~ ${fmt(r.end)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialStart =
        _state.range?.start ??
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7));
    final initialEnd =
        _state.range?.end ?? DateTime(now.year, now.month, now.day);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: tr(context, en: 'Select date range', zh: '选择日期范围'),
    );

    if (!mounted) return;
    if (range == null) return;
    _emit(_state.copyWith(range: range));
  }

  Future<void> _pickCategory() async {
    final db = widget.db;

    final picked = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 90),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            tr(context, en: 'Type', zh: '类型'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: Text(tr(context, en: 'Clear', zh: '清除')),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<List<Category>>(
                      stream:
                          (db.select(db.categories)
                                ..where((c) => c.isActive.equals(true))
                                ..orderBy([
                                  (c) => d.OrderingTerm(expression: c.name),
                                ]))
                              .watch(),
                      builder: (context, snap) {
                        final cats = snap.data ?? const <Category>[];
                        return ListView.separated(
                          controller: scrollCtrl,
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = cats[i];
                            final selected = c.id == _state.categoryId;
                            return ListTile(
                              title: Text(categoryLabel(context, c.name)),
                              trailing: selected
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              onTap: () => Navigator.pop(context, c.id),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, _state.categoryId),
                      child: Text(tr(context, en: 'Done', zh: '完成')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    _emit(_state.copyWith(categoryId: picked, clearCategory: picked == null));
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool emphasized,
    required bool expanded,
    required bool dense,
    required bool showChevron,
  }) {
    final border = Theme.of(context).dividerColor.withValues(alpha: 90);
    final scheme = Theme.of(context).colorScheme;

    final child = InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: dense ? 36 : 40,
        padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          color: emphasized
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : scheme.surface,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (showChevron) const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );

    return expanded ? child : IntrinsicWidth(child: child);
  }

  Widget _resetSquareButton({required bool enabled, Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 90);

    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(14),
      onTap: !enabled
          ? null
          : () {
              widget.onResetPressed?.call();
              _keywordCtrl.clear();
              _emit(const LedgerFilterState());
            },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          color: enabled
              ? scheme.surface
              : scheme.surface.withValues(alpha: 0.6),
        ),
        child: Icon(
          Icons.restart_alt_rounded,
          color: enabled
              ? scheme.onSurface
              : scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 64);

    return ConstrainedBox(
      key: widget.panelKey,
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: widget.keywordFieldKey,
              controller: _keywordCtrl,
              decoration: InputDecoration(
                isDense: true,
                hintText: tr(context, en: 'Search keyword', zh: '关键词搜索'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 36,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: _keywordCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr(context, en: 'Clear', zh: '清除'),
                        onPressed: () {
                          _keywordCtrl.clear();
                          _emit(_state.copyWith(keyword: ''));
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Category>>(
              stream:
                  (widget.db.select(widget.db.categories)
                        ..where((c) => c.isActive.equals(true))
                        ..orderBy([(c) => d.OrderingTerm(expression: c.name)]))
                      .watch(),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];

                return LayoutBuilder(
                  builder: (context, c) {
                    final dense = c.maxWidth < 420;
                    final gap = dense ? 6.0 : 10.0;
                    final resetW = dense ? 40.0 : 44.0;

                    String catText = tr(context, en: 'Type', zh: '类型');
                    if (_state.categoryId != null) {
                      final hit = cats
                          .where((e) => e.id == _state.categoryId)
                          .toList();
                      if (hit.isNotEmpty) {
                        catText = categoryLabel(context, hit.first.name);
                      } else {
                        catText = tr(context, en: 'Type', zh: '类型');
                      }
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _pillButton(
                            icon: Icons.calendar_month,
                            label: _fmtRangeLabel(context, _state.range),
                            emphasized: _state.range != null,
                            onTap: _pickRange,
                            expanded: true,
                            dense: dense,
                            showChevron: !dense,
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _pillButton(
                            icon: Icons.category_outlined,
                            label: catText,
                            emphasized: _state.categoryId != null,
                            onTap: _pickCategory,
                            expanded: true,
                            dense: dense,
                            showChevron: !dense,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: resetW,
                          height: dense ? 36 : 40,
                          child: _resetSquareButton(
                            enabled: _state.hasAny,
                            key: widget.resetButtonKey,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _smallAction(
                    icon: Icons.bookmark_add_outlined,
                    label: tr(context, en: 'Save View', zh: '保存视图'),
                    onPressed: _state.hasAny ? _saveCurrentView : null,
                  ),
                  _smallAction(
                    icon: Icons.collections_bookmark_outlined,
                    label: tr(context, en: 'Views', zh: '视图'),
                    onPressed: _savedViews.isEmpty ? null : _pickSavedView,
                  ),
                  if (widget.onExportPressed != null)
                    _smallAction(
                      icon: Icons.file_download_outlined,
                      label: tr(context, en: 'Export', zh: '导出'),
                      onPressed: widget.onExportPressed,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
    );
  }
}

class _SavedFilterView {
  final String name;
  final LedgerFilterState filter;

  const _SavedFilterView({required this.name, required this.filter});

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'keyword': filter.keyword,
    'range_start': filter.range?.start.toUtc().toIso8601String(),
    'range_end': filter.range?.end.toUtc().toIso8601String(),
    'category_id': filter.categoryId,
  };

  static _SavedFilterView fromJson(Map<String, dynamic> json) {
    final start = json['range_start']?.toString();
    final end = json['range_end']?.toString();
    DateTimeRange? range;
    if (start != null && end != null) {
      final s = DateTime.tryParse(start);
      final e = DateTime.tryParse(end);
      if (s != null && e != null) {
        range = DateTimeRange(start: s.toLocal(), end: e.toLocal());
      }
    }
    return _SavedFilterView(
      name: (json['name'] ?? '').toString(),
      filter: LedgerFilterState(
        keyword: (json['keyword'] ?? '').toString(),
        range: range,
        categoryId: (json['category_id'] as num?)?.toInt(),
      ),
    );
  }
}

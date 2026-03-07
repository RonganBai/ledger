import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;

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

  const LedgerSearchPanel({
    super.key,
    required this.db,
    required this.value,
    required this.onChanged,
    this.panelKey,
    this.keywordFieldKey,
    this.resetButtonKey,
    this.onResetPressed,
  });

  @override
  State<LedgerSearchPanel> createState() => _LedgerSearchPanelState();
}

class _LedgerSearchPanelState extends State<LedgerSearchPanel> {
  late final TextEditingController _keywordCtrl;
  late LedgerFilterState _state;

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
          ],
        ),
      ),
    );
  }
}

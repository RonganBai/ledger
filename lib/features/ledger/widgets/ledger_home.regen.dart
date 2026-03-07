import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as d;

import '../../data/db/app_database.dart';
import '../../l10n/tr.dart';
import '../../l10n/category_i18n.dart';
import '../../app/settings.dart';

import 'add_transaction_page.dart';
import 'models.dart';

import 'widgets/ledger_quick_actions.dart';

import '../reports/history_page.dart';
import '../reports/widgets/monthly_stats_sheet.dart';
import '../reports/report_service.dart';
import '../settings/settings_page.dart';
import '../settings/auto_backup_service.dart';
import '../settings/import_export_service.dart';

import 'widgets/balance_card.dart';
import 'widgets/day_header.dart';
import 'widgets/tx_tile.dart';
import 'widgets/category_manage_page.dart';

// New small widgets (split out from this file)
import 'widgets/ledger_drawer_shell.dart';
import 'widgets/ledger_side_menu.dart';
import 'widgets/tx_list_panel.dart';

class LedgerHome extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onToggleLocale;

  const LedgerHome({super.key, required this.db, required this.onToggleLocale});

  @override
    State<LedgerHome> createState() => _LedgerHomeState();
  }

class _LedgerHomeState extends State<LedgerHome> with SingleTickerProviderStateMixin {
  // Screenshot / capture area
  final GlobalKey _txListAreaKey = GlobalKey(debugLabel: 'tx_list_area');

  // Selection mode
  bool _selectMode = false;
  final Set<String> _selectedIds = <String>{};
  List<String> _lastTxIds = const <String>[];

  // Drawer
  late final AnimationController _drawerCtrl;
  static const Duration _drawerDur = Duration(milliseconds: 360);
  static const Curve _drawerCurve = Curves.easeOutCubic;

  // Paged: Home (0) <-> Stats (1)
  late final PageController _pageCtrl;
  int _pageIndex = 0; // 0=Home, 1=Stats
  int _refreshTick = 0;
  // Filters (search)
  bool _showSearch = false; // collapsible search panel
  // Home quick actions (2 customizable slots). Persisted in Settings.
  String _qaSlot3 = 'stats';
  String _qaSlot4 = 'history';
  DateTimeRange? _filterRange;
  int? _filterCategoryId;
  String _filterKeyword = '';
  late final TextEditingController _keywordCtrl;
  late final Stream<List<Category>> _filterCatsStream;


  void _openStats() => _pageCtrl.animateToPage(1, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  void _openHome() => _pageCtrl.animateToPage(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  void _refreshHome() {
    if (!mounted) return;
    setState(() {
      _refreshTick++;
    });
  }

  void _openDrawer() => _drawerCtrl.animateTo(1.0, duration: _drawerDur, curve: _drawerCurve);
  void _closeDrawer() => _drawerCtrl.animateTo(0.0, duration: _drawerDur, curve: _drawerCurve);


  @override
  void initState() {
    super.initState();
    _loadQuickActions();
    _drawerCtrl = AnimationController(vsync: this, duration: _drawerDur);
    _pageCtrl = PageController(initialPage: 0);

    _keywordCtrl = TextEditingController();
    _filterCatsStream = (widget.db.select(widget.db.categories)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .watch();

    // ✅ 只加这一段：不要再写第二个 initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRestoreIfEmpty();
    });
  }
  
  Future<void> _tryRestoreIfEmpty() async {
    final hasAny = await widget.db.hasAnyTransactions();
    if (hasAny) return;

    final backup = await AutoBackupService.I.readLatest();
    if (!mounted || backup == null) return;

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('检测到自动备份'),
            content: const Text('当前账单为空，是否从自动备份恢复？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('恢复')),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    final svc = ImportExportService(widget.db);
    await svc.importAppend(backup);
  }

  Future<void> _loadQuickActions() async {
    // Persisted in SharedPreferences (independent from Settings.dart to avoid coupling).
    const kQaSlot3 = 'qa_slot3';
    const kQaSlot4 = 'qa_slot4';
    try {
      final p = await SharedPreferences.getInstance();
      final s3 = p.getString(kQaSlot3);
      final s4 = p.getString(kQaSlot4);
      _qaSlot3 = (s3 == null || s3.isEmpty) ? 'stats' : s3;
      _qaSlot4 = (s4 == null || s4.isEmpty) ? 'history' : s4;
      if (_qaSlot3 == _qaSlot4) {
        _qaSlot4 = _qaSlot3 == 'stats' ? 'history' : 'stats';
      }
      if (mounted) setState(() {});
    } catch (_) {
      // keep defaults
    }
  }

  _QaItem _resolveQa(BuildContext context, String key) {
    switch (key) {
      case 'history':
        return _QaItem(
          icon: Icons.history_rounded,
          tooltip: tr(context, en: 'History', zh: '历史'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HistoryPage(db: widget.db)),
            );
            _refreshHome();
          },
        );
      case 'categories':
        return _QaItem(
          icon: Icons.category_rounded,
          tooltip: tr(context, en: 'Categories', zh: '分类'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CategoryManagePage(db: widget.db)),
            );
            _refreshHome();
          },
        );
      case 'settings':
        return _QaItem(
          icon: Icons.settings_rounded,
          tooltip: tr(context, en: 'Settings', zh: '设置'),
          onTap: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  db: widget.db,
                  onToggleLocale: widget.onToggleLocale,
                ),
              ),
            );
            // ✅ Regardless of return value, settings may have saved new quick actions.
            await _loadQuickActions();
            if (mounted) setState(() {});
            _refreshHome();
          },
        );
      case 'stats':
      default:
        return _QaItem(
          icon: Icons.bar_chart_rounded,
          tooltip: tr(context, en: 'Stats', zh: '统计'),
          onTap: _openStats,
        );
    }
  }

  @override
void dispose() {
    _keywordCtrl.dispose();
    _drawerCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  
  Future<List<Category>> _loadFilterCategories() {
    final q = widget.db.select(widget.db.categories)
      ..where((c) => c.isActive.equals(true))
      ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]);
    return q.get();
  }

  String _fmtRangeLabel(BuildContext context, DateTimeRange? r) {
    if (r == null) return tr(context, en: 'Date', zh: '时间');
    String two(int v) => v.toString().padLeft(2, '0');
    final a = r.start;
    final b = r.end;
    return '${two(a.month)}/${two(a.day)}-${two(b.month)}/${two(b.day)}';
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = _filterRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, now.day - 6),
          end: DateTime(now.year, now.month, now.day),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: initial,
    );

    if (picked != null) {
      setState(() => _filterRange = picked);
    }
  }

  void _resetFilters() {
    setState(() {
      _filterRange = null;
      _filterCategoryId = null;
      _filterKeyword = '';
      _keywordCtrl.clear();
    });
  }


  Widget _filterPillButton({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool emphasized = false,
  bool expanded = false,
  bool dense = false,
  bool showChevron = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final border = Theme.of(context).dividerColor.withValues(alpha: 90);

  final h = dense ? 36.0 : 40.0;
  final padH = dense ? 8.0 : 12.0;
  final iconSize = dense ? 16.0 : 18.0;
  final gap1 = dense ? 6.0 : 8.0;
  final gap2 = dense ? 4.0 : 6.0;

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      height: h,
      width: expanded ? double.infinity : null, // ✅ 让 Expanded 真正铺满
      padding: EdgeInsets.symmetric(horizontal: padH),
      decoration: BoxDecoration(
        color: emphasized ? scheme.primary.withValues(alpha: 22) : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max, // ✅ 不要 min
        children: [
          Icon(icon, size: iconSize, color: scheme.onSurfaceVariant),
          SizedBox(width: gap1),

          // ✅ 文本挤压时省略号，避免溢出
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 12.5 : 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),

          if (showChevron) ...[
            SizedBox(width: gap2),
            Icon(Icons.expand_more, size: iconSize, color: scheme.onSurfaceVariant),
          ],
        ],
      ),
    ),
  );
}

Widget _filterResetSquareButton(BuildContext context, {required bool enabled}) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: enabled ? 90 : 60);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? _resetFilters : null,
      child: Container(
        height: 36,
        width: 40,
        decoration: BoxDecoration(
          color: enabled ? scheme.surface : scheme.surface.withValues(alpha: 160),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Icon(
          Icons.refresh,
          size: 18,
          color: enabled ? scheme.onSurfaceVariant : scheme.onSurfaceVariant.withValues(alpha: 120),
        ),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 80);

    final cats = await _loadFilterCategories();
    int? selected = _filterCategoryId;
    String kw = '';

    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: border),
              ),
              child: StatefulBuilder(
                builder: (context, setModal) {
                  final filtered = cats.where((c) {
                    final name = categoryLabel(context, c.name);
                    if (kw.trim().isEmpty) return true;
                    return name.toLowerCase().contains(kw.trim().toLowerCase());
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 80),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Text(
                              tr(context, en: 'Category', zh: '消费类别'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(context, null),
                              child: Text(tr(context, en: 'All', zh: '全部')),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                        child: TextField(
                          onChanged: (v) => setModal(() => kw = v),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: tr(context, en: 'Search category', zh: '搜索类别'),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (_, i) {
                            final c = filtered[i];
                            final isOn = selected == c.id;
                            final name = categoryLabel(context, c.name);

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setModal(() => selected = c.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isOn ? scheme.primary.withValues(alpha: 16) : scheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor.withValues(alpha: isOn ? 120 : 60),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (isOn)
                                      Icon(Icons.check_circle, size: 18, color: scheme.primary)
                                    else
                                      Icon(Icons.circle_outlined, size: 18, color: scheme.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, null),
                                child: Text(tr(context, en: 'Clear', zh: '清除')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: () => Navigator.pop(context, selected),
                                child: Text(tr(context, en: 'Apply', zh: '应用')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() => _filterCategoryId = result);
  }
  
  Widget _buildSearchPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor.withValues(alpha: 64);

    final hasAny = _filterKeyword.trim().isNotEmpty || _filterRange != null || _filterCategoryId != null;

    return ConstrainedBox(
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
              controller: _keywordCtrl,
              onChanged: (v) => setState(() => _filterKeyword = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: tr(context, en: 'Search keyword', zh: '关键词搜索'),

                // ✅ 控制输入框上下“厚度”
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6, // 6更紧凑，10更高
                ),

                prefixIcon: const Icon(Icons.search, size: 20),

                // ✅ 防止 prefixIcon 默认把高度撑到 48
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 36,
                ),

                suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: _filterKeyword.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: tr(context, en: 'Clear', zh: '清除'),
                        onPressed: () {
                          _keywordCtrl.clear();
                          setState(() => _filterKeyword = '');
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),

                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Category>>(
              stream: _filterCatsStream,
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];

                // ✅ 如果当前选中的分类已经被删除/失活，自动清空筛选
                if (_filterCategoryId != null && cats.every((c) => c.id != _filterCategoryId)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _filterCategoryId = null);
                  });
                }

                String catText = tr(context, en: 'Type', zh: '类型');
                if (_filterCategoryId != null) {
                  for (final c in cats) {
                    if (c.id == _filterCategoryId) {
                      catText = categoryLabel(context, c.name);
                      break;
                    }
                  }
                }

                // 下面保持你原来的 Row / pill button 不变
                return LayoutBuilder(
                  builder: (context, c) {
                    final dense = c.maxWidth < 420;
                    final gap = dense ? 6.0 : 10.0;
                    final resetW = dense ? 40.0 : 44.0;

                    return Row(
                      children: [
                        Expanded(
                          child: _filterPillButton(
                            context: context,
                            icon: Icons.calendar_month,
                            label: _fmtRangeLabel(context, _filterRange),
                            emphasized: _filterRange != null,
                            onTap: () => _pickRange(),
                            expanded: true,
                            dense: dense,
                            showChevron: !dense,
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: _filterPillButton(
                            context: context,
                            icon: Icons.category_outlined,
                            label: catText,
                            emphasized: _filterCategoryId != null,
                            onTap: () => _pickCategory(context), // ✅ 下面第4步也要改
                            expanded: true,
                            dense: dense,
                            showChevron: !dense,
                          ),
                        ),
                        SizedBox(width: gap),
                        SizedBox(
                          width: resetW,
                          height: dense ? 36 : 40,
                          child: _filterResetSquareButton(context, enabled: hasAny),
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

  String _fmtDay(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final onToggleLocale = widget.onToggleLocale;

    final base = db.select(db.transactions);

    final kw = _filterKeyword.trim();
    if (kw.isNotEmpty) {
      base.where((t) => t.merchant.like('%$kw%') | t.memo.like('%$kw%'));
    }

    if (_filterCategoryId != null) {
      base.where((t) => t.categoryId.equals(_filterCategoryId!));
    }

    if (_filterRange != null) {
      final a = _filterRange!.start;
      final b = _filterRange!.end;
      final start = DateTime(a.year, a.month, a.day, 0, 0, 0);
      final end = DateTime(b.year, b.month, b.day, 23, 59, 59, 999);
      base.where((t) => t.occurredAt.isBetweenValues(start, end));
    }

    final query = (base
          ..orderBy([
            (t) => d.OrderingTerm(expression: t.occurredAt, mode: d.OrderingMode.desc),
          ]))
        .join([
      d.leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
    ]);

    final stream = query.watch().map((rows) {
      return rows.map((r) {
        final tx = r.readTable(db.transactions);
        final cat = r.readTableOrNull(db.categories);
        return TxViewRow(tx: tx, category: cat);
      }).toList();
    });

    return WillPopScope(
      onWillPop: () async {
        // If stats page is visible, go back to home page first.
        final page = _pageCtrl.hasClients ? (_pageCtrl.page ?? 0.0) : 0.0;
        if (page > 0.5) {
          _openHome();
          return false;
        }
        if (_drawerCtrl.value > 0) {
          _closeDrawer();
          return false;
        }
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final drawerWidth = (constraints.maxWidth * 0.78).clamp(260.0, 360.0);

          Widget buildStatsScaffold() {
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              appBar: AppBar(
                title: Text(tr(context, en: 'Stats', zh: '统计')),
                leading: IconButton(
                  tooltip: tr(context, en: 'Back', zh: '返回'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _openHome,
                ),
              ),
              body: SafeArea(
                child: MonthlyStatsSheet(service: ReportService(db)),
              ),
            );
          }

          Widget buildScaffold() {
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              appBar: AppBar(
                leading: _selectMode
                    ? IconButton(
                        tooltip: tr(context, en: 'Cancel', zh: '退出'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedIds.clear();
                            _selectMode = false;
                          });
                        },
                      )
                    : IconButton(
                        tooltip: tr(context, en: 'Menu', zh: '菜单'),
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: _openDrawer,
                      ),
                title: Text(
                  _selectMode
                      ? tr(context, en: 'Selected ${_selectedIds.length}', zh: '已选 ${_selectedIds.length} 条')
                      : tr(context, en: 'Ledger ✅', zh: '记账 ✅'),
                ),
                actions: [
                  if (_selectMode) ...[
                    IconButton(
                      tooltip: tr(context, en: 'Select all', zh: '全选'),
                      icon: const Icon(Icons.select_all),
                      onPressed: () {
                        setState(() {
                          _selectedIds
                            ..clear()
                            ..addAll(_lastTxIds);
                        });
                      },
                    ),
                    IconButton(
                      tooltip: tr(context, en: 'Delete', zh: '删除'),
                      icon: const Icon(Icons.delete_forever),
                      onPressed: _selectedIds.isEmpty
                          ? null
                          : () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(tr(context, en: 'Delete selected?', zh: '删除已选记录？')),
                                  content: Text(tr(context, en: 'This cannot be undone.', zh: '此操作不可撤销。')),
                                  actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  actionsAlignment: MainAxisAlignment.end,
                                  actions: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        side: BorderSide(color: Theme.of(context).colorScheme.outline),
                                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                                      ),
                                      onPressed: () => Navigator.pop(context, false),
                                      child: Text(tr(context, en: 'Cancel', zh: '取消')),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                        foregroundColor: Theme.of(context).colorScheme.onError,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: Text(tr(context, en: 'Delete', zh: '删除')),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;

                              final count = await (db.delete(db.transactions)..where((t) => t.id.isIn(_selectedIds.toList()))).go();
                              if (count > 0) {
                                AutoBackupService.I.scheduleBackup(widget.db);
                                print('[DEL] scheduled backup');
                              }
                              if (!context.mounted) return;
                              setState(() {
                                _selectedIds.clear();
                                _selectMode = false;
                              });
                            },
                    ),
                  ],
                ],
              ),
              body: StreamBuilder<List<TxViewRow>>(
                stream: stream,
                builder: (context, snapshot) {
                  final txs = snapshot.data ?? const <TxViewRow>[];
                  _lastTxIds = txs.map((e) => e.tx.id).toList(growable: false);

                  int income = 0;
                  int expense = 0;
                  for (final r in txs) {
                    if (r.tx.direction == 'income') {
                      income += r.tx.amountCents;
                    } else {
                      expense += r.tx.amountCents;
                    }
                  }
                  final balance = (income - expense) / 100.0;

                  final items = <_ListEntry>[];
                  String? currentDay;
                  for (final r in txs) {
                    final day = _fmtDay(r.tx.occurredAt);
                    if (day != currentDay) {
                      currentDay = day;
                      items.add(_HeaderEntry(day));
                    }
                    items.add(_TxEntry(r));
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),

                      // Top area
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            FutureBuilder(
                              key: ValueKey(_refreshTick),
                              future: Settings.getMinBalance(),
                              builder: (context, snap) {
                                final minB = snap.data as double?;
                                final isLow = (minB != null) && (balance < minB);

                                return LayoutBuilder(
                                  builder: (context, c) {
                                    final isNarrow = c.maxWidth < 720;
                                    const double _qaPad = 10;
                                    const double _qaBtn = 54;
                                    const double _qaGapX = 10;

                                    final minActionsWidth = _qaPad * 2 + _qaBtn * 2 + _qaGapX; // 138
                                    final actionsWidth = isNarrow ? minActionsWidth : (minActionsWidth + 8); // 138 / 146

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Container(
                                              //color: Colors.blue.withValues(alpha: 30),
                                              child: BalanceCard(
                                                balance: balance,
                                                isLow: isLow,
                                                accentColor: isLow ? Colors.red : Colors.green,
                                              ),),
                                            ),
                                            
                                            SizedBox(
                                              width: actionsWidth,
                                              //child: Container(
                                               //color: const Color.fromARGB(255, 243, 33, 198).withValues(alpha: 30),
                                              child: Builder(
                                                builder: (ctx) {
                                                  final qa3 = _resolveQa(ctx, _qaSlot3);
                                                  final qa4 = _resolveQa(ctx, _qaSlot4);
                                                  return LedgerQuickActions(
                                                    isSearchOpen: _showSearch,
                                                    onToggleSearch: () => setState(() => _showSearch = !_showSearch),
                                                    onOpenAdd: () async {
                                                      final changed = await Navigator.push(
                                                        ctx,
                                                        MaterialPageRoute(builder: (_) => AddTransactionPage(db: widget.db)),
                                                      );
                                                      if (changed == true) {
                                                        AutoBackupService.I.scheduleBackup(widget.db);
                                                      }
                                                      _refreshHome();
                                                    },
                                                    slot3Icon: qa3.icon,
                                                    slot3Tooltip: qa3.tooltip,
                                                    onSlot3: qa3.onTap,
                                                    slot4Icon: qa4.icon,
                                                    slot4Tooltip: qa4.tooltip,
                                                    onSlot4: qa4.onTap,
                                                  );
                                                },
                                              ),),
                                            //),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 500),
                                          curve: Curves.easeOutCubic,
                                          alignment: Alignment.topCenter,
                                          child: _showSearch
                                              ? _buildSearchPanel(context)
                                              : const SizedBox.shrink(),
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

                      const SizedBox(height: 10),

                      // Bill list panel
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RepaintBoundary(
                            key: _txListAreaKey,
                            child: Semantics(
                              label: 'transactions_list_area',
                              child: Builder(
                                builder: (context) {
                                  final scheme = Theme.of(context).colorScheme;
                                  final border = Theme.of(context).dividerColor.withValues(alpha: 64);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      borderRadius: BorderRadius.circular(22), // ✅ 和搜索卡片一致
                                      border: Border.all(color: border),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(22),
                                      child: txs.isEmpty
                                          ? Center(
                                              child: Text(tr(context, en: 'No transactions yet', zh: '还没有记录')),
                                            )
                                          : ListView.builder(
                                              key: const ValueKey('tx_list'),
                                              padding: EdgeInsets.zero,
                                              itemCount: items.length,
                                              itemBuilder: (context, index) {
                                                // ✅ 这里恢复你原来的逻辑（不要 _buildTxItem）
                                                final item = items[index];
                                                if (item is _HeaderEntry) return DayHeader(title: item.title);

                                                final txItem = item as _TxEntry;
                                                final row = txItem.row;
                                                final tx = row.tx;

                                                final isIncomeTx = tx.direction == 'income';
                                                final amount = tx.amountCents / 100.0;
                                                final time = _fmtTime(tx.occurredAt);

                                                final rawCat = row.category?.name;
                                                final categoryText = rawCat == null
                                                    ? tr(context, en: 'Uncategorized', zh: '未分类')
                                                    : categoryLabel(context, rawCat);

                                                final content = (tx.merchant?.trim().isNotEmpty == true)
                                                    ? tx.merchant!.trim()
                                                    : (tx.memo?.trim().isNotEmpty == true)
                                                        ? tx.memo!.trim()
                                                        : categoryText;

                                                final detail = (tx.merchant?.trim().isNotEmpty == true &&
                                                        tx.memo?.trim().isNotEmpty == true)
                                                    ? tx.memo!.trim()
                                                    : null;

                                                final subtitle = detail == null ? categoryText : '$categoryText · $detail';
                                                final selected = _selectedIds.contains(tx.id);

                                                return InkWell(
                                                  onLongPress: () {
                                                    setState(() {
                                                      _selectMode = true;
                                                      _selectedIds.add(tx.id);
                                                    });
                                                  },
                                                  onTap: !_selectMode
                                                      ? null
                                                      : () {
                                                          setState(() {
                                                            if (selected) {
                                                              _selectedIds.remove(tx.id);
                                                              if (_selectedIds.isEmpty) _selectMode = false;
                                                            } else {
                                                              _selectedIds.add(tx.id);
                                                            }
                                                          });
                                                        },
                                                  child: Stack(
                                                    children: [
                                                      Padding(
                                                        padding: EdgeInsets.only(left: _selectMode ? 44 : 0),
                                                        child: IgnorePointer(
                                                          ignoring: _selectMode,
                                                          child: TxTile(
                                                            id: tx.id,
                                                            time: time,
                                                            title: content,
                                                            subtitle: subtitle,
                                                            amount: amount,
                                                            isIncome: isIncomeTx,
                                                            onEdit: () async {
                                                              if (_selectMode) return;
                                                              final changed = await Navigator.of(context).push(
                                                                MaterialPageRoute(
                                                                  builder: (_) => AddTransactionPage(
                                                                    db: db,
                                                                    initialTx: tx,
                                                                  ),
                                                                ),
                                                              );
                                                              if (changed == true) {
                                                                AutoBackupService.I.scheduleBackup(widget.db);
                                                              }
                                                            },
                                                            onDelete: () async {
                                                              if (_selectMode) return;
                                                              final count = await (widget.db.delete(widget.db.transactions)
                                                                    ..where((t) => t.id.equals(tx.id)))
                                                                  .go();

                                                              if (count > 0) {
                                                                await AutoBackupService.I.writeLatestNow(widget.db); // ✅ 删除后立刻写（别用 schedule）
                                                                print('[DEL1] deleted txId=${tx.id}, backup written');
                                                              }
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      if (_selectMode)
                                                        Positioned(
                                                          left: -4,
                                                          top: 0,
                                                          bottom: 0,
                                                          child: IgnorePointer(
                                                            child: Checkbox(
                                                              value: selected,
                                                              onChanged: (_) {},
                                                              fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                                                                if (states.contains(MaterialState.selected)) {
                                                                  return const Color(0xFF22C55E);
                                                                }
                                                                return Colors.transparent;
                                                              }),
                                                              checkColor: Colors.black,
                                                              side: const BorderSide(color: Colors.black, width: 1.5),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }


          Widget buildPagedContent() {
            return AnimatedBuilder(
              animation: _pageCtrl,
              builder: (context, _) {
                final page = _pageCtrl.hasClients ? (_pageCtrl.page ?? 0.0) : 0.0;
                final t = page.clamp(0.0, 1.0);

                Widget shell({required Widget child, required double scale, required double radius}) {
                  return Transform.scale(
                    scale: scale,
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: child,
                    ),
                  );
                }

                final homeScale = 1.0 - (0.03 * t);
                final statsScale = 0.97 + (0.03 * t);
                final radius = 18.0 * (t < 0.5 ? t * 2 : (1 - t) * 2);

                return PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    setState(() {
                      _pageIndex = i;
                      if (i == 0) _refreshTick++;
                    });
                  },
                  physics: _drawerCtrl.value > 0 ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                  children: [
                    shell(child: buildScaffold(), scale: homeScale, radius: radius),
                    shell(child: buildStatsScaffold(), scale: statsScale, radius: radius),
                  ],
                );
              },
            );
          }
          return LedgerDrawerShell(
            controller: _drawerCtrl,
            drawerWidth: drawerWidth,
            edgeTriggerWidth: _pageIndex == 0 ? 70 : 0, // disable edge swipe on Stats
            canOpen: !_selectMode && _pageIndex == 0,
            duration: _drawerDur,
            curve: _drawerCurve,
            onTapScrim: _closeDrawer,
            drawer: SafeArea(
            child: LedgerSideMenu(
              // ✅ 只保留一个 statsPageBuilder（用你已经存在的 _MonthlyStatsPage）
              statsPageBuilder: (_) => _MonthlyStatsPage(db: widget.db),

              onOpenStats: () {
                _closeDrawer();
                _openStats();
              },

              // ✅ 历史：去 HistoryPage（你项目里有 history_page.dart）
              onOpenHistory: () async {
                _closeDrawer();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HistoryPage(db: widget.db)),
                );
                _refreshHome();
              },

              // ✅ 新增：类别管理
              onOpenCategories: () async {
                _closeDrawer();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CategoryManagePage(db: widget.db)),
                );
                _refreshHome();
              },

              onOpenSettings: () async {
                _closeDrawer();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      db: widget.db,
                      onToggleLocale: widget.onToggleLocale,
                    ),
                  ),
                );
                // ✅ Refresh quick actions after returning from Settings.
                await _loadQuickActions();
                if (mounted) setState(() {});
                _refreshHome();
              },
            ),
          ),
            content: buildPagedContent(),
          );
        },
      ),
    );
  }
}


/// Stats page wrapper (formerly shown as a bottom sheet).
/// Opens as a normal page (right-to-left slide) via Navigator.push.
class _MonthlyStatsPage extends StatelessWidget {
  final AppDatabase db;
  const _MonthlyStatsPage({required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Stats', zh: '统计')),
      ),
      body: SafeArea(
        child: MonthlyStatsSheet(service: ReportService(db)),
      ),
    );
  }
}


abstract class _ListEntry {
  const _ListEntry();
}

class _HeaderEntry extends _ListEntry {
  final String title;
  const _HeaderEntry(this.title);
}

class _TxEntry extends _ListEntry {
  final TxViewRow row;
  const _TxEntry(this.row);
}

class _QaItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _QaItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
}
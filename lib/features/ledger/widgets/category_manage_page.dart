import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;

// NOTE: This file lives under lib/features/ledger/widgets/
// so we need to go up 3 levels to reach lib/.
import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';
import '../../../l10n/category_i18n.dart';

class CategoryManagePage extends StatefulWidget {
  final AppDatabase db;

  const CategoryManagePage({super.key, required this.db});

  static Future<void> open(BuildContext context, AppDatabase db) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryManagePage(db: db)),
    );
  }

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final Stream<List<Category>> _expenseStream;
  late final Stream<List<Category>> _incomeStream;

  AppDatabase get db => widget.db;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    _expenseStream = (db.select(db.categories)
          ..where((c) => c.direction.equals('expense') & c.isActive.equals(true))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .watch();

    _incomeStream = (db.select(db.categories)
          ..where((c) => c.direction.equals('income') & c.isActive.equals(true))
          ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String _dirLabel(BuildContext context, String dir) {
    if (dir == 'income') return tr(context, en: 'Income', zh: '收入');
    return tr(context, en: 'Expense', zh: '支出');
  }

  // -----------------------------
  // DB helpers
  // -----------------------------

  Future<int> _nextSortOrder(String direction) async {
    final rows = await (db.select(db.categories)
          ..where((c) => c.direction.equals(direction))
          ..orderBy([
            (c) => d.OrderingTerm(
                  expression: c.sortOrder,
                  mode: d.OrderingMode.desc,
                )
          ])
          ..limit(1))
        .get();
    if (rows.isEmpty) return 0;
    return rows.first.sortOrder + 1;
  }

  Future<Category?> _getCategoryByName(String direction, String name) async {
    final rows = await (db.select(db.categories)
          ..where((c) => c.direction.equals(direction) & c.name.equals(name)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Category?> _getCategoryByNameAnyActive(String direction, String name) async {
    // Same as _getCategoryByName, kept for readability.
    return _getCategoryByName(direction, name);
  }

  Future<int> _ensureOtherId(String direction) async {
    // Ensure "other" exists (active).
    final exist = await _getCategoryByName(direction, 'other');

    if (exist != null) {
      if (!exist.isActive) {
        await (db.update(db.categories)..where((c) => c.id.equals(exist.id))).write(
          const CategoriesCompanion(isActive: d.Value(true)),
        );
      }
      return exist.id;
    }

    final next = await _nextSortOrder(direction);
    final inserted = await db.into(db.categories).insertReturning(
          CategoriesCompanion(
            name: const d.Value('other'),
            direction: d.Value(direction),
            isActive: const d.Value(true),
            sortOrder: d.Value(next),
          ),
        );
    return inserted.id;
  }

  Future<void> _deleteCategoryHard(Category cat) async {
    // Protect "other"
    if (cat.name == 'other') return;

    await db.transaction(() async {
      final otherId = await _ensureOtherId(cat.direction);

      // Move all tx to other
      await (db.update(db.transactions)..where((t) => t.categoryId.equals(cat.id))).write(
        TransactionsCompanion(categoryId: d.Value(otherId)),
      );

      // Hard delete category row
      await (db.delete(db.categories)..where((c) => c.id.equals(cat.id))).go();
    });
  }

  Future<void> _addOrReviveCategory(String direction, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    if (name == 'other') {
      _toast(tr(context, en: '"other" is reserved', zh: '“other/其他”是保留类别'));
      return;
    }

    final next = await _nextSortOrder(direction);

    try {
      final existing = await _getCategoryByNameAnyActive(direction, name);

      if (existing != null) {
        // revive
        await (db.update(db.categories)..where((c) => c.id.equals(existing.id))).write(
          CategoriesCompanion(
            isActive: const d.Value(true),
            sortOrder: d.Value(next),
          ),
        );
      } else {
        await db.into(db.categories).insert(
              CategoriesCompanion(
                name: d.Value(name),
                direction: d.Value(direction),
                isActive: const d.Value(true),
                sortOrder: d.Value(next),
              ),
            );
      }
    } catch (e) {
      _toast(tr(context, en: 'Failed: $e', zh: '失败：$e'));
    }
  }

  Future<void> _renameCategory(Category cat, String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return;

    if (cat.name == 'other') {
      _toast(tr(context, en: '"other" cannot be renamed', zh: '“其他”不可重命名'));
      return;
    }
    if (name == 'other') {
      _toast(tr(context, en: '"other" is reserved', zh: '“other/其他”是保留类别'));
      return;
    }

    try {
      // Prevent conflict with UNIQUE(name, direction)
      final conflictRows = await (db.select(db.categories)
            ..where((c) => c.name.equals(name) & c.direction.equals(cat.direction)))
          .get();
      final conflict = conflictRows.isEmpty ? null : conflictRows.first;

      if (conflict != null && conflict.id != cat.id) {
        _toast(tr(context, en: 'Name already exists', zh: '该名称已存在'));
        return;
      }

      await (db.update(db.categories)..where((c) => c.id.equals(cat.id))).write(
        CategoriesCompanion(name: d.Value(name)),
      );
    } catch (e) {
      _toast(tr(context, en: 'Failed: $e', zh: '失败：$e'));
    }
  }

  Future<void> _reorderAndPersist(
    String direction,
    List<Category> cats,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...cats];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    await db.transaction(() async {
      for (int i = 0; i < list.length; i++) {
        final c = list[i];
        if (c.sortOrder == i) continue;
        await (db.update(db.categories)..where((t) => t.id.equals(c.id))).write(
          CategoriesCompanion(sortOrder: d.Value(i)),
        );
      }
    });
  }

  // -----------------------------
  // UI helpers
  // -----------------------------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<String?> _promptText({
    required String title,
    String? initial,
    String? hint,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(ctrl.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(tr(context, en: 'Cancel', zh: '取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: Text(tr(context, en: 'OK', zh: '确定')),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmDelete(Category cat) async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(tr(context, en: 'Delete category?', zh: '删除类别？')),
              content: Text(
                tr(
                  context,
                  en: 'All transactions in this category will be moved to "Other".',
                  zh: '该类别下的所有账单将自动归类到“其他”。',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr(context, en: 'Cancel', zh: '取消')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr(context, en: 'Delete', zh: '删除')),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Widget _buildList(String direction, Stream<List<Category>> stream) {
    return StreamBuilder<List<Category>>(
      stream: stream,
      builder: (context, snap) {
        final cats = snap.data ?? const <Category>[];

        if (cats.isEmpty) {
          return Center(child: Text(tr(context, en: 'No categories', zh: '暂无类别')));
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: cats.length,
          onReorder: (oldIndex, newIndex) =>
              _reorderAndPersist(direction, cats, oldIndex, newIndex),
          itemBuilder: (context, index) {
            final c = cats[index];
            final title = categoryLabel(context, c.name);
            final isOther = c.name == 'other';

            return Card(
              key: ValueKey('cat_${c.id}'),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.drag_handle),
                title: Text(
                  title,
                  style: TextStyle(fontWeight: isOther ? FontWeight.w700 : FontWeight.w600),
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      tooltip: tr(context, en: 'Rename', zh: '重命名'),
                      onPressed: isOther
                          ? null
                          : () async {
                              final newName = await _promptText(
                                title: tr(context, en: 'Rename category', zh: '重命名类别'),
                                initial: c.name,
                                hint: tr(
                                  context,
                                  en: 'Use i18n key or custom name',
                                  zh: '使用 i18n key 或自定义名称',
                                ),
                              );
                              if (newName == null) return;
                              await _renameCategory(c, newName);
                            },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: tr(context, en: 'Delete', zh: '删除'),
                      onPressed: isOther
                          ? null
                          : () async {
                              final ok = await _confirmDelete(c);
                              if (!ok) return;
                              await _deleteCategoryHard(c);
                            },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onAddPressed() async {
    final dir = _tabCtrl.index == 0 ? 'expense' : 'income';
    final name = await _promptText(
      title: tr(context, en: 'Add category', zh: '新增类别'),
      hint: tr(context, en: 'e.g. food / transport / my_custom', zh: '例如 food / transport / my_custom'),
    );
    if (name == null) return;
    await _addOrReviveCategory(dir, name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Categories', zh: '类别管理')),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: _dirLabel(context, 'expense')),
            Tab(text: _dirLabel(context, 'income')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr(context, en: 'Add', zh: '新增'),
            onPressed: _onAddPressed,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      backgroundColor: scheme.surface,
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildList('expense', _expenseStream),
          _buildList('income', _incomeStream),
        ],
      ),
    );
  }
}

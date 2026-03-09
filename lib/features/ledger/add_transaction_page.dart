import 'dart:async';

import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';
import '../../l10n/category_i18n.dart';
import 'add_transaction_texts.dart';
import '../onboarding/coach_overlay.dart';
import '../onboarding/home_tutorial_controller.dart';
import '../onboarding/tutorial_chapter_result.dart';
import '../../ui/pet/pet_bus.dart';
import '../../ui/pet/pet_talker.dart';

class AddTransactionPage extends StatefulWidget {
  final AppDatabase db;
  final int? accountId;
  final String? accountCurrency;
  final Transaction? initialTx;
  final bool startTutorial;
  final ValueChanged<String>? onSavedTransactionId;

  const AddTransactionPage({
    super.key,
    required this.db,
    this.accountId,
    this.accountCurrency,
    this.initialTx,
    this.startTutorial = false,
    this.onSavedTransactionId,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static final Uuid _uuid = const Uuid();
  final _amountController = TextEditingController();
  final _contentController = TextEditingController();
  final _newCatController = TextEditingController();
  final List<_QuickTemplate> _quickTemplates = <_QuickTemplate>[];
  late final HomeTutorialController _addTutorialController;

  bool _isIncome = false;
  int? _categoryId;
  bool _catExpanded = false;
  bool _catManageMode = false;
  int? _suggestedCategoryId;
  Timer? _suggestDebounce;
  late DateTime _occurredAt;
  Timer? _tutorialRectSyncTimer;
  final GlobalKey _tutorialDateKey = GlobalKey(debugLabel: 'add_tutorial_date');
  final GlobalKey _tutorialTypeKey = GlobalKey(debugLabel: 'add_tutorial_type');
  final GlobalKey _tutorialAmountKey = GlobalKey(
    debugLabel: 'add_tutorial_amount',
  );
  final GlobalKey _tutorialCategoryKey = GlobalKey(
    debugLabel: 'add_tutorial_category',
  );
  final GlobalKey _tutorialContentKey = GlobalKey(
    debugLabel: 'add_tutorial_content',
  );
  final GlobalKey _tutorialSaveKey = GlobalKey(debugLabel: 'add_tutorial_save');

  AppDatabase get db => widget.db;
  bool get _isEdit => widget.initialTx != null;
  bool get _isTutorialMode => widget.startTutorial;
  bool get _isAddTutorialMode => _isTutorialMode && !_isEdit;
  bool get _isEditTutorialMode => _isTutorialMode && _isEdit;

  @override
  void initState() {
    super.initState();
    _addTutorialController = HomeTutorialController(
      onFinish: ({required bool skipped}) async {
        _setTutorialRectSyncing(false);
        if (!mounted) return;
        if (_isTutorialMode) {
          Navigator.of(context).pop(
            skipped
                ? TutorialChapterResult.skippedToNextMain
                : TutorialChapterResult.completed,
          );
          return;
        }
        Navigator.of(context).pop(false);
      },
    );

    final tx = widget.initialTx;
    if (tx != null) {
      _isIncome = tx.direction == 'income';
      _categoryId = tx.categoryId;
      _occurredAt = tx.occurredAt;
      _amountController.text = (tx.amountCents / 100.0).toStringAsFixed(2);
      if (tx.merchant != null) _contentController.text = tx.merchant!;
    } else {
      _occurredAt = DateTime.now();
    }
    _contentController.addListener(_scheduleSuggest);
    unawaited(_loadQuickTemplates());
    _scheduleSuggest();

    if (_isTutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startAddTutorial());
      });
    }
  }

  @override
  void dispose() {
    _setTutorialRectSyncing(false);
    _addTutorialController.dispose();
    _amountController.dispose();
    _contentController.dispose();
    _newCatController.dispose();
    _suggestDebounce?.cancel();
    super.dispose();
  }

  void _setTutorialRectSyncing(bool enabled) {
    if (enabled) {
      _tutorialRectSyncTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!mounted || !_addTutorialController.isRunning) {
            _setTutorialRectSyncing(false);
            return;
          }
          setState(() {});
        },
      );
      return;
    }
    _tutorialRectSyncTimer?.cancel();
    _tutorialRectSyncTimer = null;
  }

  Future<String?> _categoryNameById(int? id) async {
    if (id == null) return null;
    final row = await (db.select(
      db.categories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    return row?.name;
  }

  Future<List<Category>> _loadCategories() {
    final q = db.select(db.categories)
      ..where((c) => c.direction.equals(_isIncome ? 'income' : 'expense'))
      ..where((c) => c.isActive.equals(true))
      ..orderBy([(c) => d.OrderingTerm(expression: c.sortOrder)]);
    return q.get();
  }

  Future<void> _pickDateOnly() async {
    final now = DateTime.now();
    final initial = _occurredAt;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;

    setState(() {
      _occurredAt = DateTime(date.year, date.month, date.day);
    });
  }

  String _fmtDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Future<void> _waitForNextFrame() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    return c.future;
  }

  Rect? _widgetRect(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return null;
    final offset = ro.localToGlobal(Offset.zero);
    return Rect.fromLTWH(offset.dx, offset.dy, ro.size.width, ro.size.height);
  }

  Rect? _tutorialTargetRect(HomeTutorialStep step) {
    final primary = _widgetRect(step.anchorKey);
    final secondary = _widgetRect(step.secondaryAnchorKey);
    if (primary == null && secondary == null) return null;

    Rect rect = primary ?? secondary!;
    if (primary != null && secondary != null) {
      rect = Rect.fromLTRB(
        primary.left < secondary.left ? primary.left : secondary.left,
        primary.top < secondary.top ? primary.top : secondary.top,
        primary.right > secondary.right ? primary.right : secondary.right,
        primary.bottom > secondary.bottom ? primary.bottom : secondary.bottom,
      );
    }

    final dx = rect.width * step.highlightDxFactor;
    final dy = rect.height * step.highlightDyFactor;
    final scale = step.highlightScale <= 0 ? 1.0 : step.highlightScale;

    return Rect.fromCenter(
      center: rect.center.translate(dx, dy),
      width: rect.width * scale,
      height: rect.height * scale,
    );
  }

  Future<void> _setTutorialCategoryExpanded(bool expanded) async {
    if (!mounted) return;
    if (_catExpanded == expanded) {
      await _waitForNextFrame();
      return;
    }
    setState(() {
      _catExpanded = expanded;
      if (!expanded) _catManageMode = false;
    });
    await _waitForNextFrame();
    if (expanded) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await _waitForNextFrame();
    }
  }

  Future<void> _prepareTutorialDraft() async {
    var changed = false;
    if (_amountController.text.trim().isEmpty) {
      _amountController.text = '23.50';
      changed = true;
    }
    if (_contentController.text.trim().isEmpty) {
      _contentController.text = at(context, 'Lunch with colleagues');
      changed = true;
    }
    if (_categoryId == null) {
      final categories = await _loadCategories();
      if (categories.isNotEmpty) {
        _categoryId = categories.first.id;
        changed = true;
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _insertTutorialSeedBill() async {
    if (!_isAddTutorialMode) return;
    await _prepareTutorialDraft();
    final amount = double.tryParse(_amountController.text.trim()) ?? 23.50;
    final cents = (amount * 100).round();
    final content = _contentController.text.trim().isEmpty
        ? at(context, 'Lunch with colleagues')
        : _contentController.text.trim();
    final id = 'tutorial_${DateTime.now().millisecondsSinceEpoch}';
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            accountId: widget.accountId ?? 1,
            direction: d.Value(_isIncome ? 'income' : 'expense'),
            amountCents: cents,
            occurredAt: _occurredAt,
            currency: d.Value((widget.accountCurrency ?? 'USD').toUpperCase()),
            categoryId: d.Value(_categoryId),
            merchant: d.Value(content),
          ),
        );
  }

  Future<void> _exitTutorialWithResult(TutorialChapterResult result) async {
    _setTutorialRectSyncing(false);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  List<HomeTutorialStep> _buildAddTutorialSteps(BuildContext context) {
    if (_isEditTutorialMode) {
      return <HomeTutorialStep>[
        HomeTutorialStep(
          id: 'edit_page_intro',
          groupId: 'edit_page',
          anchorKey: _tutorialSaveKey,
          title: at(context, 'Edit Page'),
          message: at(
            context,
            'This is the edit page. It is almost the same as Add page. Return to continue delete tutorial.',
          ),
          captureTargetTap: false,
        ),
      ];
    }

    return <HomeTutorialStep>[
      HomeTutorialStep(
        id: 'date',
        groupId: 'add_bill',
        anchorKey: _tutorialDateKey,
        title: at(context, 'Step 1: Date'),
        message: at(context, 'At the top, pick the bill date first.'),
        onBeforeEnter: () async => _setTutorialCategoryExpanded(false),
      ),
      HomeTutorialStep(
        id: 'type',
        groupId: 'add_bill',
        anchorKey: _tutorialTypeKey,
        title: at(context, 'Step 2: Income/Expense'),
        message: at(
          context,
          'Choose Expense or Income. This changes available categories.',
        ),
      ),
      HomeTutorialStep(
        id: 'amount',
        groupId: 'add_bill',
        anchorKey: _tutorialAmountKey,
        title: at(context, 'Step 3: Amount'),
        message: at(context, 'Enter the amount for this bill.'),
      ),
      HomeTutorialStep(
        id: 'category',
        groupId: 'add_bill',
        anchorKey: _tutorialCategoryKey,
        title: at(context, 'Step 4: Category'),
        message: at(
          context,
          'Open Category and select one (you can also add a new category).',
        ),
        onBeforeEnter: () async => _setTutorialCategoryExpanded(true),
      ),
      HomeTutorialStep(
        id: 'content',
        groupId: 'add_bill',
        anchorKey: _tutorialContentKey,
        title: at(context, 'Step 5: Content'),
        message: at(
          context,
          'Fill in notes/content to make this record easier to find later.',
        ),
        onBeforeEnter: () async => _setTutorialCategoryExpanded(false),
      ),
      HomeTutorialStep(
        id: 'save',
        groupId: 'add_bill',
        anchorKey: _tutorialSaveKey,
        title: at(context, 'Step 6: Save'),
        message: at(
          context,
          'Tap the highlighted Save/Add button to finish and create this bill.',
        ),
        onBeforeEnter: _prepareTutorialDraft,
      ),
    ];
  }

  Future<void> _startAddTutorial() async {
    if (!_isTutorialMode || !mounted || _addTutorialController.isRunning) {
      return;
    }
    final steps = _buildAddTutorialSteps(context);
    await _setTutorialCategoryExpanded(false);
    if (!mounted) return;
    _setTutorialRectSyncing(true);
    await _addTutorialController.start(steps);
  }

  Future<void> _handleAddTutorialNext() async {
    if (!_addTutorialController.isRunning) return;
    final step = _addTutorialController.currentStep;
    if (step == null) return;
    if (_isEditTutorialMode) {
      await _exitTutorialWithResult(TutorialChapterResult.completed);
      return;
    }
    if (step.id == 'save') {
      await _prepareTutorialDraft();
      await _save();
      return;
    }
    await _addTutorialController.next();
  }

  Future<void> _handleAddTutorialSkipStep() async {
    if (!_addTutorialController.isRunning) return;
    if (_isAddTutorialMode) {
      await _insertTutorialSeedBill();
    }
    await _exitTutorialWithResult(TutorialChapterResult.skippedToNextMain);
  }

  Widget _buildAddTutorialOverlay(BuildContext context) {
    if (!_isTutorialMode) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _addTutorialController,
      builder: (context, _) {
        final step = _addTutorialController.currentStep;
        if (!_addTutorialController.isRunning || step == null) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: CoachOverlay(
            targetRect: _tutorialTargetRect(step),
            title: step.title,
            message: step.message,
            index: _addTutorialController.index + 1,
            total: _addTutorialController.totalSteps,
            isLastStep: _addTutorialController.isLastStep,
            onSkip: () => unawaited(_handleAddTutorialSkipStep()),
            onNext: () => unawaited(_handleAddTutorialNext()),
            onPrevious: _addTutorialController.index > 0
                ? () => unawaited(_addTutorialController.previous())
                : null,
            backLabel: at(context, 'Back'),
            skipLabel: at(context, 'Skip Section'),
            nextLabel: at(context, 'Next'),
            doneLabel: _isEditTutorialMode
                ? at(context, 'Back to Tutorial')
                : at(context, 'Save Bill'),
            captureTargetTap: step.captureTargetTap,
            hintAnimation: step.hintAnimation,
          ),
        );
      },
    );
  }

  Future<int> _nextSortOrder(String direction) async {
    final q = db.selectOnly(db.categories)
      ..addColumns([db.categories.sortOrder.max()])
      ..where(db.categories.direction.equals(direction));

    final row = await q.getSingle();
    final maxVal = row.read(db.categories.sortOrder.max()) ?? 0;
    return maxVal + 1;
  }

  Future<void> _addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final direction = _isIncome ? 'income' : 'expense';
    final next = await _nextSortOrder(direction);

    try {
      final existing =
          await (db.select(db.categories)..where(
                (c) => c.name.equals(trimmed) & c.direction.equals(direction),
              ))
              .getSingleOrNull();

      int id;
      if (existing != null) {
        await (db.update(
          db.categories,
        )..where((c) => c.id.equals(existing.id))).write(
          CategoriesCompanion(
            isActive: const d.Value(true),
            sortOrder: d.Value(next),
          ),
        );
        id = existing.id;
      } else {
        final inserted = await db
            .into(db.categories)
            .insertReturning(
              CategoriesCompanion(
                name: d.Value(trimmed),
                direction: d.Value(direction),
                isActive: const d.Value(true),
                sortOrder: d.Value(next),
              ),
            );
        id = inserted.id;
      }

      if (!mounted) return;
      setState(() {
        _categoryId = id;
        _catExpanded = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(at(context, 'Failed to add category: $e'))),
      );
    }
  }

  Future<void> _deleteCategory(int id) async {
    await db.deleteCategoryAndMoveToOther(id);
    if (_categoryId == id) _categoryId = null;
  }

  void _toggleCategoryExpanded() {
    setState(() {
      _catExpanded = !_catExpanded;
      if (!_catExpanded) _catManageMode = false;
    });
  }

  Future<void> _loadQuickTemplates() async {
    final accountId = widget.accountId ?? 1;
    final direction = _isIncome ? 'income' : 'expense';
    final rows =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    t.direction.equals(direction),
              )
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.updatedAt,
                  mode: d.OrderingMode.desc,
                ),
              ])
              ..limit(80))
            .get();
    final seen = <String>{};
    final list = <_QuickTemplate>[];
    for (final tx in rows) {
      final merchant = (tx.merchant ?? '').trim();
      final key = '${tx.categoryId}|$merchant';
      if (seen.contains(key)) continue;
      seen.add(key);
      list.add(_QuickTemplate(categoryId: tx.categoryId, merchant: merchant));
      if (list.length >= 6) break;
    }
    if (!mounted) return;
    setState(() {
      _quickTemplates
        ..clear()
        ..addAll(list);
    });
  }

  void _scheduleSuggest() {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(_applySmartSuggestion());
    });
  }

  Future<void> _applySmartSuggestion() async {
    final keyword = _contentController.text.trim();
    if (keyword.length < 2) {
      if (mounted) setState(() => _suggestedCategoryId = null);
      return;
    }
    final accountId = widget.accountId ?? 1;
    final direction = _isIncome ? 'income' : 'expense';
    final rows =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(accountId) &
                    t.direction.equals(direction) &
                    (t.merchant.like('%$keyword%') | t.memo.like('%$keyword%')),
              )
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.updatedAt,
                  mode: d.OrderingMode.desc,
                ),
              ])
              ..limit(120))
            .get();
    if (!mounted) return;
    final score = <int, int>{};
    for (final tx in rows) {
      final cid = tx.categoryId;
      if (cid == null) continue;
      score[cid] = (score[cid] ?? 0) + 1;
    }
    if (score.isEmpty) {
      setState(() => _suggestedCategoryId = null);
      return;
    }
    final sorted = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    setState(() => _suggestedCategoryId = sorted.first.key);
  }

  Future<void> _applyTemplate(_QuickTemplate t) async {
    setState(() {
      if (t.merchant.isNotEmpty) {
        _contentController.text = t.merchant;
      }
      _categoryId = t.categoryId;
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) return;

    final content = _contentController.text.trim();
    final isIncome = _isIncome;
    final cents = (amount * 100).round();
    final effectiveCategoryId = _categoryId ?? _suggestedCategoryId;
    final catName = await _categoryNameById(effectiveCategoryId);
    final autoMemo = content.isEmpty
        ? ((catName?.trim().isNotEmpty ?? false) ? catName!.trim() : null)
        : null;

    late final String savedTxId;
    if (_isEdit) {
      final tx = widget.initialTx!;
      savedTxId = tx.id;
      await (db.update(
        db.transactions,
      )..where((t) => t.id.equals(tx.id))).write(
        TransactionsCompanion(
          direction: d.Value(isIncome ? 'income' : 'expense'),
          amountCents: d.Value(cents),
          occurredAt: d.Value(_occurredAt),
          categoryId: d.Value(effectiveCategoryId),
          merchant: d.Value(content.isEmpty ? null : content),
          memo: content.isEmpty ? d.Value(autoMemo) : const d.Value.absent(),
          updatedAt: d.Value(DateTime.now()),
        ),
      );
    } else {
      final id = _uuid.v4();
      savedTxId = id;
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: id,
              accountId: widget.accountId ?? 1,
              direction: d.Value(isIncome ? 'income' : 'expense'),
              amountCents: cents,
              occurredAt: _occurredAt,
              currency: d.Value(
                (widget.accountCurrency ?? 'USD').toUpperCase(),
              ),
              categoryId: d.Value(effectiveCategoryId),
              merchant: d.Value(content.isEmpty ? null : content),
              memo: d.Value(autoMemo),
            ),
          );
    }
    widget.onSavedTransactionId?.call(savedTxId);

    final pet = PetBus.controller;
    if (pet != null && !_isEdit) {
      final talker = PetTalker(pet);
      final catName = await _categoryNameById(_categoryId);
      final locale = Localizations.localeOf(context);
      talker.onTransactionAdded(
        kind: isIncome ? TxKind.income : TxKind.expense,
        amountCents: cents,
        categoryName: catName,
        locale: locale,
      );
    }

    if (!mounted) return;
    if (_isTutorialMode) {
      Navigator.pop(context, TutorialChapterResult.completed);
      return;
    }
    Navigator.pop(context, true);
  }

  String _categoryDisplayName(BuildContext context, String raw) {
    final translated = categoryLabel(context, raw);
    if (translated != raw) return translated;

    final isZh = Localizations.localeOf(
      context,
    ).languageCode.toLowerCase().startsWith('zh');
    if (!isZh) return raw;

    const zhFallback = <String, String>{
      'Food': '椁愰ギ',
      'Dining': '椁愰ギ',
      'Groceries': '鏉傝揣',
      'Shopping': '璐墿',
      'Transport': '交通',
      'Transportation': '交通',
      'Gas': '鍔犳补',
      'Fuel': '鍔犳补',
      'Rent': '鎴跨',
      'Utilities': '姘寸數鐕冩皵',
      'Electricity': '鐢佃垂',
      'Water': '姘磋垂',
      'Internet': '缃戠粶',
      'Phone': '璇濊垂',
      'Entertainment': '濞变箰',
      'Healthcare': '鍖荤枟',
      'Medical': '鍖荤枟',
      'Pharmacy': '鑽搧',
      'Insurance': '淇濋櫓',
      'Travel': '鏃呰',
      'Education': '鏁欒偛',
      'Pets': '瀹犵墿',
      'Gift': '绀肩墿',
      'Gifts': '绀肩墿',
      'Other': '鍏朵粬',
      'Salary': '宸ヨ祫',
      'Wages': '宸ヨ祫',
      'Bonus': '濂栭噾',
      'Interest': '鍒╂伅',
      'Investment': '鎶曡祫',
      'Investments': '鎶曡祫',
      'Refund': '退款',
      'Reimbursement': '鎶ラ攢',
      'Transfer': '杞处',
    };

    return zhFallback[raw.trim()] ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _isIncome
        ? at(context, 'Income')
        : at(context, 'Expense');
    final title = _isEdit ? at(context, 'Edit') : at(context, 'Add');

    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldTextStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final hintStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.45),
    );

    InputDecoration semiDec({required String label, Widget? suffix}) {
      final base = InputDecoration(
        labelText: label,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isIncome ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
      );
      if (suffix == null) return base;
      return base.copyWith(suffixIcon: suffix);
    }

    final page = Scaffold(
      appBar: AppBar(title: Text('$title $typeLabel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KeyedSubtree(
            key: _tutorialDateKey,
            child: InkWell(
              onTap: _pickDateOnly,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: semiDec(
                  label: at(context, 'Date'),
                  suffix: const Icon(Icons.edit_calendar_rounded),
                ),
                child: Text(_fmtDate(_occurredAt), style: fieldTextStyle),
              ),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _tutorialTypeKey,
            child: SegmentedButton<bool>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (!states.contains(WidgetState.selected)) return null;
                  return _isIncome
                      ? Colors.green.withValues(alpha: 0.18)
                      : Colors.red.withValues(alpha: 0.18);
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                  states,
                ) {
                  if (isDark) return Colors.white;
                  if (!states.contains(WidgetState.selected)) return null;
                  return _isIncome ? Colors.green : Colors.red;
                }),
                side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
                  if (!states.contains(WidgetState.selected)) {
                    return const BorderSide(color: Colors.grey);
                  }
                  return BorderSide(
                    color: _isIncome ? Colors.green : Colors.red,
                    width: 1.5,
                  );
                }),
              ),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(
                    at(context, 'Expense'),
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    at(context, 'Income'),
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
              selected: {_isIncome},
              onSelectionChanged: (s) {
                setState(() {
                  _isIncome = s.first;
                  _categoryId = null;
                  _suggestedCategoryId = null;
                });
                unawaited(_loadQuickTemplates());
                _scheduleSuggest();
              },
            ),
          ),
          Builder(
            builder: (context) {
              if (_quickTemplates.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in _quickTemplates)
                      ActionChip(
                        avatar: const Icon(Icons.flash_on_rounded, size: 16),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            t.merchant.isEmpty
                                ? at(context, 'Quick Template')
                                : t.merchant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () => _applyTemplate(t),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _tutorialAmountKey,
            child: TextField(
              controller: _amountController,
              style: fieldTextStyle,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: semiDec(label: at(context, 'Amount')),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _tutorialCategoryKey,
            child: FutureBuilder<List<Category>>(
              future: _loadCategories(),
              builder: (context, snapshot) {
                final cats = snapshot.data ?? const <Category>[];

                Category? selected;
                for (final c in cats) {
                  if (c.id == _categoryId) {
                    selected = c;
                    break;
                  }
                }

                final selectedText = selected == null
                    ? ''
                    : _categoryDisplayName(context, selected.name);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_suggestedCategoryId != null &&
                        _suggestedCategoryId != _categoryId) ...[
                      Builder(
                        builder: (_) {
                          final hit = cats
                              .where((c) => c.id == _suggestedCategoryId)
                              .toList();
                          if (hit.isEmpty) return const SizedBox.shrink();
                          final suggestedName = _categoryDisplayName(
                            context,
                            hit.first.name,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Card(
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.auto_awesome_rounded),
                                title: Text(
                                  at(
                                    context,
                                    'Suggested category: $suggestedName',
                                  ),
                                ),
                                subtitle: Text(
                                  at(
                                    context,
                                    'Based on your history for similar content',
                                  ),
                                ),
                                trailing: TextButton(
                                  onPressed: () {
                                    setState(() => _categoryId = hit.first.id);
                                  },
                                  child: Text(at(context, 'Use')),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    InkWell(
                      onTap: _toggleCategoryExpanded,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: semiDec(
                          label: at(context, 'Category'),
                          suffix: Icon(
                            _catExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                          ),
                        ),
                        child: Text(
                          selectedText.isEmpty
                              ? at(context, 'Select')
                              : selectedText,
                          style: selectedText.isEmpty
                              ? hintStyle
                              : fieldTextStyle,
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: !_catExpanded
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            at(context, 'Categories'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => setState(
                                            () => _catManageMode =
                                                !_catManageMode,
                                          ),
                                          child: Text(
                                            _catManageMode
                                                ? at(context, 'Done')
                                                : at(context, 'Edit'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (_catManageMode) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _newCatController,
                                              style: fieldTextStyle,
                                              decoration: semiDec(
                                                label: at(
                                                  context,
                                                  'New category',
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          FilledButton(
                                            onPressed: () async {
                                              final name =
                                                  _newCatController.text;
                                              _newCatController.clear();
                                              await _addCategory(name);
                                              setState(() {});
                                            },
                                            child: Text(at(context, 'Add')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 240,
                                        ),
                                        child: ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: cats.length,
                                          separatorBuilder: (_, __) => Divider(
                                            height: 1,
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                          ),
                                          itemBuilder: (ctx, i) {
                                            final c = cats[i];
                                            final name = _categoryDisplayName(
                                              context,
                                              c.name,
                                            );
                                            return ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : null,
                                                ),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () async {
                                                  await _deleteCategory(c.id);
                                                  setState(() {});
                                                },
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _categoryId = c.id;
                                                  _catExpanded = false;
                                                  _catManageMode = false;
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ] else ...[
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (final c in cats)
                                            ChoiceChip(
                                              showCheckmark: false,
                                              label: Text(
                                                _categoryDisplayName(
                                                  context,
                                                  c.name,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark
                                                      ? Colors.white
                                                      : (_categoryId == c.id)
                                                      ? (_isIncome
                                                            ? Colors.green
                                                            : Colors.red)
                                                      : Colors.black87,
                                                ),
                                              ),
                                              selected: _categoryId == c.id,
                                              selectedColor:
                                                  (_isIncome
                                                          ? Colors.green
                                                          : Colors.red)
                                                      .withValues(alpha: 0.18),
                                              backgroundColor: scheme.surface,
                                              side: BorderSide(
                                                color: Colors.black.withValues(
                                                  alpha: 0.10,
                                                ),
                                              ),
                                              onSelected: (_) {
                                                setState(() {
                                                  _categoryId = c.id;
                                                  _catExpanded = false;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _tutorialContentKey,
            child: TextField(
              controller: _contentController,
              style: fieldTextStyle,
              decoration: semiDec(label: at(context, 'Content')),
            ),
          ),
          const SizedBox(height: 20),
          KeyedSubtree(
            key: _tutorialSaveKey,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _isIncome ? Colors.green : Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _save,
              child: Text(_isEdit ? at(context, 'Save') : at(context, 'Add')),
            ),
          ),
        ],
      ),
    );

    if (!_isTutorialMode) return page;
    return Stack(children: [page, _buildAddTutorialOverlay(context)]);
  }
}

class _QuickTemplate {
  final int? categoryId;
  final String merchant;

  const _QuickTemplate({required this.categoryId, required this.merchant});
}

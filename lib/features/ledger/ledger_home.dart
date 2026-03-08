import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/currency.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../data/db/app_database.dart';
import 'ledger_home_texts.dart';
import '../../l10n/category_i18n.dart';
import '../onboarding/coach_overlay.dart';
import '../onboarding/home_tutorial_controller.dart';
import '../onboarding/onboarding_manager.dart';

import 'add_transaction_page.dart';
import 'models.dart';

import '../reports/history_page.dart';
import '../reports/deep_analysis_page.dart';
import '../settings/settings_page.dart';
import '../import/external_bill_import_page.dart';

import 'recurring_transaction_service.dart';
import 'widgets/balance_card.dart';
import 'widgets/category_manage_page.dart';
import 'ledger_list_entries.dart';
import 'widgets/monthly_stats_page.dart';
import 'widgets/ledger_tx_list_area.dart';
import 'widgets/tx_detail_page.dart';
import 'widgets/ledger_quick_actions.dart';
import 'widgets/ledger_search_panel.dart';
import 'widgets/account_manage_page.dart';
import 'widgets/recurring_transactions_page.dart';

// New small widgets (split out from this file)
import 'widgets/ledger_drawer_shell.dart';
import 'widgets/ledger_side_menu.dart';
import '../../services/cloud_bill_sync_service.dart';
import '../../services/app_log.dart';

class LedgerHome extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onToggleLocale;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;
  final String? themeBackgroundImagePath;
  final ValueChanged<String?> onThemeBackgroundImageChanged;
  final double themeBackgroundMist;
  final ValueChanged<double> onThemeBackgroundMistChanged;

  const LedgerHome({
    super.key,
    required this.db,
    required this.onToggleLocale,
    required this.onToggleTheme,
    required this.isDarkMode,
    required this.themeStyle,
    required this.onThemeStyleChanged,
    required this.themeBackgroundImagePath,
    required this.onThemeBackgroundImageChanged,
    required this.themeBackgroundMist,
    required this.onThemeBackgroundMistChanged,
  });

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> with TickerProviderStateMixin {
  static const bool _homeTutorialEnabled = false;
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
  Timer? _recurringTimer;
  String _qaSlot3 = 'stats';
  String _qaSlot4 = 'history';
  bool _showSearch = false;
  LedgerFilterState _filter = const LedgerFilterState();
  int? _currentAccountId;
  String _currentAccountCurrency = 'USD';
  static const String _kCurrentAccountPref = 'ledger_current_account_id';
  final OnboardingManager _onboardingManager = OnboardingManager();
  late final HomeTutorialController _homeTutorialController;
  bool _didCheckHomeTutorial = false;
  bool _tutorialShouldMarkDone = false;
  bool _tutorialStateCaptured = false;
  bool _tutorialPrevShowSearch = false;
  bool _tutorialPrevSelectMode = false;
  Set<String> _tutorialPrevSelectedIds = <String>{};

  final GlobalKey _tutorialAddButtonKey = GlobalKey(
    debugLabel: 'tutorial_add_button',
  );
  final GlobalKey _tutorialSearchButtonKey = GlobalKey(
    debugLabel: 'tutorial_search_button',
  );
  final GlobalKey _tutorialSlot3ButtonKey = GlobalKey(
    debugLabel: 'tutorial_slot3_button',
  );
  final GlobalKey _tutorialSlot4ButtonKey = GlobalKey(
    debugLabel: 'tutorial_slot4_button',
  );
  final GlobalKey _tutorialSearchPanelKey = GlobalKey(
    debugLabel: 'tutorial_search_panel',
  );
  final GlobalKey _tutorialFirstTxKey = GlobalKey(
    debugLabel: 'tutorial_first_tx',
  );
  final GlobalKey _tutorialBatchSelectKey = GlobalKey(
    debugLabel: 'tutorial_batch_select',
  );
  final GlobalKey _tutorialBatchDeleteKey = GlobalKey(
    debugLabel: 'tutorial_batch_delete',
  );
  final GlobalKey _homeOverlayStackKey = GlobalKey(
    debugLabel: 'home_overlay_stack',
  );
  late final AnimationController _qaBubbleCtrl;
  int? _qaEditingSlot;
  Rect? _qaBubbleAnchorRect;
  bool _cloudSyncing = false;

  Future<void> _syncDeletedTxsToCloud(List<Transaction> deletedTxs) async {
    if (deletedTxs.isEmpty) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.deleteTransactionsFromCloudByLocal(deletedTxs);
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    }
  }

  Future<void> _downloadCloudNow({required String reason}) async {
    if (_cloudSyncing) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _cloudSyncing = true;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.downloadFromCloudNow(reason: reason);
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    } finally {
      _cloudSyncing = false;
    }
  }

  Future<void> _uploadSingleTxToCloud(
    String txId, {
    required String reason,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.uploadSingleLocalTransaction(
        localTransactionId: txId,
        reason: reason,
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    }
  }

  Future<void> _uploadCreatedAccountToCloud(Account account) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.uploadCreatedAccount(
        account: account,
        reason: 'account_create',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    }
  }

  Future<void> _uploadUpdatedAccountToCloud(
    Account oldAccount,
    Account newAccount,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.uploadUpdatedAccount(
        oldAccount: oldAccount,
        newAccount: newAccount,
        reason: 'account_update',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    }
  }

  Future<void> _uploadDeletedAccountToCloud(Account account) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final svc = CloudBillSyncService(
        db: widget.db,
        client: Supabase.instance.client,
      );
      await svc.uploadDeletedAccount(
        account: account,
        reason: 'account_delete',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
    }
  }

  Future<void> _handleExternalImportSync(
    ExternalImportSyncPayload? payload, {
    required String reason,
  }) async {
    if (payload == null) return;
    for (final id in payload.insertedTransactionIds) {
      await _uploadSingleTxToCloud(id, reason: reason);
    }
  }

  Future<void> _onHomePullToRefresh() async {
    await _downloadCloudNow(reason: 'pull_refresh');
    if (!mounted) return;
    setState(() {});
  }

  void _openStats() => _pageCtrl.animateToPage(
    1,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );
  void _openHome() => _pageCtrl.animateToPage(
    0,
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  void _refreshHome() {
    if (!mounted) return;
    setState(() {});
  }

  void _openDrawer() =>
      _drawerCtrl.animateTo(1.0, duration: _drawerDur, curve: _drawerCurve);
  void _closeDrawer() =>
      _drawerCtrl.animateTo(0.0, duration: _drawerDur, curve: _drawerCurve);

  @override
  void initState() {
    super.initState();
    _drawerCtrl = AnimationController(vsync: this, duration: _drawerDur);
    _qaBubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _pageCtrl = PageController(initialPage: 0);
    _homeTutorialController = HomeTutorialController(
      onFinish: ({required bool skipped}) async {
        _restoreUiAfterTutorial();
        if (_tutorialShouldMarkDone) {
          await _onboardingManager.markHomeTutorialDone();
          _tutorialShouldMarkDone = false;
        }
      },
    );
    _loadQuickActions();
    _initCurrentAccount();
    unawaited(_applyRecurringForAllAccounts());
    _recurringTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_applyRecurringForAllAccounts());
    });
    if (_homeTutorialEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeStartHomeTutorial());
      });
    }
  }

  @override
  void dispose() {
    _recurringTimer?.cancel();
    _drawerCtrl.dispose();
    _qaBubbleCtrl.dispose();
    _pageCtrl.dispose();
    _homeTutorialController.dispose();
    super.dispose();
  }

  String _fmtDay(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  String _fmtTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}';
  }

  Future<int> _ensureDefaultAccount() async {
    final existing =
        await (widget.db.select(widget.db.accounts)
              ..where((a) => a.isActive.equals(true))
              ..orderBy([(a) => d.OrderingTerm(expression: a.id)]))
            .get();
    if (existing.isNotEmpty) {
      return existing.first.id;
    }
    final id = await widget.db
        .into(widget.db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Default',
            type: d.Value('cash'),
            currency: d.Value('USD'),
          ),
        );
    return id;
  }

  Future<void> _initCurrentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final fallback = await _ensureDefaultAccount();
    final prefId = prefs.getInt(_kCurrentAccountPref);

    int selected = fallback;
    if (prefId != null) {
      final hit =
          await (widget.db.select(widget.db.accounts)
                ..where((a) => a.id.equals(prefId) & a.isActive.equals(true)))
              .getSingleOrNull();
      if (hit != null) selected = hit.id;
    }

    await prefs.setInt(_kCurrentAccountPref, selected);
    final current = await (widget.db.select(
      widget.db.accounts,
    )..where((a) => a.id.equals(selected))).getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _currentAccountId = selected;
      _currentAccountCurrency = (current?.currency ?? 'USD').toUpperCase();
    });
  }

  Future<void> _setCurrentAccount(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kCurrentAccountPref, accountId);
    final current = await (widget.db.select(
      widget.db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _currentAccountId = accountId;
      _currentAccountCurrency = (current?.currency ?? 'USD').toUpperCase();
      _filter = const LedgerFilterState();
    });
    await _applyRecurringForAccount(accountId);
    _refreshHome();
  }

  Future<void> _applyRecurringForAllAccounts() async {
    final inserted = await RecurringTransactionService.applyDueForAllAccounts(
      widget.db,
    );
    if (inserted > 0 && mounted) {
      _refreshHome();
    }
  }

  Future<void> _applyRecurringForAccount(int accountId) async {
    final account = await (widget.db.select(
      widget.db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (account == null) return;
    final inserted = await RecurringTransactionService.applyDueForAccount(
      widget.db,
      accountId: accountId,
      accountCurrency: account.currency.toUpperCase(),
    );
    if (inserted > 0 && mounted) {
      _refreshHome();
    }
  }

  Future<void> _switchAccountFromSheet() async {
    final accounts =
        await (widget.db.select(widget.db.accounts)
              ..where((a) => a.isActive.equals(true))
              ..orderBy([
                (a) => d.OrderingTerm(expression: a.sortOrder),
                (a) => d.OrderingTerm(expression: a.id),
              ]))
            .get();
    if (!mounted || accounts.isEmpty) return;

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: accounts.length,
              separatorBuilder: (_, unused) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = accounts[i];
                final selected = a.id == _currentAccountId;
                return ListTile(
                  title: Text(a.name),
                  subtitle: Text(
                    '${a.type.toUpperCase()}  |  ${a.currency.toUpperCase()}',
                  ),
                  tileColor: selected
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.35)
                      : null,
                  trailing: selected ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(context, a.id),
                );
              },
            ),
          ),
        );
      },
    );
    if (picked == null || picked == _currentAccountId) return;
    await _setCurrentAccount(picked);
  }

  List<TxViewRow> _applyFilters(List<TxViewRow> input) {
    String norm(String s) => s.toLowerCase().trim();
    String two(int n) => n.toString().padLeft(2, '0');
    String fmtDt(DateTime dt) =>
        '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';

    final keyword = norm(_filter.keyword);
    final range = _filter.range;
    final categoryId = _filter.categoryId;
    final tokens = keyword
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return input
        .where((row) {
          if (categoryId != null && row.tx.categoryId != categoryId) {
            return false;
          }

          if (range != null) {
            final start = DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
            );
            final endExclusive = DateTime(
              range.end.year,
              range.end.month,
              range.end.day,
            ).add(const Duration(days: 1));
            final t = row.tx.occurredAt;
            if (t.isBefore(start) || !t.isBefore(endExclusive)) {
              return false;
            }
          }

          if (tokens.isNotEmpty) {
            final categoryNameRaw = row.category?.name ?? '';
            final categoryNameI18n = categoryLabel(context, categoryNameRaw);
            final amount = (row.tx.amountCents / 100.0);
            final fields = <String>[
              row.tx.id,
              row.tx.source,
              row.tx.sourceId ?? '',
              row.tx.direction,
              row.tx.currency,
              row.tx.merchant ?? '',
              row.tx.memo ?? '',
              categoryNameRaw,
              categoryNameI18n,
              amount.toStringAsFixed(2),
              amount.toStringAsFixed(0),
              fmtDt(row.tx.occurredAt),
              '${row.tx.occurredAt.year}-${two(row.tx.occurredAt.month)}-${two(row.tx.occurredAt.day)}',
              row.tx.direction == 'income'
                  ? 'income 鏀跺叆'
                  : (row.tx.direction == 'expense'
                        ? 'expense 鏀嚭'
                        : 'pending 待处理'),
            ].map(norm).toList(growable: false);

            final hitAllTokens = tokens.every((token) {
              return fields.any((f) => f.contains(token));
            });
            if (!hitAllTokens) return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  Future<void> _loadQuickActions() async {
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

  Future<void> _saveQuickActions() async {
    const kQaSlot3 = 'qa_slot3';
    const kQaSlot4 = 'qa_slot4';
    final p = await SharedPreferences.getInstance();
    await p.setString(kQaSlot3, _qaSlot3);
    await p.setString(kQaSlot4, _qaSlot4);
  }

  List<_QaOption> _qaOptions(BuildContext context) {
    return [
      _QaOption(
        key: 'stats',
        icon: Icons.bar_chart_rounded,
        label: lht(context, 'Stats'),
      ),
      _QaOption(
        key: 'history',
        icon: Icons.history_rounded,
        label: lht(context, 'History'),
      ),
      _QaOption(
        key: 'categories',
        icon: Icons.category_rounded,
        label: lht(context, 'Categories'),
      ),
      _QaOption(
        key: 'settings',
        icon: Icons.settings_rounded,
        label: lht(context, 'Settings'),
      ),
      _QaOption(
        key: 'switchAccount',
        icon: Icons.swap_horiz_rounded,
        label: lht(context, 'Switch Account'),
      ),
      _QaOption(
        key: 'manageAccounts',
        icon: Icons.account_balance_wallet_rounded,
        label: lht(context, 'Manage Accounts'),
      ),
      _QaOption(
        key: 'recurring',
        icon: Icons.repeat_rounded,
        label: lht(context, 'Recurring'),
      ),
      _QaOption(
        key: 'analysis',
        icon: Icons.insights_rounded,
        label: lht(context, 'Analysis'),
      ),
      _QaOption(
        key: 'externalImport',
        icon: Icons.file_upload_rounded,
        label: lht(context, 'External Import'),
      ),
    ];
  }

  Future<void> _openQuickActionEditor(int slot) async {
    if (_homeTutorialController.isRunning) return;
    if (!mounted) return;
    setState(() {
      _qaEditingSlot = slot;
      _qaBubbleAnchorRect = null;
    });
    await _waitForNextFrame();
    if (!mounted) return;
    setState(() {
      _qaBubbleAnchorRect = _quickActionAnchorRect(slot);
    });
    await _qaBubbleCtrl.forward(from: 0);
  }

  Future<void> _closeQuickActionEditor() async {
    if (_qaEditingSlot == null) return;
    await _qaBubbleCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _qaEditingSlot = null;
      _qaBubbleAnchorRect = null;
    });
  }

  Rect? _quickActionAnchorRect(int slot) {
    final targetKey = slot == 3
        ? _tutorialSlot3ButtonKey
        : _tutorialSlot4ButtonKey;
    final targetRect = _widgetRect(targetKey);
    if (targetRect == null) return null;
    final stackContext = _homeOverlayStackKey.currentContext;
    if (stackContext == null) return targetRect;
    final stackRo = stackContext.findRenderObject();
    if (stackRo is! RenderBox || !stackRo.hasSize) return targetRect;
    final topLeft = stackRo.globalToLocal(targetRect.topLeft);
    final bottomRight = stackRo.globalToLocal(targetRect.bottomRight);
    return Rect.fromPoints(topLeft, bottomRight);
  }

  Future<void> _applyQuickActionSelection(String selectedKey) async {
    final slot = _qaEditingSlot;
    if (slot == null) return;

    final old3 = _qaSlot3;
    final old4 = _qaSlot4;

    setState(() {
      if (slot == 3) {
        _qaSlot3 = selectedKey;
        if (selectedKey == old4) {
          _qaSlot4 = old3;
        }
      } else {
        _qaSlot4 = selectedKey;
        if (selectedKey == old3) {
          _qaSlot3 = old4;
        }
      }
      if (_qaSlot3 == _qaSlot4) {
        _qaSlot4 = _qaSlot3 == 'stats' ? 'history' : 'stats';
      }
    });

    await _saveQuickActions();
    await _closeQuickActionEditor();
  }

  _QaItem _resolveQa(BuildContext context, String key) {
    switch (key) {
      case 'switchAccount':
        return _QaItem(
          icon: Icons.swap_horiz_rounded,
          tooltip: lht(context, 'Switch Account'),
          onTap: () async {
            await _switchAccountFromSheet();
          },
        );
      case 'manageAccounts':
        return _QaItem(
          icon: Icons.account_balance_wallet_rounded,
          tooltip: lht(context, 'Manage Accounts'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AccountManagePage(
                  db: widget.db,
                  onAccountCreated: _uploadCreatedAccountToCloud,
                  onAccountUpdated: _uploadUpdatedAccountToCloud,
                  onAccountDeleted: _uploadDeletedAccountToCloud,
                ),
              ),
            );
            await _initCurrentAccount();
          },
        );
      case 'recurring':
        return _QaItem(
          icon: Icons.repeat_rounded,
          tooltip: lht(context, 'Recurring'),
          onTap: () async {
            if (_currentAccountId == null) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecurringTransactionsPage(
                  db: widget.db,
                  accountId: _currentAccountId!,
                  accountCurrency: _currentAccountCurrency,
                ),
              ),
            );
            await _applyRecurringForAccount(_currentAccountId!);
            _refreshHome();
          },
        );
      case 'analysis':
        return _QaItem(
          icon: Icons.insights_rounded,
          tooltip: lht(context, 'Analysis'),
          onTap: () async {
            if (_currentAccountId == null) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeepAnalysisPage(
                  db: widget.db,
                  accountId: _currentAccountId!,
                  accountCurrency: _currentAccountCurrency,
                ),
              ),
            );
            _refreshHome();
          },
        );
      case 'externalImport':
        return _QaItem(
          icon: Icons.file_upload_rounded,
          tooltip: lht(context, 'External Import'),
          onTap: () async {
            if (_currentAccountId == null) return;
            final imported = await Navigator.push<ExternalImportSyncPayload>(
              context,
              MaterialPageRoute(
                builder: (_) => ExternalBillImportPage(
                  db: widget.db,
                  accountId: _currentAccountId!,
                ),
              ),
            );
            if (imported != null) {
              await _handleExternalImportSync(
                imported,
                reason: 'external_import',
              );
              _refreshHome();
            }
          },
        );
      case 'history':
        return _QaItem(
          icon: Icons.history_rounded,
          tooltip: lht(context, 'History'),
          onTap: () async {
            if (_currentAccountId == null) return;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryPage(
                  db: widget.db,
                  accountId: _currentAccountId!,
                  accountCurrency: _currentAccountCurrency,
                ),
              ),
            );
            _refreshHome();
          },
        );
      case 'categories':
        return _QaItem(
          icon: Icons.category_rounded,
          tooltip: lht(context, 'Categories'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CategoryManagePage(db: widget.db),
              ),
            );
            _refreshHome();
          },
        );
      case 'settings':
        return _QaItem(
          icon: Icons.settings_rounded,
          tooltip: lht(context, 'Settings'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  db: widget.db,
                  accountId: _currentAccountId!,
                  onToggleLocale: widget.onToggleLocale,
                  isDarkMode: widget.isDarkMode,
                  onToggleThemeMode: widget.onToggleTheme,
                  activeThemeStyle: widget.themeStyle,
                  onThemeStyleChanged: widget.onThemeStyleChanged,
                  themeBackgroundImagePath: widget.themeBackgroundImagePath,
                  onThemeBackgroundImageChanged:
                      widget.onThemeBackgroundImageChanged,
                  themeBackgroundMist: widget.themeBackgroundMist,
                  onThemeBackgroundMistChanged:
                      widget.onThemeBackgroundMistChanged,
                ),
              ),
            );
            await _loadQuickActions();
            _refreshHome();
          },
        );
      case 'stats':
      default:
        return _QaItem(
          icon: Icons.bar_chart_rounded,
          tooltip: lht(context, 'Stats'),
          onTap: _openStats,
        );
    }
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

  void _captureTutorialUiState() {
    _tutorialStateCaptured = true;
    _tutorialPrevShowSearch = _showSearch;
    _tutorialPrevSelectMode = _selectMode;
    _tutorialPrevSelectedIds = Set<String>.from(_selectedIds);
  }

  void _restoreUiAfterTutorial() {
    if (!mounted || !_tutorialStateCaptured) return;
    setState(() {
      _showSearch = _tutorialPrevShowSearch;
      _selectMode = _tutorialPrevSelectMode;
      _selectedIds
        ..clear()
        ..addAll(_tutorialPrevSelectedIds);
    });
    _tutorialStateCaptured = false;
  }

  Future<void> _setTutorialSearchVisible(bool visible) async {
    if (!mounted) return;
    if (_showSearch == visible) {
      if (visible) {
        await Future<void>.delayed(const Duration(milliseconds: 260));
      }
      await _waitForNextFrame();
      return;
    }
    setState(() {
      _showSearch = visible;
    });
    await _waitForNextFrame();
    if (visible) {
      // Wait for AnimatedSize in the search panel to fully expand.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      await _waitForNextFrame();
    }
  }

  Future<void> _setTutorialBatchMode(bool enabled) async {
    if (!mounted) return;
    setState(() {
      if (enabled && _lastTxIds.isNotEmpty) {
        _selectMode = true;
        _selectedIds
          ..clear()
          ..add(_lastTxIds.first);
      } else {
        _selectedIds.clear();
        _selectMode = false;
      }
    });
    await _waitForNextFrame();
  }

  List<HomeTutorialStep> _buildHomeTutorialSteps(BuildContext context) {
    final hasTransactions = _lastTxIds.isNotEmpty;
    return <HomeTutorialStep>[
      HomeTutorialStep(
        id: 'welcome',
        title: lht(context, 'Home Tutorial'),
        message: lht(
          context,
          'This guide shows adding bills, editing/deleting, searching, batch delete, and quick actions.',
        ),
        onBeforeEnter: () async {
          await _setTutorialSearchVisible(false);
          await _setTutorialBatchMode(false);
        },
      ),
      HomeTutorialStep(
        id: 'add',
        anchorKey: _tutorialAddButtonKey,
        title: lht(context, 'Add Bill'),
        message: lht(context, 'Tap this button to create a new transaction.'),
      ),
      HomeTutorialStep(
        id: 'edit_delete',
        anchorKey: hasTransactions ? _tutorialFirstTxKey : null,
        title: lht(context, 'Edit / Delete'),
        message: hasTransactions
            ? lht(
                context,
                'Swipe right on a bill to edit, swipe left to delete.',
              )
            : lht(
                context,
                'No bill yet. Add one first, then you can swipe right to edit and left to delete.',
              ),
      ),
      HomeTutorialStep(
        id: 'search_button',
        anchorKey: _tutorialSearchButtonKey,
        title: lht(context, 'Open Search'),
        message: lht(
          context,
          'Tap search to expand/collapse the filter panel.',
        ),
      ),
      HomeTutorialStep(
        id: 'search_panel',
        anchorKey: _tutorialSearchPanelKey,
        title: lht(context, 'Search & Filters'),
        message: lht(
          context,
          'You can do fuzzy keyword search and combine date/category filters.',
        ),
        onBeforeEnter: () async => _setTutorialSearchVisible(true),
      ),
      HomeTutorialStep(
        id: 'batch_delete',
        anchorKey: hasTransactions ? _tutorialBatchSelectKey : null,
        secondaryAnchorKey: hasTransactions ? _tutorialBatchDeleteKey : null,
        title: lht(context, 'Batch Delete'),
        message: hasTransactions
            ? lht(
                context,
                'Long-press a bill to enter selection mode, then use Select all / Delete in the top bar.',
              )
            : lht(
                context,
                'Batch delete appears after long-pressing at least one bill.',
              ),
        onBeforeEnter: () async => _setTutorialBatchMode(hasTransactions),
      ),
      HomeTutorialStep(
        id: 'quick_actions',
        anchorKey: _tutorialSlot3ButtonKey,
        secondaryAnchorKey: _tutorialSlot4ButtonKey,
        title: lht(context, 'Customize Quick Actions'),
        message: lht(
          context,
          'Slot 3/4 quick actions can be customized from Settings.',
        ),
        onBeforeEnter: () async => _setTutorialBatchMode(false),
      ),
      HomeTutorialStep(
        id: 'finish',
        title: lht(context, 'All Set'),
        message: lht(
          context,
          'You can replay this tutorial anytime from the side menu.',
        ),
      ),
    ];
  }

  Future<void> _startHomeTutorial({
    required bool markDone,
    bool resetDoneFlag = false,
  }) async {
    if (!mounted) return;
    if (resetDoneFlag) {
      await _onboardingManager.resetHomeTutorial();
    }
    if (_homeTutorialController.isRunning) {
      await _homeTutorialController.skip();
    }
    if (!mounted) return;
    _openHome();
    _captureTutorialUiState();
    _tutorialShouldMarkDone = markDone;
    final steps = _buildHomeTutorialSteps(context);
    await _homeTutorialController.start(steps);
  }

  Future<void> _maybeStartHomeTutorial() async {
    if (_didCheckHomeTutorial) return;
    _didCheckHomeTutorial = true;
    final shouldShow = await _onboardingManager.shouldShowHomeTutorial();
    if (!mounted || !shouldShow) return;
    await _startHomeTutorial(markDone: true);
  }

  Widget _buildQuickActionEditorOverlay(BuildContext context) {
    final editingSlot = _qaEditingSlot;
    if (editingSlot == null) return const SizedBox.shrink();

    final anchor = _qaBubbleAnchorRect;
    final media = MediaQuery.of(context).size;
    final panelWidth = math.min(430.0, media.width - 16.0);
    final anchorCenterX = anchor?.center.dx ?? (media.width * 0.5);
    final anchorCenterY = anchor?.center.dy ?? (media.height * 0.5);
    final anchorBottomY = anchor?.bottom ?? anchorCenterY;
    final options = _qaOptions(context);
    final currentKey = editingSlot == 3 ? _qaSlot3 : _qaSlot4;
    final currentLabel = options
        .firstWhere((e) => e.key == currentKey, orElse: () => options.first)
        .label;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _qaBubbleCtrl,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_qaBubbleCtrl.value);
          final startTop = anchorCenterY + 4;
          final endTop = anchorBottomY + 14;
          final bubbleTop = lerpDouble(startTop, endTop, t) ?? endTop;
          final minLeft = 8.0;
          final maxLeft = math.max(minLeft, media.width - panelWidth - 8.0);
          final bubbleLeft = (anchorCenterX - panelWidth / 2).clamp(
            minLeft,
            maxLeft,
          );

          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => unawaited(_closeQuickActionEditor()),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.4 * t, sigmaY: 2.4 * t),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.12 * t),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: bubbleLeft,
                top: bubbleTop,
                child: Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.72 + (0.28 * t),
                    alignment: Alignment.topCenter,
                    child: _QuickActionBubble(
                      width: panelWidth,
                      titleLeft: lht(context, 'Edit Button $editingSlot'),
                      titleRight: lht(context, 'Current: $currentLabel'),
                      options: options,
                      selectedKey: currentKey,
                      onSelect: (key) =>
                          unawaited(_applyQuickActionSelection(key)),
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

  Widget _buildTutorialOverlay(BuildContext context) {
    if (!_homeTutorialEnabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _homeTutorialController,
      builder: (context, _) {
        final step = _homeTutorialController.currentStep;
        if (!_homeTutorialController.isRunning || step == null) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: CoachOverlay(
            targetRect: _tutorialTargetRect(step),
            title: step.title,
            message: step.message,
            index: _homeTutorialController.index + 1,
            total: _homeTutorialController.totalSteps,
            isLastStep: _homeTutorialController.isLastStep,
            onSkip: () => unawaited(_homeTutorialController.skip()),
            onNext: () => unawaited(_homeTutorialController.next()),
            onPrevious: _homeTutorialController.index > 0
                ? () => unawaited(_homeTutorialController.previous())
                : null,
            backLabel: lht(context, 'Back'),
            skipLabel: lht(context, 'Skip'),
            nextLabel: lht(context, 'Next'),
            doneLabel: lht(context, 'Done'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final onToggleLocale = widget.onToggleLocale;
    final currentAccountId = _currentAccountId;

    final query =
        (db.select(db.transactions)
              ..where((t) => t.accountId.equals(currentAccountId ?? -1))
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.occurredAt,
                  mode: d.OrderingMode.desc,
                ),
              ]))
            .join([
              d.leftOuterJoin(
                db.categories,
                db.categories.id.equalsExp(db.transactions.categoryId),
              ),
            ]);

    final stream = query.watch().map((rows) {
      return rows.map((r) {
        final tx = r.readTable(db.transactions);
        final cat = r.readTableOrNull(db.categories);
        return TxViewRow(tx: tx, category: cat);
      }).toList();
    });

    if (currentAccountId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WillPopScope(
      onWillPop: () async {
        if (_qaEditingSlot != null) {
          await _closeQuickActionEditor();
          return false;
        }
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
            return MonthlyStatsPage(
              db: db,
              accountId: currentAccountId,
              accountCurrency: _currentAccountCurrency,
              onBack: _openHome,
            );
          }

          Widget buildScaffold() {
            final hasCustomBg =
                widget.themeBackgroundImagePath != null &&
                widget.themeBackgroundImagePath!.isNotEmpty;
            return Scaffold(
              backgroundColor: hasCustomBg
                  ? Colors.transparent
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              appBar: AppBar(
                leading: _selectMode
                    ? IconButton(
                        tooltip: lht(context, 'Cancel'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _selectedIds.clear();
                            _selectMode = false;
                          });
                        },
                      )
                    : IconButton(
                        tooltip: lht(context, 'Menu'),
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: _openDrawer,
                      ),
                title: Text(
                  _selectMode
                      ? lht(context, 'Selected ${_selectedIds.length}')
                      : lht(context, 'Ledger'),
                ),
                actions: [
                  if (_selectMode) ...[
                    KeyedSubtree(
                      key: _tutorialBatchSelectKey,
                      child: IconButton(
                        tooltip: lht(context, 'Select all'),
                        icon: const Icon(Icons.select_all),
                        onPressed: () {
                          setState(() {
                            _selectedIds
                              ..clear()
                              ..addAll(_lastTxIds);
                          });
                        },
                      ),
                    ),
                    KeyedSubtree(
                      key: _tutorialBatchDeleteKey,
                      child: IconButton(
                        tooltip: lht(context, 'Delete'),
                        icon: const Icon(Icons.delete_forever),
                        onPressed: _selectedIds.isEmpty
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(
                                      lht(context, 'Delete selected?'),
                                    ),
                                    content: Text(
                                      lht(context, 'This cannot be undone.'),
                                    ),
                                    actionsPadding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    actionsAlignment: MainAxisAlignment.end,
                                    actions: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          side: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                          ),
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surfaceVariant,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(lht(context, 'Cancel')),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          foregroundColor: Theme.of(
                                            context,
                                          ).colorScheme.onError,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(lht(context, 'Delete')),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;

                                final toDelete =
                                    await (db.select(db.transactions)..where(
                                          (t) =>
                                              t.id.isIn(_selectedIds.toList()),
                                        ))
                                        .get();
                                await (db.delete(db.transactions)..where(
                                      (t) => t.id.isIn(_selectedIds.toList()),
                                    ))
                                    .go();
                                unawaited(_syncDeletedTxsToCloud(toDelete));

                                if (!context.mounted) return;
                                setState(() {
                                  _selectedIds.clear();
                                  _selectMode = false;
                                });
                              },
                      ),
                    ),
                  ],
                ],
              ),
              body: StreamBuilder<List<TxViewRow>>(
                stream: stream,
                builder: (context, snapshot) {
                  final rawTxs = snapshot.data ?? const <TxViewRow>[];
                  final txs = _applyFilters(rawTxs);
                  _lastTxIds = txs.map((e) => e.tx.id).toList(growable: false);

                  int income = 0;
                  int expense = 0;
                  for (final r in txs) {
                    if (r.tx.direction == 'income') {
                      income += r.tx.amountCents;
                    } else if (r.tx.direction == 'expense') {
                      expense += r.tx.amountCents;
                    }
                  }
                  final balance = (income - expense) / 100.0;

                  final items = <LedgerListEntry>[];
                  String? currentDay;
                  for (final r in txs) {
                    final day = _fmtDay(r.tx.occurredAt);
                    if (day != currentDay) {
                      currentDay = day;
                      items.add(LedgerHeaderEntry(day));
                    }
                    items.add(LedgerTxEntry(r));
                  }

                  Widget txListPanel = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: RepaintBoundary(
                      key: _txListAreaKey,
                      child: Semantics(
                        label: 'transactions_list_area',
                        child: LedgerTxListArea(
                          txs: txs,
                          items: items,
                          firstTransactionKey: _tutorialFirstTxKey,
                          selectMode: _selectMode,
                          selectedIds: _selectedIds,
                          fmtTime: _fmtTime,
                          onEnterSelectWith: (id) {
                            setState(() {
                              _selectMode = true;
                              _selectedIds.add(id);
                            });
                          },
                          onToggleSelected: (id) {
                            setState(() {
                              if (_selectedIds.contains(id)) {
                                _selectedIds.remove(id);
                                if (_selectedIds.isEmpty) _selectMode = false;
                              } else {
                                _selectedIds.add(id);
                              }
                            });
                          },
                          onOpenTxDetail: (row) {
                            if (_selectMode) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TxDetailPage(row: row),
                              ),
                            );
                          },
                          onEditTx: (row) async {
                            if (_selectMode) return;
                            String? editedTxId;
                            final changed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => AddTransactionPage(
                                      db: db,
                                      accountId: currentAccountId,
                                      accountCurrency: _currentAccountCurrency,
                                      initialTx: row.tx,
                                      onSavedTransactionId: (id) {
                                        editedTxId = id;
                                      },
                                    ),
                                  ),
                                );
                            _refreshHome();
                            if (changed == true && editedTxId != null) {
                              unawaited(
                                _uploadSingleTxToCloud(
                                  editedTxId!,
                                  reason: 'edit_tx',
                                ),
                              );
                            }
                          },
                          onDeleteTx: (id) async {
                            if (_selectMode) return;
                            final localTx =
                                await (db.select(db.transactions)
                                      ..where((t) => t.id.equals(id))
                                      ..limit(1))
                                    .getSingleOrNull();
                            await (db.delete(
                              db.transactions,
                            )..where((t) => t.id.equals(id))).go();
                            if (localTx != null) {
                              unawaited(_syncDeletedTxsToCloud([localTx]));
                            }
                          },
                          onRefresh: _onHomePullToRefresh,
                        ),
                      ),
                    ),
                  );

                  Widget topPanel = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final qa3 = _resolveQa(context, _qaSlot3);
                        final qa4 = _resolveQa(context, _qaSlot4);
                        final actionsWidth = (c.maxWidth * 0.33).clamp(
                          120.0,
                          190.0,
                        );
                        final balanceActionGap = (c.maxWidth * 0.015).clamp(
                          8.0,
                          14.0,
                        );
                        final balanceWidth =
                            c.maxWidth - actionsWidth - balanceActionGap;
                        final panelHeight = balanceWidth * (2 / 3);
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: balanceWidth,
                                  child: AspectRatio(
                                    aspectRatio: 3 / 2,
                                    child: FutureBuilder<double?>(
                                      future: Settings.getMinBalance(
                                        accountId: currentAccountId,
                                      ),
                                      builder: (context, snap) {
                                        final minB = snap.data;
                                        final isLow =
                                            minB != null && balance < minB;
                                        return BalanceCard(
                                          balance: balance,
                                          currencySymbol: currencySymbol(
                                            _currentAccountCurrency,
                                          ),
                                          isLow: isLow,
                                          accentColor: isLow
                                              ? Colors.red
                                              : Colors.green,
                                          compact: true,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(width: balanceActionGap),
                                SizedBox(
                                  width: actionsWidth,
                                  height: panelHeight,
                                  child: LedgerQuickActions(
                                    isSearchOpen: _showSearch,
                                    searchButtonKey: _tutorialSearchButtonKey,
                                    addButtonKey: _tutorialAddButtonKey,
                                    slot3ButtonKey: _tutorialSlot3ButtonKey,
                                    slot4ButtonKey: _tutorialSlot4ButtonKey,
                                    onToggleSearch: () {
                                      setState(() {
                                        _showSearch = !_showSearch;
                                      });
                                    },
                                    onOpenAdd: () async {
                                      String? addedTxId;
                                      final changed =
                                          await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  AddTransactionPage(
                                                    db: db,
                                                    accountId: currentAccountId,
                                                    accountCurrency:
                                                        _currentAccountCurrency,
                                                    onSavedTransactionId: (id) {
                                                      addedTxId = id;
                                                    },
                                                  ),
                                            ),
                                          );
                                      _refreshHome();
                                      if (changed == true &&
                                          addedTxId != null) {
                                        unawaited(
                                          _uploadSingleTxToCloud(
                                            addedTxId!,
                                            reason: 'add_tx',
                                          ),
                                        );
                                      }
                                    },
                                    slot3Icon: qa3.icon,
                                    slot3Tooltip: qa3.tooltip,
                                    onSlot3: qa3.onTap,
                                    onSlot3LongPress: () =>
                                        unawaited(_openQuickActionEditor(3)),
                                    slot4Icon: qa4.icon,
                                    slot4Tooltip: qa4.tooltip,
                                    onSlot4: qa4.onTap,
                                    onSlot4LongPress: () =>
                                        unawaited(_openQuickActionEditor(4)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  );

                  Widget searchPanel = AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _showSearch
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                            child: LedgerSearchPanel(
                              db: db,
                              panelKey: _tutorialSearchPanelKey,
                              value: _filter,
                              onChanged: (next) {
                                setState(() {
                                  _filter = next;
                                });
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  );

                  final isLandscape =
                      MediaQuery.of(context).orientation ==
                      Orientation.landscape;
                  if (isLandscape) {
                    return Row(
                      children: [
                        SizedBox(
                          width: (constraints.maxWidth * 0.44).clamp(
                            360.0,
                            520.0,
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
                            child: Column(children: [topPanel, searchPanel]),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              Expanded(child: txListPanel),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      topPanel,
                      searchPanel,
                      const SizedBox(height: 12),
                      Expanded(child: txListPanel),
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
                final page = _pageCtrl.hasClients
                    ? (_pageCtrl.page ?? 0.0)
                    : 0.0;
                final t = page.clamp(0.0, 1.0);

                Widget shell({
                  required Widget child,
                  required double scale,
                  required double radius,
                }) {
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
                    if (i == 0) _refreshHome();
                  },
                  physics: _drawerCtrl.value > 0
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  children: [
                    shell(
                      child: buildScaffold(),
                      scale: homeScale,
                      radius: radius,
                    ),
                    shell(
                      child: buildStatsScaffold(),
                      scale: statsScale,
                      radius: radius,
                    ),
                  ],
                );
              },
            );
          }

          return Stack(
            key: _homeOverlayStackKey,
            children: [
              LedgerDrawerShell(
                controller: _drawerCtrl,
                drawerWidth: drawerWidth,
                edgeTriggerWidth: 70, // expand drag-to-open area here
                canOpen: !_selectMode,
                duration: _drawerDur,
                curve: _drawerCurve,
                onTapScrim: _closeDrawer,
                drawer: SafeArea(
                  child: LedgerSideMenu(
                    onSwitchAccount: () async {
                      _closeDrawer();
                      await _switchAccountFromSheet();
                    },
                    onManageAccounts: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountManagePage(
                            db: db,
                            onAccountCreated: _uploadCreatedAccountToCloud,
                            onAccountUpdated: _uploadUpdatedAccountToCloud,
                            onAccountDeleted: _uploadDeletedAccountToCloud,
                          ),
                        ),
                      );
                      await _initCurrentAccount();
                    },
                    onOpenStats: () {
                      _closeDrawer();
                      _openStats();
                    },
                    statsPageBuilder: (_) => MonthlyStatsPage(
                      db: widget.db,
                      accountId: currentAccountId,
                      accountCurrency: _currentAccountCurrency,
                    ),
                    onOpenHistory: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryPage(
                            db: widget.db,
                            accountId: currentAccountId,
                            accountCurrency: _currentAccountCurrency,
                          ),
                        ),
                      );
                      _refreshHome();
                    },
                    onOpenAnalysis: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeepAnalysisPage(
                            db: widget.db,
                            accountId: currentAccountId,
                            accountCurrency: _currentAccountCurrency,
                          ),
                        ),
                      );
                      _refreshHome();
                    },
                    onOpenRecurring: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecurringTransactionsPage(
                            db: widget.db,
                            accountId: currentAccountId,
                            accountCurrency: _currentAccountCurrency,
                          ),
                        ),
                      );
                      await _applyRecurringForAccount(currentAccountId);
                      _refreshHome();
                    },
                    onOpenCategories: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CategoryManagePage(db: widget.db),
                        ),
                      );
                      _refreshHome();
                    },
                    onOpenExternalImport: () async {
                      _closeDrawer();
                      final imported =
                          await Navigator.push<ExternalImportSyncPayload>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExternalBillImportPage(
                                db: widget.db,
                                accountId: currentAccountId,
                              ),
                            ),
                          );
                      if (imported != null) {
                        await _handleExternalImportSync(
                          imported,
                          reason: 'external_import',
                        );
                        _refreshHome();
                      }
                    },
                    onOpenSettings: () async {
                      _closeDrawer();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsPage(
                            db: widget.db,
                            accountId: currentAccountId,
                            onToggleLocale: onToggleLocale,
                            isDarkMode: widget.isDarkMode,
                            onToggleThemeMode: widget.onToggleTheme,
                            activeThemeStyle: widget.themeStyle,
                            onThemeStyleChanged: widget.onThemeStyleChanged,
                            themeBackgroundImagePath:
                                widget.themeBackgroundImagePath,
                            onThemeBackgroundImageChanged:
                                widget.onThemeBackgroundImageChanged,
                            themeBackgroundMist: widget.themeBackgroundMist,
                            onThemeBackgroundMistChanged:
                                widget.onThemeBackgroundMistChanged,
                          ),
                        ),
                      );
                      await _loadQuickActions();
                      _refreshHome();
                    },
                    onReplayTutorial: _homeTutorialEnabled
                        ? () {
                            _closeDrawer();
                            Future<void>.delayed(_drawerDur, () {
                              if (!mounted) return;
                              unawaited(
                                _startHomeTutorial(
                                  markDone: true,
                                  resetDoneFlag: true,
                                ),
                              );
                            });
                          }
                        : null,
                    onToggleTheme: widget.onToggleTheme,
                    onLogout: () async {
                      _closeDrawer();
                      await Supabase.instance.client.auth.signOut();
                      AppLog.i('Auth', 'Sign out completed');
                    },
                    isDarkMode: widget.isDarkMode,
                  ),
                ),
                content: buildPagedContent(),
              ),
              _buildQuickActionEditorOverlay(context),
              _buildTutorialOverlay(context),
            ],
          );
        },
      ),
    );
  }
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

class _QaOption {
  final String key;
  final IconData icon;
  final String label;

  const _QaOption({required this.key, required this.icon, required this.label});
}

class _QuickActionBubble extends StatelessWidget {
  final double width;
  final String titleLeft;
  final String titleRight;
  final List<_QaOption> options;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const _QuickActionBubble({
    required this.width,
    required this.titleLeft,
    required this.titleRight,
    required this.options,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titleLeft,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      titleRight,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final option = options[index];
                final selected = option.key == selectedKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(option.key),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.6)
                            : scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 20,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          option.label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

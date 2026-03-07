import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as d;

import '../../data/db/app_database.dart';
import '../../l10n/tr.dart';
import 'external_bill_record_detail_page.dart';
import 'external_bill_import_service.dart';

class ExternalImportSyncPayload {
  final List<String> insertedTransactionIds;

  const ExternalImportSyncPayload({required this.insertedTransactionIds});
}

class ExternalBillImportPage extends StatefulWidget {
  final AppDatabase db;
  final int? accountId;

  const ExternalBillImportPage({
    super.key,
    required this.db,
    required this.accountId,
  });

  @override
  State<ExternalBillImportPage> createState() => _ExternalBillImportPageState();
}

class _ExternalBillImportPageState extends State<ExternalBillImportPage> {
  late final ExternalBillImportService _service;
  PlatformFile? _pickedFile;
  ExternalBillParsedData? _parsed;
  List<Account> _accounts = const [];
  int? _selectedAccountId;
  bool _loadingAccounts = true;
  bool _parsing = false;
  bool _importing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = ExternalBillImportService(widget.db);
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final rows =
          await (widget.db.select(widget.db.accounts)
                ..where((a) => a.isActive.equals(true))
                ..orderBy([
                  (a) => d.OrderingTerm(expression: a.sortOrder),
                  (a) => d.OrderingTerm(expression: a.id),
                ]))
              .get();

      int? selected = widget.accountId;
      if (selected != null && !rows.any((a) => a.id == selected)) {
        selected = null;
      }
      selected ??= rows.isEmpty ? null : rows.first.id;

      if (!mounted) return;
      setState(() {
        _accounts = rows;
        _selectedAccountId = selected;
        _loadingAccounts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAccounts = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _pickFileAndAnalyze() async {
    setState(() {
      _error = null;
      _parsed = null;
      _pickedFile = null;
      _parsing = true;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'xlsx'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        if (!mounted) return;
        setState(() => _parsing = false);
        return;
      }

      final file = picked.files.single;
      final parsed = await _service.parsePickedFile(file);
      if (!mounted) return;
      setState(() {
        _pickedFile = file;
        _parsed = parsed;
        _parsing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _importNow() async {
    final parsed = _parsed;
    final accountId = _selectedAccountId;
    if (parsed == null || accountId == null) return;
    if (_hasCurrencyMismatch(parsed)) {
      setState(() {
        _error = tr(
          context,
          en: 'Account currency does not match bill currency.',
          zh: '账户币种与账单币种不一致，无法导入。',
        );
      });
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final r = await _service.importParsedData(
        accountId: accountId,
        parsed: parsed,
      );
      if (!mounted) return;
      final baseMsg = tr(
        context,
        en: 'Imported ${r.inserted}, skipped ${r.skipped}, failed ${r.failed}.',
        zh: '已导入 ${r.inserted} 条，跳过 ${r.skipped} 条，失败 ${r.failed} 条。',
      );
      final adjustMsg = r.hasBalanceAdjustment
          ? tr(
              context,
              en: 'Balance synchronized by ${(r.balanceAdjustedCents / 100.0).toStringAsFixed(2)} USD from latest PNC CSV balance.',
              zh: '已根据最新 PNC CSV 余额自动校准 ${(r.balanceAdjustedCents / 100.0).toStringAsFixed(2)} USD。',
            )
          : '';
      final msg = adjustMsg.isEmpty ? baseMsg : '$baseMsg\n$adjustMsg';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(
        context,
        ExternalImportSyncPayload(
          insertedTransactionIds: r.insertedTransactionIds,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = e.toString();
      });
    }
  }

  Account? get _selectedAccount {
    final id = _selectedAccountId;
    if (id == null) return null;
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool _hasCurrencyMismatch(ExternalBillParsedData? parsed) {
    if (parsed == null) return false;
    final account = _selectedAccount;
    if (account == null) return false;
    return account.currency.toUpperCase() != parsed.currency.toUpperCase();
  }

  String _fmtAmount(ExternalBillRecord r) {
    final abs = (r.amountCents.abs() / 100.0).toStringAsFixed(2);
    final sign = switch (r.direction) {
      'income' => '+',
      'expense' => '-',
      'pending' => r.pendingBaseDirection == 'income' ? '+' : '~',
      _ => '~',
    };
    return '$sign$abs ${r.currency}';
  }

  String _fmtDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _directionLabel(String direction) {
    return direction == 'income'
        ? tr(context, en: 'Income', zh: '收入')
        : tr(context, en: 'Expense', zh: '支出');
  }

  String _directionLabelEx(String direction) {
    switch (direction) {
      case 'income':
        return tr(context, en: 'Income', zh: '收入');
      case 'expense':
        return tr(context, en: 'Expense', zh: '支出');
      case 'pending':
        return tr(context, en: 'Pending', zh: '待处理');
      default:
        return direction;
    }
  }

  String _recordTitle(ExternalBillRecord r) {
    final t = (r.counterparty ?? '').trim();
    if (t.isNotEmpty) return t;
    final m = (r.memo ?? '').trim();
    if (m.isNotEmpty) return m;
    if (r.tradeType.trim().isNotEmpty) return r.tradeType.trim();
    return r.sourceId;
  }

  String _typeLabel(BuildContext context, ExternalBillType type) {
    switch (type) {
      case ExternalBillType.wechatPay:
        return tr(context, en: 'WeChat Pay', zh: '微信支付');
      case ExternalBillType.alipay:
        return tr(context, en: 'Alipay', zh: '支付宝');
      case ExternalBillType.unknown:
      case ExternalBillType.pnc:
        return tr(context, en: 'Unknown', zh: '未知');
    }
  }

  String _typeLabelEx(BuildContext context, ExternalBillType type) {
    switch (type) {
      case ExternalBillType.wechatPay:
        return tr(context, en: 'WeChat Pay', zh: '微信支付');
      case ExternalBillType.alipay:
        return tr(context, en: 'Alipay', zh: '支付宝');
      case ExternalBillType.pnc:
        return tr(context, en: 'PNC Bank', zh: 'PNC 银行');
      case ExternalBillType.unknown:
        return tr(context, en: 'Unknown', zh: '未知');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    final hasAccount = _selectedAccountId != null;
    final mismatch = _hasCurrencyMismatch(parsed);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'External Bill Import', zh: '外部账单导入')),
        actions: [
          IconButton(
            tooltip: tr(context, en: 'Export Tutorial', zh: '导出教程'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _ExportTutorialPage()),
              );
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, en: 'Import Account', zh: '导入账户'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingAccounts)
                    const LinearProgressIndicator()
                  else if (_accounts.isEmpty)
                    Text(
                      tr(
                        context,
                        en: 'No active account available.',
                        zh: '当前没有可用账户。',
                      ),
                    )
                  else
                    _ImportSelectorField(
                      label: tr(context, en: 'Target Account', zh: '目标账户'),
                      valueText: _selectedAccount == null
                          ? tr(context, en: 'Not selected', zh: '未选择')
                          : '${_selectedAccount!.name} (${_selectedAccount!.currency.toUpperCase()})',
                      onTap: _importing
                          ? null
                          : () async {
                              final picked = await _showImportSelectionSheet<int>(
                                context,
                                title: tr(
                                  context,
                                  en: 'Select Target Account',
                                  zh: '选择目标账户',
                                ),
                                options: _accounts
                                    .map(
                                      (a) => (
                                        value: a.id,
                                        label:
                                            '${a.name} (${a.currency.toUpperCase()})',
                                        icon: Icons
                                            .account_balance_wallet_rounded,
                                      ),
                                    )
                                    .toList(growable: false),
                                current: _selectedAccountId,
                              );
                              if (picked == null ||
                                  picked == _selectedAccountId) {
                                return;
                              }
                              if (!mounted) return;
                              setState(() => _selectedAccountId = picked);
                            },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, en: 'Supported Files', zh: '支持的文件'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      en: 'WeChat Pay: .xlsx  |  Alipay: .csv  |  PNC: .csv',
                      zh: '微信支付：.xlsx  |  支付宝：.csv  |  PNC：.csv',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _parsing || _importing ? null : _pickFileAndAnalyze,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(
              _parsing
                  ? tr(context, en: 'Analyzing...', zh: '正在识别...')
                  : tr(context, en: 'Choose Bill File', zh: '选择账单文件'),
            ),
          ),
          if (_pickedFile != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(_pickedFile!.name),
                subtitle: Text(
                  tr(
                    context,
                    en: 'Size: ${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                    zh: '大小：${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                  ),
                ),
              ),
            ),
          ],
          if (parsed != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, en: 'Recognition Result', zh: '识别结果'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tr(context, en: 'Bill Type', zh: '账单类型')}：${_typeLabelEx(context, parsed.type)}',
                    ),
                    Text(
                      '${tr(context, en: 'Currency', zh: '币种')}：${parsed.currency}',
                    ),
                    if (_selectedAccount != null)
                      Text(
                        '${tr(context, en: 'Account Currency', zh: '账户币种')}：${_selectedAccount!.currency.toUpperCase()}',
                      ),
                    Text(
                      '${tr(context, en: 'Scanned Rows', zh: '扫描行数')}：${parsed.scannedRows}',
                    ),
                    Text(
                      '${tr(context, en: 'Importable Rows', zh: '可导入行数')}：${parsed.importableRows}',
                    ),
                    Text(
                      '${tr(context, en: 'Skipped Rows', zh: '跳过行数')}：${parsed.skippedRows}',
                    ),
                    if (parsed.latestBalanceCents != null)
                      Text(
                        '${tr(context, en: 'Latest CSV Balance', zh: '最新 CSV 余额')}：${(parsed.latestBalanceCents! / 100.0).toStringAsFixed(2)} ${parsed.currency}',
                      ),
                    if (mismatch) ...[
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          context,
                          en: 'Currency mismatch: account currency must match bill currency before import.',
                          zh: '币种不一致：导入前请确保账户币种与账单币种一致。',
                        ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (!hasAccount || _importing || _parsing || mismatch)
                  ? null
                  : _importNow,
              icon: const Icon(Icons.file_download_done_rounded),
              label: Text(
                _importing
                    ? tr(context, en: 'Importing...', zh: '正在导入...')
                    : tr(
                        context,
                        en: 'Import to Selected Account',
                        zh: '导入到选定账户',
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, en: 'Bill Preview', zh: '账单预览'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        context,
                        en: 'Tap a bill to view details.',
                        zh: '点击账单查看详情。',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: parsed.records.length > 30
                          ? 30
                          : parsed.records.length,
                      separatorBuilder: (_, idx) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final r = parsed.records[index];
                        final amountColor = switch (r.direction) {
                          'income' => Colors.green,
                          'expense' => Theme.of(context).colorScheme.error,
                          'pending' => Colors.orange,
                          _ => Theme.of(context).colorScheme.onSurfaceVariant,
                        };
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _recordTitle(r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_fmtDateTime(r.occurredAt)} · ${_directionLabelEx(r.direction)}',
                          ),
                          trailing: Text(
                            _fmtAmount(r),
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExternalBillRecordDetailPage(
                                  record: r,
                                  index: index + 1,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    if (parsed.records.length > 30)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          tr(
                            context,
                            en: 'Showing first 30 rows only.',
                            zh: '仅显示前 30 条记录。',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (!hasAccount) ...[
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                en: 'Please choose an active account first.',
                zh: '请先选择可用账户。',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportSelectorField extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback? onTap;

  const _ImportSelectorField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: onTap != null),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: TextStyle(
                  color: onTap != null ? cs.onSurface : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

Future<T?> _showImportSelectionSheet<T>(
  BuildContext context, {
  required String title,
  required List<({T value, String label, IconData icon})> options,
  required T? current,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: tr(context, en: 'Close', zh: '关闭'),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final o = options[i];
                  final selected = o.value == current;
                  return ListTile(
                    leading: Icon(
                      o.icon,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    title: Text(
                      o.label,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : null,
                    tileColor: selected
                        ? cs.primaryContainer.withValues(alpha: 0.55)
                        : Colors.transparent,
                    onTap: () => Navigator.of(sheetContext).pop(o.value),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ExportTutorialPage extends StatelessWidget {
  const _ExportTutorialPage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr(context, en: 'Bill Export Tutorial', zh: '账单导出教程')),
          bottom: TabBar(
            tabs: [
              Tab(
                text: tr(context, en: 'WeChat', zh: '微信'),
              ),
              Tab(
                text: tr(context, en: 'Alipay', zh: '支付宝'),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_WechatExportTutorialTab(), _AlipayExportTutorialTab()],
        ),
      ),
    );
  }
}

class _WechatExportTutorialTab extends StatelessWidget {
  const _WechatExportTutorialTab();

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      title: '步骤',
      text: '打开微信，进入“我”页面后点击“服务”。',
      imageAsset: 'assets/tutorials/export/wechat/1.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '在服务页点击“钱包”。',
      imageAsset: 'assets/tutorials/export/wechat/2.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '进入钱包后点击“账单”。',
      imageAsset: 'assets/tutorials/export/wechat/3.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '在账单页点击右上角“...”。',
      imageAsset: 'assets/tutorials/export/wechat/4.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '选择“下载账单”。',
      imageAsset: 'assets/tutorials/export/wechat/5.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '用途选择“用于个人对账”。',
      imageAsset: 'assets/tutorials/export/wechat/6.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '接收方式选择“微信”，账单时间建议选择最近 3 个月。',
      imageAsset: 'assets/tutorials/export/wechat/7.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '按提示完成身份验证。',
      imageAsset: 'assets/tutorials/export/wechat/8.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '导出成功后，在“微信支付”聊天中下载账单文件。',
      imageAsset: 'assets/tutorials/export/wechat/9.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '回到本应用点击“选择账单文件”，选中下载的文件并导入。',
      imageAsset: 'assets/tutorials/export/wechat/10.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final step = _steps[index];
        return _TutorialStepCard(step: step, index: index + 1);
      },
    );
  }
}

class _AlipayExportTutorialTab extends StatelessWidget {
  const _AlipayExportTutorialTab();

  static const _steps = <_TutorialStep>[
    _TutorialStep(
      title: '步骤',
      text: '打开支付宝，进入“我的”页面后点击“账单”。',
      imageAsset: 'assets/tutorials/export/alipay/11.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '在账单页点击右上角“...”。',
      imageAsset: 'assets/tutorials/export/alipay/12.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '选择“开具交易流水证明”或类似导出入口。',
      imageAsset: 'assets/tutorials/export/alipay/13.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '用途选择“用于个人对账”，然后点击“申请”。',
      imageAsset: 'assets/tutorials/export/alipay/14.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '交易类型建议选择“全部”，时间范围建议“最近三个月”。',
      imageAsset: 'assets/tutorials/export/alipay/15.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '填写接收账单的邮箱地址并提交。',
      imageAsset: 'assets/tutorials/export/alipay/16.jpg',
    ),
    _TutorialStep(
      title: '步骤',
      text: '确认邮箱地址无误后，点击“确认发送”。',
      imageAsset: 'assets/tutorials/export/alipay/17.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '收到发送成功提示后，留意邮件中的解压密码。',
      imageAsset: 'assets/tutorials/export/alipay/18.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '到邮箱下载支付宝发送的账单压缩包。',
      imageAsset: 'assets/tutorials/export/alipay/19.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '如未收到通知，可在支付宝消息中心查看导出通知。',
      imageAsset: 'assets/tutorials/export/alipay/20.png',
    ),
    _TutorialStep(
      title: '步骤',
      text: '解压后回到本应用，点击“选择账单文件”导入。',
      imageAsset: 'assets/tutorials/export/alipay/21.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _steps.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final step = _steps[index];
        return _TutorialStepCard(step: step, index: index + 1);
      },
    );
  }
}

class _TutorialStepCard extends StatelessWidget {
  final _TutorialStep step;
  final int index;

  const _TutorialStepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${step.title} $index',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(step.text),
            const SizedBox(height: 10),
            if (step.imageAsset != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  step.imageAsset!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                alignment: Alignment.center,
                child: Text(
                  '预留图片位',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TutorialStep {
  final String title;
  final String text;
  final String? imageAsset;

  const _TutorialStep({
    required this.title,
    required this.text,
    this.imageAsset,
  });
}

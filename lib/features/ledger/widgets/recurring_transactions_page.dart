import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';

class RecurringTransactionsPage extends StatefulWidget {
  final AppDatabase db;
  final int accountId;
  final String accountCurrency;

  const RecurringTransactionsPage({
    super.key,
    required this.db,
    required this.accountId,
    required this.accountCurrency,
  });

  @override
  State<RecurringTransactionsPage> createState() =>
      _RecurringTransactionsPageState();
}

class _RecurringTransactionsPageState extends State<RecurringTransactionsPage> {
  Future<void> _upsertRule({RecurringTransaction? editing}) async {
    final result = await showDialog<_RuleFormResult>(
      context: context,
      builder: (_) => _RuleEditDialog(
        accountCurrency: widget.accountCurrency,
        editing: editing,
      ),
    );
    if (result == null) return;

    final now = DateTime.now();
    if (editing == null) {
      await widget.db
          .into(widget.db.recurringTransactions)
          .insert(
            RecurringTransactionsCompanion.insert(
              accountId: widget.accountId,
              title: d.Value(result.title),
              direction: d.Value(result.direction),
              amountCents: result.amountCents,
              currency: d.Value(widget.accountCurrency.toUpperCase()),
              memo: d.Value(result.memo),
              frequency: d.Value(result.frequency),
              runHour: d.Value(result.runHour),
              runMinute: d.Value(result.runMinute),
              dayOfWeek: d.Value(result.dayOfWeek),
              dayOfMonth: d.Value(result.dayOfMonth),
              isActive: d.Value(result.isActive),
              startDate: d.Value(result.startDate),
            ),
          );
      return;
    }

    await (widget.db.update(
      widget.db.recurringTransactions,
    )..where((t) => t.id.equals(editing.id))).write(
      RecurringTransactionsCompanion(
        title: d.Value(result.title),
        direction: d.Value(result.direction),
        amountCents: d.Value(result.amountCents),
        currency: d.Value(widget.accountCurrency.toUpperCase()),
        memo: d.Value(result.memo),
        frequency: d.Value(result.frequency),
        runHour: d.Value(result.runHour),
        runMinute: d.Value(result.runMinute),
        dayOfWeek: d.Value(result.dayOfWeek),
        dayOfMonth: d.Value(result.dayOfMonth),
        isActive: d.Value(result.isActive),
        startDate: d.Value(result.startDate),
        updatedAt: d.Value(now),
      ),
    );
  }

  Future<void> _deleteRuleDirect(RecurringTransaction rule) async {
    await (widget.db.delete(
      widget.db.recurringTransactions,
    )..where((t) => t.id.equals(rule.id))).go();
  }

  Future<void> _deleteRuleWithConfirm(RecurringTransaction rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, en: 'Delete recurring item?', zh: '删除周期交易？')),
        content: Text(
          tr(
            context,
            en: 'Delete "${rule.title}"?',
            zh: '确定删除“${rule.title}”？',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, en: 'Cancel', zh: '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, en: 'Delete', zh: '删除')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteRuleDirect(rule);
  }

  Future<void> _toggleRule(RecurringTransaction rule, bool enabled) async {
    await (widget.db.update(
      widget.db.recurringTransactions,
    )..where((t) => t.id.equals(rule.id))).write(
      RecurringTransactionsCompanion(
        isActive: d.Value(enabled),
        updatedAt: d.Value(DateTime.now()),
      ),
    );
  }

  String _fmtTime(int h, int m) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}';
  }

  String _freqLabel(String v) {
    switch (v) {
      case 'daily':
        return tr(context, en: 'Daily', zh: '每天');
      case 'weekly':
        return tr(context, en: 'Weekly', zh: '每周');
      case 'monthly':
      default:
        return tr(context, en: 'Monthly', zh: '每月');
    }
  }

  String _scheduleLabel(RecurringTransaction r) {
    final t = _fmtTime(r.runHour, r.runMinute);
    switch (r.frequency) {
      case 'weekly':
        final wd = r.dayOfWeek ?? 1;
        final weekNames = [
          tr(context, en: 'Mon', zh: '周一'),
          tr(context, en: 'Tue', zh: '周二'),
          tr(context, en: 'Wed', zh: '周三'),
          tr(context, en: 'Thu', zh: '周四'),
          tr(context, en: 'Fri', zh: '周五'),
          tr(context, en: 'Sat', zh: '周六'),
          tr(context, en: 'Sun', zh: '周日'),
        ];
        return '${_freqLabel(r.frequency)} ${weekNames[(wd - 1).clamp(0, 6)]} $t';
      case 'monthly':
        return '${_freqLabel(r.frequency)} ${tr(context, en: 'Day', zh: '第')} ${r.dayOfMonth ?? 1} ${tr(context, en: 'at', zh: '日')} $t';
      case 'daily':
      default:
        return '${_freqLabel(r.frequency)} $t';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        (widget.db.select(widget.db.recurringTransactions)
              ..where((t) => t.accountId.equals(widget.accountId))
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: t.createdAt,
                  mode: d.OrderingMode.desc,
                ),
              ]))
            .watch();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Recurring Transactions', zh: '周期交易')),
      ),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: stream,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <RecurringTransaction>[];
          if (rows.isEmpty) {
            return Center(
              child: Text(
                tr(context, en: 'No recurring items yet', zh: '还没有周期交易'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = rows[i];
              final amount = r.amountCents / 100.0;
              final symbol = currencySymbol(r.currency);
              final signed = r.direction == 'income'
                  ? '+$symbol${amount.toStringAsFixed(2)}'
                  : '-$symbol${amount.toStringAsFixed(2)}';
              final amountColor = r.direction == 'income'
                  ? Colors.green
                  : Colors.red;

              return Dismissible(
                key: ValueKey('recurring_${r.id}'),
                direction: DismissDirection.horizontal,
                background: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
                secondaryBackground: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.startToEnd) {
                    await _upsertRule(editing: r);
                    return false;
                  }
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        tr(
                          context,
                          en: 'Delete recurring item?',
                          zh: '删除周期交易？',
                        ),
                      ),
                      content: Text(
                        tr(
                          context,
                          en: 'Delete "${r.title}"?',
                          zh: '确定删除“${r.title}”？',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(tr(context, en: 'Cancel', zh: '取消')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(tr(context, en: 'Delete', zh: '删除')),
                        ),
                      ],
                    ),
                  );
                  return ok ?? false;
                },
                onDismissed: (direction) {
                  if (direction == DismissDirection.endToStart) {
                    _deleteRuleDirect(r);
                  }
                },
                child: Card(
                  child: ListTile(
                    title: Text(
                      r.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${_scheduleLabel(r)}\n$signed',
                      style: TextStyle(color: amountColor),
                    ),
                    isThreeLine: true,
                    trailing: Switch(
                      value: r.isActive,
                      onChanged: (v) => _toggleRule(r, v),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsertRule(),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, en: 'Add Recurring', zh: '新增周期交易')),
      ),
    );
  }
}

class _RuleEditDialog extends StatefulWidget {
  final String accountCurrency;
  final RecurringTransaction? editing;

  const _RuleEditDialog({required this.accountCurrency, this.editing});

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _memoCtrl;

  late String _direction;
  late String _frequency;
  late int _dayOfWeek;
  late int _dayOfMonth;
  late TimeOfDay _time;
  late bool _isActive;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.amountCents / 100.0).toStringAsFixed(2),
    );
    _memoCtrl = TextEditingController(text: e?.memo ?? '');

    _direction = e?.direction ?? 'expense';
    _frequency = e?.frequency ?? 'monthly';
    _dayOfWeek = e?.dayOfWeek ?? DateTime.now().weekday;
    _dayOfMonth = e?.dayOfMonth ?? DateTime.now().day.clamp(1, 28);
    _time = TimeOfDay(hour: e?.runHour ?? 9, minute: e?.runMinute ?? 0);
    _isActive = e?.isActive ?? true;
    _startDate = e?.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekItems = <DropdownMenuItem<int>>[
      DropdownMenuItem(
        value: 1,
        child: Text(tr(context, en: 'Monday', zh: '周一')),
      ),
      DropdownMenuItem(
        value: 2,
        child: Text(tr(context, en: 'Tuesday', zh: '周二')),
      ),
      DropdownMenuItem(
        value: 3,
        child: Text(tr(context, en: 'Wednesday', zh: '周三')),
      ),
      DropdownMenuItem(
        value: 4,
        child: Text(tr(context, en: 'Thursday', zh: '周四')),
      ),
      DropdownMenuItem(
        value: 5,
        child: Text(tr(context, en: 'Friday', zh: '周五')),
      ),
      DropdownMenuItem(
        value: 6,
        child: Text(tr(context, en: 'Saturday', zh: '周六')),
      ),
      DropdownMenuItem(
        value: 7,
        child: Text(tr(context, en: 'Sunday', zh: '周日')),
      ),
    ];

    return AlertDialog(
      title: Text(
        widget.editing == null
            ? tr(context, en: 'Add Recurring', zh: '新增周期交易')
            : tr(context, en: 'Edit Recurring', zh: '编辑周期交易'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Title', zh: '名称'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr(context, en: 'Amount', zh: '金额'),
                prefixText: '${currencySymbol(widget.accountCurrency)} ',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _direction,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Type', zh: '类型'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'expense',
                  child: Text(tr(context, en: 'Expense', zh: '支出')),
                ),
                DropdownMenuItem(
                  value: 'income',
                  child: Text(tr(context, en: 'Income', zh: '收入')),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _direction = v);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Cycle', zh: '周期'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(tr(context, en: 'Daily', zh: '每天')),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text(tr(context, en: 'Weekly', zh: '每周')),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text(tr(context, en: 'Monthly', zh: '每月')),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            if (_frequency == 'weekly') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Weekday', zh: '周几'),
                ),
                items: weekItems,
                onChanged: (v) {
                  if (v != null) setState(() => _dayOfWeek = v);
                },
              ),
            ],
            if (_frequency == 'monthly') ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _dayOfMonth,
                decoration: InputDecoration(
                  labelText: tr(context, en: 'Day of month', zh: '每月日期'),
                ),
                items: List.generate(
                  28,
                  (i) => DropdownMenuItem<int>(
                    value: i + 1,
                    child: Text('${i + 1}'),
                  ),
                ),
                onChanged: (v) {
                  if (v != null) setState(() => _dayOfMonth = v);
                },
              ),
            ],
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr(context, en: 'Auto add time', zh: '自动添加时间')),
              subtitle: Text(_time.format(context)),
              trailing: IconButton(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked == null) return;
                  setState(() => _time = picked);
                },
                icon: const Icon(Icons.schedule_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _memoCtrl,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Memo (optional)', zh: '备注（可选）'),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: Text(tr(context, en: 'Enabled', zh: '启用')),
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, en: 'Cancel', zh: '取消')),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            final amount = double.tryParse(_amountCtrl.text.trim());
            if (title.isEmpty || amount == null || amount <= 0) return;
            final cents = (amount * 100).round();
            Navigator.pop(
              context,
              _RuleFormResult(
                title: title,
                direction: _direction,
                amountCents: cents,
                frequency: _frequency,
                runHour: _time.hour,
                runMinute: _time.minute,
                dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : null,
                dayOfMonth: _frequency == 'monthly' ? _dayOfMonth : null,
                memo: _memoCtrl.text.trim().isEmpty
                    ? null
                    : _memoCtrl.text.trim(),
                isActive: _isActive,
                startDate: _startDate,
              ),
            );
          },
          child: Text(tr(context, en: 'Save', zh: '保存')),
        ),
      ],
    );
  }
}

class _RuleFormResult {
  final String title;
  final String direction;
  final int amountCents;
  final String frequency;
  final int runHour;
  final int runMinute;
  final int? dayOfWeek;
  final int? dayOfMonth;
  final String? memo;
  final bool isActive;
  final DateTime startDate;

  const _RuleFormResult({
    required this.title,
    required this.direction,
    required this.amountCents,
    required this.frequency,
    required this.runHour,
    required this.runMinute,
    required this.dayOfWeek,
    required this.dayOfMonth,
    required this.memo,
    required this.isActive,
    required this.startDate,
  });
}

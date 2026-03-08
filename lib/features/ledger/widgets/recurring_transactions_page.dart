import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import '../../../data/db/app_database.dart';
import 'recurring_transactions_texts.dart';

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
        return rrt(context, 'Daily');
      case 'weekly':
        return rrt(context, 'Weekly');
      case 'monthly':
      default:
        return rrt(context, 'Monthly');
    }
  }

  String _scheduleLabel(RecurringTransaction r) {
    final t = _fmtTime(r.runHour, r.runMinute);
    switch (r.frequency) {
      case 'weekly':
        final wd = r.dayOfWeek ?? 1;
        final weekNames = [
          rrt(context, 'Mon'),
          rrt(context, 'Tue'),
          rrt(context, 'Wed'),
          rrt(context, 'Thu'),
          rrt(context, 'Fri'),
          rrt(context, 'Sat'),
          rrt(context, 'Sun'),
        ];
        return '${_freqLabel(r.frequency)} ${weekNames[(wd - 1).clamp(0, 6)]} $t';
      case 'monthly':
        return '${_freqLabel(r.frequency)} ${rrt(context, 'Day')} ${r.dayOfMonth ?? 1} ${rrt(context, 'at')} $t';
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
      appBar: AppBar(title: Text(rrt(context, 'Recurring Transactions'))),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: stream,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <RecurringTransaction>[];
          if (rows.isEmpty) {
            return Center(child: Text(rrt(context, 'No recurring items yet')));
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
                      title: Text(rrt(context, 'Delete recurring item?')),
                      content: Text(rrt(context, 'Delete "${r.title}"?')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(rrt(context, 'Cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(rrt(context, 'Delete')),
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
        label: Text(rrt(context, 'Add Recurring')),
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
      DropdownMenuItem(value: 1, child: Text(rrt(context, 'Monday'))),
      DropdownMenuItem(value: 2, child: Text(rrt(context, 'Tuesday'))),
      DropdownMenuItem(value: 3, child: Text(rrt(context, 'Wednesday'))),
      DropdownMenuItem(value: 4, child: Text(rrt(context, 'Thursday'))),
      DropdownMenuItem(value: 5, child: Text(rrt(context, 'Friday'))),
      DropdownMenuItem(value: 6, child: Text(rrt(context, 'Saturday'))),
      DropdownMenuItem(value: 7, child: Text(rrt(context, 'Sunday'))),
    ];

    return AlertDialog(
      title: Text(
        widget.editing == null
            ? rrt(context, 'Add Recurring')
            : rrt(context, 'Edit Recurring'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: rrt(context, 'Title')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: rrt(context, 'Amount'),
                prefixText: '${currencySymbol(widget.accountCurrency)} ',
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _direction,
              decoration: InputDecoration(labelText: rrt(context, 'Type')),
              items: [
                DropdownMenuItem(
                  value: 'expense',
                  child: Text(rrt(context, 'Expense')),
                ),
                DropdownMenuItem(
                  value: 'income',
                  child: Text(rrt(context, 'Income')),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _direction = v);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: InputDecoration(labelText: rrt(context, 'Cycle')),
              items: [
                DropdownMenuItem(
                  value: 'daily',
                  child: Text(rrt(context, 'Daily')),
                ),
                DropdownMenuItem(
                  value: 'weekly',
                  child: Text(rrt(context, 'Weekly')),
                ),
                DropdownMenuItem(
                  value: 'monthly',
                  child: Text(rrt(context, 'Monthly')),
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
                decoration: InputDecoration(labelText: rrt(context, 'Weekday')),
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
                  labelText: rrt(context, 'Day of month'),
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
              title: Text(rrt(context, 'Auto add time')),
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
                labelText: rrt(context, 'Memo (optional)'),
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: Text(rrt(context, 'Enabled')),
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(rrt(context, 'Cancel')),
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
          child: Text(rrt(context, 'Save')),
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

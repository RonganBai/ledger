import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';

import '../../../app/currency.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';

class AccountManagePage extends StatelessWidget {
  final AppDatabase db;
  final Future<void> Function(Account created)? onAccountCreated;
  final Future<void> Function(Account oldAccount, Account newAccount)?
  onAccountUpdated;
  final Future<void> Function(Account deleted)? onAccountDeleted;

  const AccountManagePage({
    super.key,
    required this.db,
    this.onAccountCreated,
    this.onAccountUpdated,
    this.onAccountDeleted,
  });

  Future<void> _upsertAccount(BuildContext context, {Account? editing}) async {
    final result = await showDialog<_AccountFormResult>(
      context: context,
      builder: (_) => _AccountEditDialog(editing: editing),
    );
    if (result == null) return;

    if (editing == null) {
      final newId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: result.name,
              ownerUserId: d.Value(db.currentOwnerUserId),
              type: d.Value(result.type),
              currency: d.Value(result.currency),
            ),
          );
      final created = await (db.select(
        db.accounts,
      )..where((a) => a.id.equals(newId))).getSingleOrNull();
      if (created != null) {
        await onAccountCreated?.call(created);
      }
      return;
    }

    await (db.update(db.accounts)..where((a) => a.id.equals(editing.id))).write(
      AccountsCompanion(
        name: d.Value(result.name),
        type: d.Value(result.type),
        currency: d.Value(result.currency),
      ),
    );
    final updated = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(editing.id))).getSingleOrNull();
    if (updated != null) {
      await onAccountUpdated?.call(editing, updated);
    }
  }

  Future<int> _accountBalanceCents(int accountId) async {
    final rows = await (db.select(
      db.transactions,
    )..where((t) => t.accountId.equals(accountId))).get();
    var cents = 0;
    for (final tx in rows) {
      if (tx.direction == 'income') {
        cents += tx.amountCents;
      } else if (tx.direction == 'expense') {
        cents -= tx.amountCents;
      }
    }
    return cents;
  }

  Future<void> _deleteAccount(BuildContext context, Account account) async {
    final activeCount =
        await (db.selectOnly(db.accounts)
              ..addColumns([db.accounts.id.count()])
              ..where(
                db.accounts.isActive.equals(true) &
                    db.accounts.ownerUserId.equals(db.currentOwnerUserId),
              ))
            .getSingle();
    final count = activeCount.read(db.accounts.id.count()) ?? 0;
    if (count <= 1) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'At least one account is required.',
              zh: '至少保留一个账户。',
            ),
          ),
        ),
      );
      return;
    }

    final balanceCents = await _accountBalanceCents(account.id);
    if (balanceCents > 0) {
      if (!context.mounted) return;
      final balance = (balanceCents / 100.0).toStringAsFixed(2);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              en: 'Cannot delete account with positive balance: ${currencySymbol(account.currency)}$balance',
              zh: '账户余额为正数，无法删除：${currencySymbol(account.currency)}$balance',
            ),
          ),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, en: 'Delete account?', zh: '删除账户？')),
        content: Text(
          tr(
            context,
            en: 'Delete account "${account.name}" and all its transactions?',
            zh: '删除账户“${account.name}”及其所有账单？',
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

    await db.transaction(() async {
      await (db.delete(
        db.transactions,
      )..where((t) => t.accountId.equals(account.id))).go();
      await (db.delete(
        db.accounts,
      )..where((a) => a.id.equals(account.id))).go();
    });
    await onAccountDeleted?.call(account);
  }

  @override
  Widget build(BuildContext context) {
    final stream =
        (db.select(db.accounts)
              ..where(
                (a) =>
                    a.isActive.equals(true) &
                    a.ownerUserId.equals(db.currentOwnerUserId),
              )
              ..orderBy([
                (a) => d.OrderingTerm(expression: a.sortOrder),
                (a) => d.OrderingTerm(expression: a.id),
              ]))
            .watch();

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, en: 'Manage Accounts', zh: '账户管理')),
      ),
      body: StreamBuilder<List<Account>>(
        stream: stream,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <Account>[];
          if (rows.isEmpty) {
            return Center(
              child: Text(tr(context, en: 'No accounts', zh: '暂无账户')),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: rows.length,
            separatorBuilder: (_, unused) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = rows[i];
              return FutureBuilder<int>(
                future: _accountBalanceCents(a.id),
                builder: (context, snap) {
                  final cents = snap.data ?? 0;
                  final absAmount = (cents.abs() / 100.0).toStringAsFixed(2);
                  final amountText =
                      '${cents >= 0 ? '+' : '-'}${currencySymbol(a.currency)}$absAmount';
                  return Dismissible(
                    key: ValueKey('account_${a.id}'),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                      ),
                    ),
                    secondaryBackground: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        await _upsertAccount(context, editing: a);
                        return false;
                      }
                      await _deleteAccount(context, a);
                      return false;
                    },
                    child: Card(
                      child: ListTile(
                        title: Text(
                          a.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${a.type.toUpperCase()}  |  ${a.currency.toUpperCase()}\n'
                          '${tr(context, en: 'Current Balance', zh: '当前余额')}: $amountText',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          Icons.swap_horiz_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsertAccount(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr(context, en: 'Add Account', zh: '新增账户')),
      ),
    );
  }
}

class _AccountEditDialog extends StatefulWidget {
  final Account? editing;
  const _AccountEditDialog({this.editing});

  @override
  State<_AccountEditDialog> createState() => _AccountEditDialogState();
}

class _AccountEditDialogState extends State<_AccountEditDialog> {
  late final TextEditingController _nameCtrl;
  late String _type;
  late String _currency;

  static const _types = <String>['cash', 'bank', 'card', 'paypal', 'other'];
  static const _currencies = <String>[
    'USD',
    'CNY',
    'HKD',
    'EUR',
    'JPY',
    'KRW',
    'GBP',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _type = (e?.type ?? 'cash').toLowerCase();
    _currency = (e?.currency ?? 'USD').toUpperCase();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.editing == null
            ? tr(context, en: 'Add Account', zh: '新增账户')
            : tr(context, en: 'Edit Account', zh: '编辑账户'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Account name', zh: '账户名称'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Type', zh: '类型'),
              ),
              items: _types
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: InputDecoration(
                labelText: tr(context, en: 'Currency', zh: '币种'),
              ),
              items: _currencies
                  .map(
                    (e) => DropdownMenuItem<String>(value: e, child: Text(e)),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _currency = v);
              },
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
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _AccountFormResult(name: name, type: _type, currency: _currency),
            );
          },
          child: Text(tr(context, en: 'Save', zh: '保存')),
        ),
      ],
    );
  }
}

class _AccountFormResult {
  final String name;
  final String type;
  final String currency;

  const _AccountFormResult({
    required this.name,
    required this.type,
    required this.currency,
  });
}

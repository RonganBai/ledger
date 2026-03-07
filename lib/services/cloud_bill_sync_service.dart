import 'package:drift/drift.dart' as d;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/db/app_database.dart';
import 'app_log.dart';

class CloudBillSyncService {
  final AppDatabase db;
  final SupabaseClient client;
  final Uuid _uuid = const Uuid();

  CloudBillSyncService({required this.db, required this.client});

  Future<int> clearAllCloudBillsForCurrentUser() async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w('CloudSync', 'Skip clear cloud bills: no signed in user');
      return 0;
    }
    final userId = user.id;
    try {
      final rows = await client
          .from('ledger_bills')
          .select('id')
          .eq('user_id', userId);
      if (rows.isEmpty) {
        AppLog.i('CloudSync', 'Clear cloud bills: nothing to delete');
        return 0;
      }
      final deletedRows = await client
          .from('ledger_bills')
          .delete()
          .eq('user_id', userId)
          .select('id');
      final deletedCount = deletedRows.length;
      final remaining = await client
          .from('ledger_bills')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      AppLog.i(
        'CloudSync',
        'Clear cloud bills done. deleted=$deletedCount remaining=${remaining.length}',
      );
      return deletedCount;
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> deleteTransactionsFromCloudByLocal(
    List<Transaction> deletedLocalTxs,
  ) async {
    if (deletedLocalTxs.isEmpty) return;
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w('CloudSync', 'Skip cloud delete: no signed in user');
      return;
    }
    final userId = user.id;
    try {
      final accountMap = await _ensureCloudAccounts(userId);
      final cloudToLocalAccount = <String, int>{
        for (final e in accountMap.entries) e.value: e.key,
      };
      final cloudTxs = await _fetchCloudBills(userId);
      final cloudById = <String, _CloudBill>{for (final b in cloudTxs) b.id: b};
      final cloudByKey = <String, List<_CloudBill>>{};
      for (final bill in cloudTxs) {
        final key = _cloudKey(bill, cloudToLocalAccount: cloudToLocalAccount);
        cloudByKey.putIfAbsent(key, () => <_CloudBill>[]).add(bill);
      }

      final deleteIds = <String>{};
      for (final tx in deletedLocalTxs) {
        if (_isValidUuid(tx.id) && cloudById.containsKey(tx.id)) {
          deleteIds.add(tx.id);
          continue;
        }
        final key = _localKey(tx);
        final matches = cloudByKey[key];
        if (matches == null || matches.isEmpty) continue;
        for (final m in matches) {
          deleteIds.add(m.id);
        }
      }
      if (deleteIds.isEmpty) {
        AppLog.i(
          'CloudSync',
          'Cloud delete skipped: no matched rows. localDeleted=${deletedLocalTxs.length}',
        );
        return;
      }
      await client
          .from('ledger_bills')
          .delete()
          .eq('user_id', userId)
          .inFilter('id', deleteIds.toList());
      AppLog.i(
        'CloudSync',
        'Cloud delete done. localDeleted=${deletedLocalTxs.length} cloudDeleted=${deleteIds.length}',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> syncNow({required String reason}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w('CloudSync', 'Skip sync($reason): no signed in user');
      return;
    }
    final userId = user.id;
    AppLog.i('CloudSync', 'Start sync($reason). user=$userId');

    try {
      final accountMap = await _ensureCloudAccounts(userId);
      final cloudToLocalAccount = <String, int>{
        for (final e in accountMap.entries) e.value: e.key,
      };
      final localTxs = await (db.select(db.transactions)).get();
      final cloudTxs = await _fetchCloudBills(userId);

      final localById = <String, Transaction>{
        for (final tx in localTxs)
          if (_isValidUuid(tx.id)) tx.id: tx,
      };
      final localByKey = <String, Transaction>{};
      for (final tx in localTxs) {
        localByKey[_localKey(tx)] = tx;
      }
      final cloudById = <String, _CloudBill>{
        for (final bill in cloudTxs) bill.id: bill,
      };
      final cloudByKey = <String, _CloudBill>{};
      for (final bill in cloudTxs) {
        cloudByKey[_cloudKey(bill, cloudToLocalAccount: cloudToLocalAccount)] =
            bill;
      }

      int uploaded = 0;
      int downloaded = 0;
      int updatedCloud = 0;
      int updatedLocal = 0;

      // Upload / update cloud by latest timestamp.
      for (final localTx in localTxs) {
        final cloudBySameId = _isValidUuid(localTx.id)
            ? cloudById[localTx.id]
            : null;
        if (cloudBySameId != null) {
          if (localTx.updatedAt.isAfter(
            cloudBySameId.updatedAt.add(const Duration(seconds: 1)),
          )) {
            await _updateCloudBill(
              cloudBySameId.id,
              localTx,
              userId,
              accountMap[localTx.accountId],
            );
            updatedCloud++;
          }
          continue;
        }
        final key = _localKey(localTx);
        final cloudTx = cloudByKey[key];
        if (cloudTx == null) {
          await _insertCloudBill(
            userId: userId,
            cloudAccountId: accountMap[localTx.accountId],
            tx: localTx,
          );
          uploaded++;
          continue;
        }
        if (localTx.updatedAt.isAfter(
          cloudTx.updatedAt.add(const Duration(seconds: 1)),
        )) {
          await _updateCloudBill(
            cloudTx.id,
            localTx,
            userId,
            accountMap[localTx.accountId],
          );
          updatedCloud++;
        }
      }

      // Download / update local by latest timestamp.
      for (final cloudTx in cloudTxs) {
        final localBySameId = localById[cloudTx.id];
        if (localBySameId != null) {
          if (cloudTx.updatedAt.isAfter(
            localBySameId.updatedAt.add(const Duration(seconds: 1)),
          )) {
            await _updateLocalFromCloud(localBySameId, cloudTx);
            updatedLocal++;
          }
          continue;
        }
        final key = _cloudKey(
          cloudTx,
          cloudToLocalAccount: cloudToLocalAccount,
        );
        final localTx = localByKey[key];
        if (localTx == null) {
          final inserted = await _insertLocalFromCloud(
            cloudTx,
            cloudToLocalAccount,
          );
          if (inserted) {
            downloaded++;
          }
          continue;
        }
        if (cloudTx.updatedAt.isAfter(
          localTx.updatedAt.add(const Duration(seconds: 1)),
        )) {
          await _updateLocalFromCloud(localTx, cloudTx);
          updatedLocal++;
        }
      }

      AppLog.i(
        'CloudSync',
        'Done sync($reason). uploaded=$uploaded downloaded=$downloaded updatedCloud=$updatedCloud updatedLocal=$updatedLocal',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> downloadFromCloudNow({required String reason}) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w('CloudSync', 'Skip download($reason): no signed in user');
      return;
    }
    final userId = user.id;
    AppLog.i('CloudSync', 'Start download($reason). user=$userId');

    try {
      final cloudToLocalAccount = await _downloadAccountsFromCloud(userId);
      final localTxs = await (db.select(db.transactions)).get();
      final cloudTxs = await _fetchCloudBills(userId);

      final localById = <String, Transaction>{
        for (final tx in localTxs)
          if (_isValidUuid(tx.id)) tx.id: tx,
      };
      final localByKey = <String, Transaction>{
        for (final tx in localTxs) _localKey(tx): tx,
      };

      var downloaded = 0;
      var updatedLocal = 0;

      for (final cloudTx in cloudTxs) {
        final localBySameId = localById[cloudTx.id];
        if (localBySameId != null) {
          if (cloudTx.updatedAt.isAfter(
            localBySameId.updatedAt.add(const Duration(seconds: 1)),
          )) {
            await _updateLocalFromCloud(localBySameId, cloudTx);
            updatedLocal++;
          }
          continue;
        }

        final key = _cloudKey(
          cloudTx,
          cloudToLocalAccount: cloudToLocalAccount,
        );
        final localTx = localByKey[key];
        if (localTx == null) {
          final inserted = await _insertLocalFromCloud(
            cloudTx,
            cloudToLocalAccount,
          );
          if (inserted) downloaded++;
          continue;
        }

        if (cloudTx.updatedAt.isAfter(
          localTx.updatedAt.add(const Duration(seconds: 1)),
        )) {
          await _updateLocalFromCloud(localTx, cloudTx);
          updatedLocal++;
        }
      }

      AppLog.i(
        'CloudSync',
        'Done download($reason). downloaded=$downloaded updatedLocal=$updatedLocal',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> uploadCreatedAccount({
    required Account account,
    required String reason,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w(
        'CloudSync',
        'Skip account create upload($reason): no signed in user',
      );
      return;
    }
    final userId = user.id;
    try {
      await client.from('ledger_accounts').insert({
        'user_id': userId,
        'name': account.name,
        'currency': account.currency.toUpperCase(),
        'is_active': account.isActive,
        'sort_order': account.sortOrder,
      });
      AppLog.i(
        'CloudSync',
        'Account create uploaded($reason) name=${account.name} currency=${account.currency}',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> uploadUpdatedAccount({
    required Account oldAccount,
    required Account newAccount,
    required String reason,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w(
        'CloudSync',
        'Skip account update upload($reason): no signed in user',
      );
      return;
    }
    final userId = user.id;
    try {
      final rows = await _fetchCloudAccounts(userId);
      _CloudAccount? target;
      for (final row in rows) {
        if (row.name == oldAccount.name &&
            row.currency == oldAccount.currency.toUpperCase()) {
          target = row;
          break;
        }
      }
      if (target == null) {
        for (final row in rows) {
          if (row.name == newAccount.name &&
              row.currency == newAccount.currency.toUpperCase()) {
            target = row;
            break;
          }
        }
      }
      if (target == null) {
        await uploadCreatedAccount(
          account: newAccount,
          reason: '$reason/fallback_create',
        );
        return;
      }
      await client
          .from('ledger_accounts')
          .update({
            'name': newAccount.name,
            'currency': newAccount.currency.toUpperCase(),
            'is_active': newAccount.isActive,
            'sort_order': newAccount.sortOrder,
          })
          .eq('user_id', userId)
          .eq('id', target.id);
      AppLog.i(
        'CloudSync',
        'Account update uploaded($reason) old=${oldAccount.name}/${oldAccount.currency} new=${newAccount.name}/${newAccount.currency}',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> uploadDeletedAccount({
    required Account account,
    required String reason,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w(
        'CloudSync',
        'Skip account delete upload($reason): no signed in user',
      );
      return;
    }
    final userId = user.id;
    try {
      final rows = await _fetchCloudAccounts(userId);
      final matches = rows
          .where(
            (row) =>
                row.name == account.name &&
                row.currency == account.currency.toUpperCase(),
          )
          .toList(growable: false);
      if (matches.isEmpty) {
        AppLog.i(
          'CloudSync',
          'Account delete upload($reason) skipped: no cloud match name=${account.name} currency=${account.currency}',
        );
        return;
      }
      final cloudIds = matches.map((e) => e.id).toList(growable: false);
      await client
          .from('ledger_bills')
          .delete()
          .eq('user_id', userId)
          .inFilter('account_id', cloudIds);
      await client
          .from('ledger_accounts')
          .delete()
          .eq('user_id', userId)
          .inFilter('id', cloudIds);
      AppLog.i(
        'CloudSync',
        'Account delete uploaded($reason) name=${account.name} currency=${account.currency} deletedCloudAccounts=${cloudIds.length}',
      );
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<void> uploadSingleLocalTransaction({
    required String localTransactionId,
    required String reason,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w('CloudSync', 'Skip single upload($reason): no signed in user');
      return;
    }
    final userId = user.id;
    final localTx =
        await (db.select(db.transactions)
              ..where((t) => t.id.equals(localTransactionId))
              ..limit(1))
            .getSingleOrNull();
    if (localTx == null) {
      AppLog.w(
        'CloudSync',
        'Skip single upload($reason): local tx not found id=$localTransactionId',
      );
      return;
    }

    try {
      final accountMap = await _ensureCloudAccounts(userId);
      final cloudToLocalAccount = <String, int>{
        for (final e in accountMap.entries) e.value: e.key,
      };
      final cloudTxs = await _fetchCloudBills(userId);
      final cloudById = <String, _CloudBill>{for (final b in cloudTxs) b.id: b};
      final cloudByKey = <String, _CloudBill>{
        for (final b in cloudTxs)
          _cloudKey(b, cloudToLocalAccount: cloudToLocalAccount): b,
      };

      _CloudBill? matchedCloud;
      if (_isValidUuid(localTx.id)) {
        matchedCloud = cloudById[localTx.id];
      }
      matchedCloud ??= cloudByKey[_localKey(localTx)];

      if (matchedCloud == null) {
        await _insertCloudBill(
          userId: userId,
          cloudAccountId: accountMap[localTx.accountId],
          tx: localTx,
        );
        AppLog.i(
          'CloudSync',
          'Single upload inserted($reason) tx=${localTx.id}',
        );
        return;
      }

      if (localTx.updatedAt.isAfter(
        matchedCloud.updatedAt.add(const Duration(seconds: 1)),
      )) {
        await _updateCloudBill(
          matchedCloud.id,
          localTx,
          userId,
          accountMap[localTx.accountId],
        );
        AppLog.i(
          'CloudSync',
          'Single upload updated cloud($reason) tx=${localTx.id}',
        );
        return;
      }

      if (matchedCloud.updatedAt.isAfter(
        localTx.updatedAt.add(const Duration(seconds: 1)),
      )) {
        await _updateLocalFromCloud(localTx, matchedCloud);
        AppLog.i(
          'CloudSync',
          'Single upload conflict: updated local from cloud($reason) tx=${localTx.id}',
        );
        return;
      }

      AppLog.i('CloudSync', 'Single upload no-op($reason) tx=${localTx.id}');
    } catch (e, st) {
      AppLog.e('CloudSync', e, st);
      rethrow;
    }
  }

  Future<Map<int, String>> _ensureCloudAccounts(String userId) async {
    final localAccounts = await (db.select(db.accounts)).get();
    final cloudRows = await client
        .from('ledger_accounts')
        .select('id,name,currency')
        .eq('user_id', userId);
    final cloudByNameCurrency = <String, String>{};
    for (final row in cloudRows) {
      final id = '${row['id'] ?? ''}';
      final name = '${row['name'] ?? ''}';
      final currency = '${row['currency'] ?? 'USD'}';
      if (id.isEmpty || name.isEmpty) continue;
      cloudByNameCurrency['$name|${currency.toUpperCase()}'] = id;
    }

    final map = <int, String>{};
    for (final a in localAccounts) {
      final key = '${a.name}|${a.currency.toUpperCase()}';
      var cloudId = cloudByNameCurrency[key];
      if (cloudId == null) {
        final inserted = await client
            .from('ledger_accounts')
            .insert({
              'user_id': userId,
              'name': a.name,
              'currency': a.currency.toUpperCase(),
              'is_active': a.isActive,
              'sort_order': a.sortOrder,
            })
            .select('id')
            .single();
        cloudId = '${inserted['id']}';
        cloudByNameCurrency[key] = cloudId;
      }
      map[a.id] = cloudId;
    }
    return map;
  }

  Future<Map<String, int>> _downloadAccountsFromCloud(String userId) async {
    final cloudRows = await _fetchCloudAccounts(userId);
    final localRows = await (db.select(db.accounts)).get();

    final localByKey = <String, Account>{
      for (final a in localRows) _accountKey(a.name, a.currency): a,
    };
    final cloudToLocal = <String, int>{};

    for (final cloud in cloudRows) {
      final key = _accountKey(cloud.name, cloud.currency);
      final local = localByKey[key];
      if (local != null) {
        cloudToLocal[cloud.id] = local.id;
        await (db.update(
          db.accounts,
        )..where((a) => a.id.equals(local.id))).write(
          AccountsCompanion(
            type: d.Value(cloud.type),
            currency: d.Value(cloud.currency),
            isActive: d.Value(cloud.isActive),
            sortOrder: d.Value(cloud.sortOrder),
          ),
        );
        continue;
      }

      final newLocalId = await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              name: cloud.name,
              type: d.Value(cloud.type),
              currency: d.Value(cloud.currency),
              isActive: d.Value(cloud.isActive),
              sortOrder: d.Value(cloud.sortOrder),
            ),
          );
      cloudToLocal[cloud.id] = newLocalId;
    }
    AppLog.i(
      'CloudSync',
      'Downloaded cloud accounts. cloud=${cloudRows.length} mapped=${cloudToLocal.length}',
    );
    return cloudToLocal;
  }

  Future<List<_CloudAccount>> _fetchCloudAccounts(String userId) async {
    final rows = await client
        .from('ledger_accounts')
        .select('id,name,type,currency,is_active,sort_order')
        .eq('user_id', userId);
    return rows.map(_CloudAccount.fromMap).toList(growable: false);
  }

  Future<List<_CloudBill>> _fetchCloudBills(String userId) async {
    final rows = await client
        .from('ledger_bills')
        .select(
          'id,account_id,source,source_id,direction,amount_cents,currency,merchant,memo,occurred_at,created_at,updated_at',
        )
        .eq('user_id', userId)
        .order('occurred_at', ascending: false);
    return rows.map(_CloudBill.fromMap).toList(growable: false);
  }

  Future<void> _insertCloudBill({
    required String userId,
    required String? cloudAccountId,
    required Transaction tx,
  }) async {
    if (cloudAccountId == null) return;
    await client.from('ledger_bills').insert({
      'id': _validUuidOrGenerated(tx.id),
      'user_id': userId,
      'account_id': cloudAccountId,
      'source': tx.source,
      'source_id': tx.sourceId,
      'direction': tx.direction,
      'amount_cents': tx.amountCents,
      'currency': tx.currency,
      'merchant': tx.merchant,
      'memo': tx.memo,
      'occurred_at': tx.occurredAt.toUtc().toIso8601String(),
      'created_at': tx.createdAt.toUtc().toIso8601String(),
      'updated_at': tx.updatedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> _updateCloudBill(
    String cloudBillId,
    Transaction tx,
    String userId,
    String? cloudAccountId,
  ) async {
    if (cloudAccountId == null) return;
    await client
        .from('ledger_bills')
        .update({
          'account_id': cloudAccountId,
          'source': tx.source,
          'source_id': tx.sourceId,
          'direction': tx.direction,
          'amount_cents': tx.amountCents,
          'currency': tx.currency,
          'merchant': tx.merchant,
          'memo': tx.memo,
          'occurred_at': tx.occurredAt.toUtc().toIso8601String(),
          'updated_at': tx.updatedAt.toUtc().toIso8601String(),
        })
        .eq('id', cloudBillId)
        .eq('user_id', userId);
  }

  Future<bool> _insertLocalFromCloud(
    _CloudBill bill,
    Map<String, int> cloudToLocalAccount,
  ) async {
    var localAccountId = cloudToLocalAccount[bill.accountId];
    if (localAccountId == null) {
      localAccountId = await _resolveLocalAccountId(
        bill.accountId,
        bill.currency,
      );
      cloudToLocalAccount[bill.accountId] = localAccountId;
    }
    final existing = await _findExistingLocalForCloudBill(bill, localAccountId);
    if (existing != null) {
      if (bill.updatedAt.isAfter(
        existing.updatedAt.add(const Duration(seconds: 1)),
      )) {
        await _updateLocalFromCloud(existing, bill);
      }
      return false;
    }
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: _validUuidOrGenerated(bill.id),
            source: d.Value(bill.source),
            sourceId: d.Value(bill.sourceId),
            accountId: localAccountId,
            direction: d.Value(bill.direction),
            amountCents: bill.amountCents,
            currency: d.Value(bill.currency),
            merchant: d.Value(bill.merchant),
            memo: d.Value(bill.memo),
            categoryId: const d.Value(null),
            occurredAt: bill.occurredAt.toLocal(),
            createdAt: d.Value(bill.createdAt.toLocal()),
            updatedAt: d.Value(bill.updatedAt.toLocal()),
            confidence: const d.Value(1.0),
          ),
        );
    return true;
  }

  Future<Transaction?> _findExistingLocalForCloudBill(
    _CloudBill bill,
    int localAccountId,
  ) async {
    final byId =
        await (db.select(db.transactions)
              ..where((t) => t.id.equals(bill.id))
              ..limit(1))
            .getSingleOrNull();
    if (byId != null) {
      return byId;
    }
    final sid = bill.sourceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      final bySourceId =
          await (db.select(db.transactions)
                ..where(
                  (t) => t.source.equals(bill.source) & t.sourceId.equals(sid),
                )
                ..limit(1))
              .getSingleOrNull();
      if (bySourceId != null) {
        return bySourceId;
      }
    }

    final targetOccurred = bill.occurredAt.toLocal();
    final start = targetOccurred.subtract(const Duration(seconds: 1));
    final end = targetOccurred.add(const Duration(seconds: 1));
    final merchant = (bill.merchant ?? '').trim();
    final memo = (bill.memo ?? '').trim();
    final candidates =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.accountId.equals(localAccountId) &
                  t.direction.equals(bill.direction) &
                  t.amountCents.equals(bill.amountCents) &
                  t.occurredAt.isBetweenValues(start, end),
            ))
            .get();
    for (final c in candidates) {
      if ((c.merchant ?? '').trim() == merchant &&
          (c.memo ?? '').trim() == memo) {
        return c;
      }
    }
    return null;
  }

  Future<void> _updateLocalFromCloud(
    Transaction local,
    _CloudBill cloud,
  ) async {
    await (db.update(
      db.transactions,
    )..where((t) => t.id.equals(local.id))).write(
      TransactionsCompanion(
        source: d.Value(cloud.source),
        sourceId: d.Value(cloud.sourceId),
        direction: d.Value(cloud.direction),
        amountCents: d.Value(cloud.amountCents),
        currency: d.Value(cloud.currency),
        merchant: d.Value(cloud.merchant),
        memo: d.Value(cloud.memo),
        occurredAt: d.Value(cloud.occurredAt.toLocal()),
        updatedAt: d.Value(cloud.updatedAt.toLocal()),
      ),
    );
  }

  Future<int> _resolveLocalAccountId(
    String cloudAccountId,
    String currency,
  ) async {
    final account =
        await (db.select(db.accounts)
              ..where((a) => a.currency.equals(currency))
              ..limit(1))
            .getSingleOrNull();
    if (account != null) return account.id;
    return db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Cloud $currency',
            currency: d.Value(currency),
            type: const d.Value('bank'),
          ),
        );
  }

  String _localKey(Transaction tx) {
    final sid = tx.sourceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      return 'S|${tx.source}|$sid';
    }
    return 'F|${tx.accountId}|${tx.direction}|${tx.amountCents}|${tx.occurredAt.toUtc().toIso8601String()}|${(tx.merchant ?? '').trim()}|${(tx.memo ?? '').trim()}';
  }

  String _cloudKey(_CloudBill tx, {Map<String, int>? cloudToLocalAccount}) {
    final sid = tx.sourceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      return 'S|${tx.source}|$sid';
    }
    final accountToken =
        cloudToLocalAccount != null && cloudToLocalAccount[tx.accountId] != null
        ? '${cloudToLocalAccount[tx.accountId]}'
        : 'cloud:${tx.accountId}';
    return 'F|$accountToken|${tx.direction}|${tx.amountCents}|${tx.occurredAt.toUtc().toIso8601String()}|${(tx.merchant ?? '').trim()}|${(tx.memo ?? '').trim()}';
  }

  String _validUuidOrGenerated(String id) {
    return _isValidUuid(id) ? id : _uuid.v4();
  }

  bool _isValidUuid(String id) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(id);
  }

  String _accountKey(String name, String currency) {
    return '${name.trim()}|${currency.toUpperCase()}';
  }
}

class _CloudBill {
  final String id;
  final String accountId;
  final String source;
  final String? sourceId;
  final String direction;
  final int amountCents;
  final String currency;
  final String? merchant;
  final String? memo;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  _CloudBill({
    required this.id,
    required this.accountId,
    required this.source,
    required this.sourceId,
    required this.direction,
    required this.amountCents,
    required this.currency,
    required this.merchant,
    required this.memo,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _CloudBill.fromMap(Map<String, dynamic> m) {
    DateTime dt(String key) => DateTime.parse('${m[key]}');
    return _CloudBill(
      id: '${m['id']}',
      accountId: '${m['account_id']}',
      source: '${m['source'] ?? 'manual'}',
      sourceId: m['source_id'] as String?,
      direction: '${m['direction'] ?? 'expense'}',
      amountCents: (m['amount_cents'] as num).toInt(),
      currency: '${m['currency'] ?? 'USD'}',
      merchant: m['merchant'] as String?,
      memo: m['memo'] as String?,
      occurredAt: dt('occurred_at'),
      createdAt: dt('created_at'),
      updatedAt: dt('updated_at'),
    );
  }
}

class _CloudAccount {
  final String id;
  final String name;
  final String type;
  final String currency;
  final bool isActive;
  final int sortOrder;

  _CloudAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.isActive,
    required this.sortOrder,
  });

  factory _CloudAccount.fromMap(Map<String, dynamic> m) {
    return _CloudAccount(
      id: '${m['id']}',
      name: '${m['name'] ?? ''}',
      type: '${m['type'] ?? 'cash'}',
      currency: '${m['currency'] ?? 'USD'}'.toUpperCase(),
      isActive: m['is_active'] == true,
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

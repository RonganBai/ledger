import 'package:drift/drift.dart' as d;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../data/db/app_database.dart';
import 'app_log.dart';
import 'sync_conflict_log_service.dart';

class CloudBillSyncService {
  final AppDatabase db;
  final SupabaseClient client;
  final Uuid _uuid = const Uuid();
  final SyncConflictLogService _conflictLog = SyncConflictLogService();

  CloudBillSyncService({required this.db, required this.client});

  Future<void> _recordConflict({
    required String direction,
    required String reason,
    required String localTxId,
    required String cloudTxId,
    required String detail,
  }) async {
    await _conflictLog.append(
      SyncConflictEvent(
        time: DateTime.now(),
        direction: direction,
        reason: reason,
        localTxId: localTxId,
        cloudTxId: cloudTxId,
        detail: detail,
      ),
    );
  }

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

  Future<int> clearCloudBillsForLocalAccount(int localAccountId) async {
    final user = client.auth.currentUser;
    if (user == null) {
      AppLog.w(
        'CloudSync',
        'Skip clear account cloud bills: no signed in user',
      );
      return 0;
    }
    final userId = user.id;
    try {
      final accountMap = await _ensureCloudAccounts(userId);
      final cloudAccountId = accountMap[localAccountId];
      if (cloudAccountId == null || cloudAccountId.trim().isEmpty) {
        AppLog.i(
          'CloudSync',
          'Clear account cloud bills skipped: no cloud account mapping for local=$localAccountId',
        );
        return 0;
      }

      final rows = await client
          .from('ledger_bills')
          .select('id')
          .eq('user_id', userId)
          .eq('account_id', cloudAccountId);
      if (rows.isEmpty) {
        AppLog.i(
          'CloudSync',
          'Clear account cloud bills: nothing to delete for local=$localAccountId cloud=$cloudAccountId',
        );
        return 0;
      }

      final deletedRows = await client
          .from('ledger_bills')
          .delete()
          .eq('user_id', userId)
          .eq('account_id', cloudAccountId)
          .select('id');
      final deletedCount = deletedRows.length;
      AppLog.i(
        'CloudSync',
        'Clear account cloud bills done. local=$localAccountId cloud=$cloudAccountId deleted=$deletedCount',
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
      final localByKeyNoDirection = <String, Transaction>{};
      final localBySourceIdOnly = <String, Transaction>{};
      for (final tx in localTxs) {
        localByKey[_localKey(tx)] = tx;
        localByKeyNoDirection[_localKeyNoDirection(tx)] = tx;
        final sid = tx.sourceId?.trim();
        if (sid != null && sid.isNotEmpty) {
          localBySourceIdOnly[sid] = tx;
        }
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
            await _recordConflict(
              direction: 'local_to_cloud',
              reason: 'sync/$reason/by_id/newer_local',
              localTxId: localTx.id,
              cloudTxId: cloudBySameId.id,
              detail:
                  'Local updatedAt ${localTx.updatedAt.toIso8601String()} newer than cloud ${cloudBySameId.updatedAt.toIso8601String()}',
            );
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
          await _recordConflict(
            direction: 'local_to_cloud',
            reason: 'sync/$reason/by_key/newer_local',
            localTxId: localTx.id,
            cloudTxId: cloudTx.id,
            detail:
                'Local updatedAt ${localTx.updatedAt.toIso8601String()} newer than cloud ${cloudTx.updatedAt.toIso8601String()}',
          );
        }
      }

      // Download / update local by latest timestamp.
      for (final cloudTx in cloudTxs) {
        final localBySameId = localById[cloudTx.id];
        if (localBySameId != null) {
          final shouldUpdateByTime = cloudTx.updatedAt.isAfter(
            localBySameId.updatedAt.add(const Duration(seconds: 1)),
          );
          final shouldUpdateByDiff = !_sameTxContent(localBySameId, cloudTx);
          if (shouldUpdateByTime || shouldUpdateByDiff) {
            await _updateLocalFromCloud(localBySameId, cloudTx);
            updatedLocal++;
            await _recordConflict(
              direction: 'cloud_to_local',
              reason: shouldUpdateByTime
                  ? 'sync/$reason/by_id/newer_cloud'
                  : 'sync/$reason/by_id/content_diff',
              localTxId: localBySameId.id,
              cloudTxId: cloudTx.id,
              detail:
                  'Cloud updatedAt ${cloudTx.updatedAt.toIso8601String()}, local updatedAt ${localBySameId.updatedAt.toIso8601String()}',
            );
          }
          continue;
        }
        final key = _cloudKey(
          cloudTx,
          cloudToLocalAccount: cloudToLocalAccount,
        );
        final localByExactKey = localByKey[key];
        final localByNoDirection =
            localByKeyNoDirection[_cloudKeyNoDirection(
              cloudTx,
              cloudToLocalAccount: cloudToLocalAccount,
            )];
        final sid = cloudTx.sourceId?.trim();
        final localBySourceId = sid != null && sid.isNotEmpty
            ? localBySourceIdOnly[sid]
            : null;
        final localTx =
            localByExactKey ?? localByNoDirection ?? localBySourceId;
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
          await _recordConflict(
            direction: 'cloud_to_local',
            reason: 'sync/$reason/newer_cloud',
            localTxId: localTx.id,
            cloudTxId: cloudTx.id,
            detail:
                'Cloud updatedAt ${cloudTx.updatedAt.toIso8601String()} newer than local ${localTx.updatedAt.toIso8601String()}',
          );
          if (localByExactKey == null &&
              localByNoDirection == null &&
              localBySourceId != null) {
            AppLog.i(
              'CloudSync',
              'Sync($reason) sourceId-only match override. local=${localTx.id} cloud=${cloudTx.id} from=${localTx.direction} to=${cloudTx.direction}',
            );
          }
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
      final localByKeyNoDirection = <String, Transaction>{
        for (final tx in localTxs) _localKeyNoDirection(tx): tx,
      };
      final localBySourceIdOnly = <String, Transaction>{
        for (final tx in localTxs)
          if ((tx.sourceId ?? '').trim().isNotEmpty) tx.sourceId!.trim(): tx,
      };

      var downloaded = 0;
      var updatedLocal = 0;

      for (final cloudTx in cloudTxs) {
        final localBySameId = localById[cloudTx.id];
        if (localBySameId != null) {
          final shouldUpdateByTime = cloudTx.updatedAt.isAfter(
            localBySameId.updatedAt.add(const Duration(seconds: 1)),
          );
          final shouldUpdateByDiff = !_sameTxContent(localBySameId, cloudTx);
          if (shouldUpdateByTime || shouldUpdateByDiff) {
            await _updateLocalFromCloud(localBySameId, cloudTx);
            updatedLocal++;
            await _recordConflict(
              direction: 'cloud_to_local',
              reason: shouldUpdateByTime
                  ? 'download/$reason/by_id/newer_cloud'
                  : 'download/$reason/by_id/content_diff',
              localTxId: localBySameId.id,
              cloudTxId: cloudTx.id,
              detail:
                  'Cloud updatedAt ${cloudTx.updatedAt.toIso8601String()}, local updatedAt ${localBySameId.updatedAt.toIso8601String()}',
            );
            if (shouldUpdateByDiff && !shouldUpdateByTime) {
              AppLog.i(
                'CloudSync',
                'Download($reason) diff-override by id. tx=${localBySameId.id} localUpdatedAt=${localBySameId.updatedAt.toIso8601String()} cloudUpdatedAt=${cloudTx.updatedAt.toIso8601String()}',
              );
            }
          }
          continue;
        }

        final key = _cloudKey(
          cloudTx,
          cloudToLocalAccount: cloudToLocalAccount,
        );
        final localByExactKey = localByKey[key];
        final localByNoDirection =
            localByKeyNoDirection[_cloudKeyNoDirection(
              cloudTx,
              cloudToLocalAccount: cloudToLocalAccount,
            )];
        final sid = cloudTx.sourceId?.trim();
        final localBySourceId = sid != null && sid.isNotEmpty
            ? localBySourceIdOnly[sid]
            : null;
        final localByFallback =
            localByExactKey == null &&
                localByNoDirection == null &&
                localBySourceId == null
            ? await _findDownloadFallbackLocal(cloudTx, cloudToLocalAccount)
            : null;
        final localTx =
            localByExactKey ??
            localByNoDirection ??
            localBySourceId ??
            localByFallback;
        if (localTx == null) {
          final inserted = await _insertLocalFromCloud(
            cloudTx,
            cloudToLocalAccount,
          );
          if (inserted) downloaded++;
          AppLog.i(
            'CloudSync',
            'Download($reason) inserted new local (no match). cloud=${cloudTx.id} dir=${cloudTx.direction} amount=${cloudTx.amountCents} source=${cloudTx.source} sourceId=${cloudTx.sourceId}',
          );
          continue;
        }

        final shouldUpdateByTime = cloudTx.updatedAt.isAfter(
          localTx.updatedAt.add(const Duration(seconds: 1)),
        );
        final shouldUpdateByDiff = !_sameTxContent(localTx, cloudTx);
        if (shouldUpdateByTime || shouldUpdateByDiff) {
          await _updateLocalFromCloud(localTx, cloudTx);
          updatedLocal++;
          await _recordConflict(
            direction: 'cloud_to_local',
            reason: shouldUpdateByTime
                ? 'download/$reason/newer_cloud'
                : 'download/$reason/content_diff',
            localTxId: localTx.id,
            cloudTxId: cloudTx.id,
            detail:
                'Cloud updatedAt ${cloudTx.updatedAt.toIso8601String()}, local updatedAt ${localTx.updatedAt.toIso8601String()}',
          );
          if (localByExactKey == null && localByNoDirection != null) {
            AppLog.i(
              'CloudSync',
              'Download($reason) no-direction match override. local=${localTx.id} cloud=${cloudTx.id} from=${localTx.direction} to=${cloudTx.direction}',
            );
          } else if (localByExactKey == null &&
              localByNoDirection == null &&
              localBySourceId != null) {
            AppLog.i(
              'CloudSync',
              'Download($reason) sourceId-only match override. local=${localTx.id} cloud=${cloudTx.id} from=${localTx.direction} to=${cloudTx.direction}',
            );
          } else if (localByExactKey == null &&
              localByNoDirection == null &&
              localByFallback != null) {
            AppLog.i(
              'CloudSync',
              'Download($reason) fallback match override. local=${localTx.id} cloud=${cloudTx.id} from=${localTx.direction} to=${cloudTx.direction}',
            );
          }
        }
      }

      AppLog.i(
        'CloudSync',
        'Done download($reason). downloaded=$downloaded updatedLocal=$updatedLocal',
      );

      // Cloud-authoritative prune for download mode:
      // remove local transactions that don't exist in cloud anymore.
      final localAfter = await (db.select(db.transactions)).get();
      final cloudIdSet = <String>{for (final c in cloudTxs) c.id};
      final cloudSourceKeySet = <String>{
        for (final c in cloudTxs)
          if ((c.sourceId ?? '').trim().isNotEmpty)
            'S|${c.source}|${c.sourceId!.trim()}',
      };
      final cloudFullKeySet = <String>{
        for (final c in cloudTxs)
          _cloudKey(c, cloudToLocalAccount: cloudToLocalAccount),
      };
      final cloudNoDirectionKeySet = <String>{
        for (final c in cloudTxs)
          _cloudKeyNoDirection(c, cloudToLocalAccount: cloudToLocalAccount),
      };

      final toDeleteIds = <String>[];
      for (final local in localAfter) {
        if (_isValidUuid(local.id) && cloudIdSet.contains(local.id)) {
          continue;
        }
        final sid = local.sourceId?.trim();
        if (sid != null &&
            sid.isNotEmpty &&
            cloudSourceKeySet.contains('S|${local.source}|$sid')) {
          continue;
        }
        if (cloudFullKeySet.contains(_localKey(local))) {
          continue;
        }
        if (cloudNoDirectionKeySet.contains(_localKeyNoDirection(local))) {
          continue;
        }
        toDeleteIds.add(local.id);
      }

      if (toDeleteIds.isNotEmpty) {
        await (db.delete(
          db.transactions,
        )..where((t) => t.id.isIn(toDeleteIds))).go();
      }
      AppLog.i(
        'CloudSync',
        'Done download prune($reason). localTotal=${localAfter.length} deleted=${toDeleteIds.length} kept=${localAfter.length - toDeleteIds.length}',
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
        await _recordConflict(
          direction: 'local_to_cloud',
          reason: 'single_upload/$reason/newer_local',
          localTxId: localTx.id,
          cloudTxId: matchedCloud.id,
          detail:
              'Local updatedAt ${localTx.updatedAt.toIso8601String()} newer than cloud ${matchedCloud.updatedAt.toIso8601String()}',
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
        await _recordConflict(
          direction: 'cloud_to_local',
          reason: 'single_upload/$reason/newer_cloud',
          localTxId: localTx.id,
          cloudTxId: matchedCloud.id,
          detail:
              'Cloud updatedAt ${matchedCloud.updatedAt.toIso8601String()} newer than local ${localTx.updatedAt.toIso8601String()}',
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
    final cloudById = <String, String>{};
    final cloudByNameCurrency = <String, String>{};
    for (final row in cloudRows) {
      final id = '${row['id'] ?? ''}';
      final name = '${row['name'] ?? ''}';
      final currency = '${row['currency'] ?? 'USD'}';
      if (id.isEmpty || name.isEmpty) continue;
      cloudById[id] = id;
      cloudByNameCurrency['$name|${currency.toUpperCase()}'] = id;
    }

    final map = <int, String>{};
    for (final a in localAccounts) {
      final key = '${a.name}|${a.currency.toUpperCase()}';
      var cloudId = (a.cloudAccountId ?? '').trim();
      if (cloudId.isNotEmpty && !cloudById.containsKey(cloudId)) {
        cloudId = '';
      }
      if (cloudId.isEmpty) {
        cloudId = cloudByNameCurrency[key] ?? '';
      }
      if (cloudId.isEmpty) {
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
        cloudId = '${inserted['id'] ?? ''}';
        if (cloudId.isNotEmpty) {
          cloudByNameCurrency[key] = cloudId;
          cloudById[cloudId] = cloudId;
        }
      }
      if (cloudId.isEmpty) continue;
      if ((a.cloudAccountId ?? '').trim() != cloudId && cloudId.isNotEmpty) {
        await (db.update(db.accounts)..where((x) => x.id.equals(a.id))).write(
          AccountsCompanion(cloudAccountId: d.Value(cloudId)),
        );
      }
      map[a.id] = cloudId;
    }
    return map;
  }

  Future<Map<String, int>> _downloadAccountsFromCloud(String userId) async {
    final cloudRows = await _fetchCloudAccounts(userId);
    await _removeSeededPlaceholderAccountsIfNeeded(cloudRows);
    final localRows = await (db.select(db.accounts)).get();

    final localByCloudId = <String, Account>{
      for (final a in localRows)
        if ((a.cloudAccountId ?? '').trim().isNotEmpty)
          a.cloudAccountId!.trim(): a,
    };
    final localByKey = <String, Account>{
      for (final a in localRows) _accountKey(a.name, a.currency): a,
    };
    final cloudToLocal = <String, int>{};

    for (final cloud in cloudRows) {
      final key = _accountKey(cloud.name, cloud.currency);
      final local = localByCloudId[cloud.id] ?? localByKey[key];
      if (local != null) {
        cloudToLocal[cloud.id] = local.id;
        await (db.update(
          db.accounts,
        )..where((a) => a.id.equals(local.id))).write(
          AccountsCompanion(
            cloudAccountId: d.Value(cloud.id),
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
              cloudAccountId: d.Value(cloud.id),
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

  Future<void> _removeSeededPlaceholderAccountsIfNeeded(
    List<_CloudAccount> cloudRows,
  ) async {
    if (cloudRows.isEmpty) return;

    final localRows = await (db.select(db.accounts)).get();
    for (final account in localRows) {
      if (!_isSeededPlaceholderAccount(account)) continue;
      final txCountExpr = db.transactions.id.count();
      final txCountRow =
          await (db.selectOnly(db.transactions)
                ..addColumns([txCountExpr])
                ..where(db.transactions.accountId.equals(account.id)))
              .getSingle();
      final txCount = txCountRow.read(txCountExpr) ?? 0;
      if (txCount != 0) continue;
      await (db.delete(
        db.accounts,
      )..where((a) => a.id.equals(account.id))).go();
    }
  }

  bool _isSeededPlaceholderAccount(Account account) {
    final cloudAccountId = (account.cloudAccountId ?? '').trim();
    if (cloudAccountId.isNotEmpty) return false;
    final normalizedName = account.name.trim().toLowerCase();
    const seededNames = <String>{'cash', 'paypal'};
    return seededNames.contains(normalizedName);
  }

  Future<List<_CloudAccount>> _fetchCloudAccounts(String userId) async {
    try {
      final rows = await client
          .from('ledger_accounts')
          .select('id,name,type,currency,is_active,sort_order')
          .eq('user_id', userId);
      return rows.map(_CloudAccount.fromMap).toList(growable: false);
    } catch (_) {
      final rows = await client
          .from('ledger_accounts')
          .select('id,name,currency,is_active,sort_order')
          .eq('user_id', userId);
      return rows.map(_CloudAccount.fromMap).toList(growable: false);
    }
  }

  Future<List<_CloudBill>> _fetchCloudBills(String userId) async {
    try {
      final rows = await client
          .from('ledger_bills')
          .select(
            'id,account_id,source,source_id,direction,amount_cents,currency,merchant,memo,category_key,occurred_at,created_at,updated_at',
          )
          .eq('user_id', userId)
          .order('occurred_at', ascending: false);
      return rows.map(_CloudBill.fromMap).toList(growable: false);
    } catch (_) {
      final rows = await client
          .from('ledger_bills')
          .select(
            'id,account_id,source,source_id,direction,amount_cents,currency,merchant,memo,occurred_at,created_at,updated_at',
          )
          .eq('user_id', userId)
          .order('occurred_at', ascending: false);
      return rows.map(_CloudBill.fromMap).toList(growable: false);
    }
  }

  Future<void> _insertCloudBill({
    required String userId,
    required String? cloudAccountId,
    required Transaction tx,
  }) async {
    if (cloudAccountId == null) return;
    final categoryKey = await _categoryKeyById(tx.categoryId);
    final payload = <String, dynamic>{
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
    };
    try {
      payload['category_key'] = categoryKey;
      await client.from('ledger_bills').insert(payload);
    } catch (_) {
      payload.remove('category_key');
      await client.from('ledger_bills').insert(payload);
    }
  }

  Future<void> _updateCloudBill(
    String cloudBillId,
    Transaction tx,
    String userId,
    String? cloudAccountId,
  ) async {
    if (cloudAccountId == null) return;
    final categoryKey = await _categoryKeyById(tx.categoryId);
    final payload = <String, dynamic>{
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
    };
    try {
      payload['category_key'] = categoryKey;
      await client
          .from('ledger_bills')
          .update(payload)
          .eq('id', cloudBillId)
          .eq('user_id', userId);
    } catch (_) {
      payload.remove('category_key');
      await client
          .from('ledger_bills')
          .update(payload)
          .eq('id', cloudBillId)
          .eq('user_id', userId);
    }
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
      final shouldUpdateByTime = bill.updatedAt.isAfter(
        existing.updatedAt.add(const Duration(seconds: 1)),
      );
      final shouldUpdateByDiff = !_sameTxContent(existing, bill);
      if (shouldUpdateByTime || shouldUpdateByDiff) {
        await _updateLocalFromCloud(existing, bill);
      }
      return false;
    }
    final inferredCategoryId = await _inferCategoryIdForCloudBill(bill);
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
            categoryId: d.Value(inferredCategoryId),
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

    final candidatesIgnoreDirection =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.accountId.equals(localAccountId) &
                  t.amountCents.equals(bill.amountCents) &
                  t.occurredAt.isBetweenValues(start, end),
            ))
            .get();
    for (final c in candidatesIgnoreDirection) {
      if ((c.merchant ?? '').trim() == merchant &&
          (c.memo ?? '').trim() == memo) {
        return c;
      }
    }
    return null;
  }

  Future<Transaction?> _findDownloadFallbackLocal(
    _CloudBill bill,
    Map<String, int> cloudToLocalAccount,
  ) async {
    final localAccountId = cloudToLocalAccount[bill.accountId];
    if (localAccountId != null) {
      final inAccount = await _findExistingLocalForCloudBill(
        bill,
        localAccountId,
      );
      if (inAccount != null) return inAccount;
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
      if (bySourceId != null) return bySourceId;
    }

    final targetOccurred = bill.occurredAt.toLocal();
    final start = targetOccurred.subtract(const Duration(seconds: 1));
    final end = targetOccurred.add(const Duration(seconds: 1));
    final merchant = (bill.merchant ?? '').trim();
    final memo = (bill.memo ?? '').trim();
    final candidates =
        await (db.select(db.transactions)..where(
              (t) =>
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
    final inferredCategoryId = local.categoryId == null
        ? await _inferCategoryIdForCloudBill(cloud)
        : null;
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
        categoryId: d.Value(inferredCategoryId ?? local.categoryId),
        occurredAt: d.Value(cloud.occurredAt.toLocal()),
        updatedAt: d.Value(cloud.updatedAt.toLocal()),
      ),
    );
  }

  Future<int?> _inferCategoryIdForCloudBill(_CloudBill bill) async {
    final key =
        _normalizeCategoryKey(bill.categoryKey) ??
        _normalizeCategoryKey((bill.memo ?? '').trim());
    if (key == null) return null;

    final preferredDirection = bill.direction == 'income'
        ? 'income'
        : 'expense';
    final byPreferred =
        await (db.select(db.categories)
              ..where(
                (c) =>
                    c.name.equals(key) & c.direction.equals(preferredDirection),
              )
              ..limit(1))
            .getSingleOrNull();
    if (byPreferred != null) return byPreferred.id;

    final byAny =
        await (db.select(db.categories)
              ..where((c) => c.name.equals(key))
              ..limit(1))
            .getSingleOrNull();
    return byAny?.id;
  }

  Future<String?> _categoryKeyById(int? categoryId) async {
    if (categoryId == null) return null;
    final row =
        await (db.select(db.categories)
              ..where((c) => c.id.equals(categoryId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return _normalizeCategoryKey(row.name);
  }

  Future<int> _resolveLocalAccountId(
    String cloudAccountId,
    String currency,
  ) async {
    final byCloudId =
        await (db.select(db.accounts)
              ..where((a) => a.cloudAccountId.equals(cloudAccountId))
              ..limit(1))
            .getSingleOrNull();
    if (byCloudId != null) return byCloudId.id;

    final user = client.auth.currentUser;
    if (user != null) {
      try {
        dynamic row;
        try {
          row = await client
              .from('ledger_accounts')
              .select('id,name,type,currency,is_active,sort_order')
              .eq('user_id', user.id)
              .eq('id', cloudAccountId)
              .maybeSingle();
        } catch (_) {
          row = await client
              .from('ledger_accounts')
              .select('id,name,currency,is_active,sort_order')
              .eq('user_id', user.id)
              .eq('id', cloudAccountId)
              .maybeSingle();
        }

        if (row is Map<String, dynamic>) {
          final cloud = _CloudAccount.fromMap(row);
          final existing =
              await (db.select(db.accounts)
                    ..where(
                      (a) =>
                          a.name.equals(cloud.name) &
                          a.currency.equals(cloud.currency),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          if (existing != null) {
            await (db.update(
              db.accounts,
            )..where((a) => a.id.equals(existing.id))).write(
              AccountsCompanion(
                cloudAccountId: d.Value(cloudAccountId),
                type: d.Value(cloud.type),
                currency: d.Value(cloud.currency),
                isActive: d.Value(cloud.isActive),
                sortOrder: d.Value(cloud.sortOrder),
              ),
            );
            return existing.id;
          }

          return db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  name: cloud.name,
                  cloudAccountId: d.Value(cloudAccountId),
                  type: d.Value(cloud.type),
                  currency: d.Value(cloud.currency),
                  isActive: d.Value(cloud.isActive),
                  sortOrder: d.Value(cloud.sortOrder),
                ),
              );
        }
      } catch (e, st) {
        AppLog.e('CloudSync', e, st);
      }
    }

    final fallbackCurrency = currency.toUpperCase();
    return db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            name: 'Cloud-$fallbackCurrency-${cloudAccountId.substring(0, 6)}',
            cloudAccountId: d.Value(cloudAccountId),
            currency: d.Value(fallbackCurrency),
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

  String _localKeyNoDirection(Transaction tx) {
    final sid = tx.sourceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      return 'S|${tx.source}|$sid';
    }
    return 'N|${tx.accountId}|${tx.amountCents}|${tx.occurredAt.toUtc().toIso8601String()}|${(tx.merchant ?? '').trim()}|${(tx.memo ?? '').trim()}';
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

  String _cloudKeyNoDirection(
    _CloudBill tx, {
    Map<String, int>? cloudToLocalAccount,
  }) {
    final sid = tx.sourceId?.trim();
    if (sid != null && sid.isNotEmpty) {
      return 'S|${tx.source}|$sid';
    }
    final accountToken =
        cloudToLocalAccount != null && cloudToLocalAccount[tx.accountId] != null
        ? '${cloudToLocalAccount[tx.accountId]}'
        : 'cloud:${tx.accountId}';
    return 'N|$accountToken|${tx.amountCents}|${tx.occurredAt.toUtc().toIso8601String()}|${(tx.merchant ?? '').trim()}|${(tx.memo ?? '').trim()}';
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
  final String? categoryKey;
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
    required this.categoryKey,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _CloudBill.fromMap(Map<String, dynamic> m) {
    DateTime dt(String key) => DateTime.parse('${m[key]}');
    return _CloudBill(
      id: '${m['id']}',
      accountId: '${m['account_id']}',
      source: _normalizeSource(m['source']),
      sourceId: m['source_id'] as String?,
      direction: _normalizeDirection(m['direction']),
      amountCents: (m['amount_cents'] as num).toInt(),
      currency: '${m['currency'] ?? 'USD'}',
      merchant: m['merchant'] as String?,
      memo: m['memo'] as String?,
      categoryKey: m['category_key'] as String?,
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
      isActive: _parseCloudIsActive(m['is_active']),
      sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

bool _parseCloudIsActive(dynamic raw) {
  if (raw == null) return true;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final text = raw.toString().trim().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return true;
}

String _normalizeDirection(dynamic raw) {
  final text = (raw?.toString() ?? 'expense').trim().toLowerCase();
  if (text == 'income' || text == 'expense' || text == 'pending') return text;
  return 'expense';
}

String _normalizeSource(dynamic raw) {
  final text = (raw?.toString() ?? 'manual').trim().toLowerCase();
  const allowed = <String>{
    'manual',
    'paypal',
    'pnc',
    'wechatpay',
    'alipay',
    'recurring',
  };
  if (allowed.contains(text)) return text;
  return 'manual';
}

String? _normalizeCategoryKey(String? raw) {
  var text = (raw ?? '').trim().toLowerCase();
  if (text.isEmpty) return null;
  if (text.contains('|')) {
    final parts = text
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (parts.isNotEmpty) {
      // Prefer right-most token, e.g. "... | Restaurants and Dining"
      text = parts.last;
    }
  }
  const knownKeys = <String>{
    'food',
    'transport',
    'shopping',
    'bills',
    'entertainment',
    'health',
    'salary',
    'refund',
    'rent',
    'utilities',
    'travel',
    'medical',
    'gift',
    'transfer',
    'other',
  };
  if (knownKeys.contains(text)) return text;

  if (text.contains('restaurant') ||
      text.contains('dining') ||
      text.contains('doordash') ||
      text.contains('food')) {
    return 'food';
  }
  if (text.contains('uber') ||
      text.contains('lyft') ||
      text.contains('transport') ||
      text.contains('travel')) {
    return 'transport';
  }
  if (text.contains('shopping') || text.contains('amazon')) {
    return 'shopping';
  }
  if (text.contains('rent')) return 'rent';
  if (text.contains('utility') ||
      text.contains('electric') ||
      text.contains('water')) {
    return 'utilities';
  }
  if (text.contains('salary') || text.contains('payroll')) return 'salary';
  if (text.contains('refund')) return 'refund';
  if (text.contains('gift')) return 'gift';
  if (text.contains('transfer') || text.contains('zelle')) return 'transfer';

  const enAlias = <String, String>{
    'food': 'food',
    'transport': 'transport',
    'shopping': 'shopping',
    'bills': 'bills',
    'entertainment': 'entertainment',
    'health': 'health',
    'salary': 'salary',
    'refund': 'refund',
    'rent': 'rent',
    'utilities': 'utilities',
    'travel': 'travel',
    'medical': 'medical',
    'gift': 'gift',
    'transfer': 'transfer',
    'other': 'other',
  };
  return enAlias[text];
}

bool _sameTxContent(Transaction local, _CloudBill cloud) {
  return local.source == cloud.source &&
      (local.sourceId ?? '') == (cloud.sourceId ?? '') &&
      local.direction == cloud.direction &&
      local.amountCents == cloud.amountCents &&
      local.currency.toUpperCase() == cloud.currency.toUpperCase() &&
      (local.merchant ?? '') == (cloud.merchant ?? '') &&
      (local.memo ?? '') == (cloud.memo ?? '') &&
      local.occurredAt.toUtc().toIso8601String() ==
          cloud.occurredAt.toUtc().toIso8601String();
}

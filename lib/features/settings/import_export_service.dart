import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';

class ImportExportService {
  final AppDatabase db;
  ImportExportService(this.db);

  Future<String> exportFullBackupJsonString() async {
    final file = await exportFullBackupJson();
    return file.readAsString();
  }

  // ======== Export (Full Backup) ========

  Future<File> exportFullBackupJson() async {
    final acc = await (db.select(
      db.accounts,
    )..where((a) => a.ownerUserId.equals(db.currentOwnerUserId))).get();
    final cat = await db.select(db.categories).get();
    final accountIds = acc.map((e) => e.id).toSet();
    final tx = accountIds.isEmpty
        ? const <Transaction>[]
        : await (db.select(
            db.transactions,
          )..where((t) => t.accountId.isIn(accountIds))).get();

    final payload = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'accounts': acc.map(_accountToJson).toList(),
      'categories': cat.map(_categoryToJson).toList(),
      'transactions': tx.map(_txToJson).toList(),
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/ledger_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file;
  }

  Future<void> shareFile(File f) async {
    await Share.shareXFiles([XFile(f.path)]);
  }

  // ======== Pick Backup ========

  Future<PickedBackup?> pickBackupJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final f = File(result.files.single.path!);
    final raw = await f.readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Invalid backup format: root is not an object',
      );
    }
    return PickedBackup(file: f, data: decoded);
  }

  /// 只追加：不删除旧数据
  Future<ImportResult> importAppend(Map<String, dynamic> backup) async {
    return _importInternal(backup, wipeFirst: false);
  }

  /// 清空数据库后恢复：先清空再导入
  Future<ImportResult> restoreAfterWipe(Map<String, dynamic> backup) async {
    return _importInternal(backup, wipeFirst: true);
  }

  /// 清空应用中已存储的账单数据（不依赖选择备份文件）。
  /// 会删除：transactions、recurringTransactions、syncState。
  /// 返回删除的交易条数（transactions + recurringTransactions）。
  Future<int> clearStoredBillData() async {
    return db.transaction(() async {
      final ownedAccounts = await (db.select(
        db.accounts,
      )..where((a) => a.ownerUserId.equals(db.currentOwnerUserId))).get();
      final ownedIds = ownedAccounts.map((e) => e.id).toList(growable: false);
      if (ownedIds.isEmpty) return 0;
      final deletedTx = await (db.delete(
        db.transactions,
      )..where((t) => t.accountId.isIn(ownedIds))).go();
      int deletedRecurring = 0;
      try {
        deletedRecurring = await (db.delete(
          db.recurringTransactions,
        )..where((t) => t.accountId.isIn(ownedIds))).go();
      } catch (_) {
        // ignore if table unavailable in old schema
      }
      try {
        await db.delete(db.syncState).go();
      } catch (_) {
        // ignore
      }
      return deletedTx + deletedRecurring;
    });
  }

  Future<int> clearStoredBillDataForAccount({required int accountId}) async {
    return db.transaction(() async {
      final deletedTx = await (db.delete(
        db.transactions,
      )..where((t) => t.accountId.equals(accountId))).go();
      int deletedRecurring = 0;
      try {
        deletedRecurring = await (db.delete(
          db.recurringTransactions,
        )..where((t) => t.accountId.equals(accountId))).go();
      } catch (_) {
        // ignore if table unavailable in old schema
      }
      return deletedTx + deletedRecurring;
    });
  }

  Future<ImportResult> _importInternal(
    Map<String, dynamic> backup, {
    required bool wipeFirst,
  }) async {
    final accounts = (backup['accounts'] as List? ?? const []).cast<dynamic>();
    final categories = (backup['categories'] as List? ?? const [])
        .cast<dynamic>();
    final transactions = (backup['transactions'] as List? ?? const [])
        .cast<dynamic>();

    return db.transaction(() async {
      if (wipeFirst) {
        // 删除顺序：先 tx（外键），再 categories，再 accounts
        final ownedAccounts = await (db.select(
          db.accounts,
        )..where((a) => a.ownerUserId.equals(db.currentOwnerUserId))).get();
        final ownedIds = ownedAccounts.map((e) => e.id).toList(growable: false);
        if (ownedIds.isNotEmpty) {
          await (db.delete(
            db.transactions,
          )..where((t) => t.accountId.isIn(ownedIds))).go();
          await (db.delete(
            db.accounts,
          )..where((a) => a.id.isIn(ownedIds))).go();
        }

        // 你的数据库里有 SyncState 表
        try {
          await db.delete(db.syncState).go();
        } catch (_) {
          // ignore
        }
      }

      // oldId -> newId 映射（append 时很关键）
      final accIdMap = <int, int>{};
      final catIdMap = <int, int>{};

      // 1) Accounts
      int insertedAccounts = 0;
      for (final a in accounts) {
        final m = (a as Map).cast<String, dynamic>();
        final oldId = (m['id'] as num?)?.toInt();
        final name = (m['name'] ?? '').toString();
        final type = (m['type'] ?? 'cash').toString();
        final currency = (m['currency'] ?? 'USD').toString();
        final isActive = (m['isActive'] ?? true) as bool;
        final sortOrder = (m['sortOrder'] as num?)?.toInt() ?? 0;
        final createdAt =
            DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now();

        // append：按 name+type+currency 匹配已有账户
        final existing =
            await (db.select(db.accounts)..where(
                  (t) =>
                      t.name.equals(name) &
                      t.type.equals(type) &
                      t.currency.equals(currency) &
                      t.ownerUserId.equals(db.currentOwnerUserId),
                ))
                .getSingleOrNull();

        if (existing != null) {
          if (oldId != null) accIdMap[oldId] = existing.id;
          continue;
        }

        if (wipeFirst && oldId != null) {
          await db
              .into(db.accounts)
              .insert(
                AccountsCompanion(
                  id: Value(oldId),
                  ownerUserId: Value(db.currentOwnerUserId),
                  name: Value(name),
                  type: Value(type),
                  currency: Value(currency),
                  isActive: Value(isActive),
                  sortOrder: Value(sortOrder),
                  createdAt: Value(createdAt),
                ),
              );
          accIdMap[oldId] = oldId;
        } else {
          final newId = await db
              .into(db.accounts)
              .insert(
                AccountsCompanion.insert(
                  name: name,
                  ownerUserId: Value(db.currentOwnerUserId),
                  type: Value(type),
                  currency: Value(currency),
                  isActive: Value(isActive),
                  sortOrder: Value(sortOrder),
                  createdAt: Value(createdAt),
                ),
              );
          if (oldId != null) accIdMap[oldId] = newId;
        }

        insertedAccounts++;
      }

      // 2) Categories：先插入，再补 parentId
      int insertedCategories = 0;

      // 2.1 插入（暂不处理 parentId）
      for (final c in categories) {
        final m = (c as Map).cast<String, dynamic>();
        final oldId = (m['id'] as num?)?.toInt();
        final name = (m['name'] ?? '').toString(); // 你这里存的是 i18n key
        final direction = (m['direction'] ?? 'expense').toString();
        final isActive = (m['isActive'] ?? true) as bool;
        final sortOrder = (m['sortOrder'] as num?)?.toInt() ?? 0;
        final createdAt =
            DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now();

        // append：按 unique key（name+direction）匹配已有分类
        final existing =
            await (db.select(db.categories)..where(
                  (t) => t.name.equals(name) & t.direction.equals(direction),
                ))
                .getSingleOrNull();

        if (existing != null) {
          if (oldId != null) catIdMap[oldId] = existing.id;
          continue;
        }

        if (wipeFirst && oldId != null) {
          await db
              .into(db.categories)
              .insert(
                CategoriesCompanion(
                  id: Value(oldId),
                  name: Value(name),
                  direction: Value(direction),
                  parentId: const Value(null),
                  isActive: Value(isActive),
                  sortOrder: Value(sortOrder),
                  createdAt: Value(createdAt),
                ),
              );
          catIdMap[oldId] = oldId;
        } else {
          final newId = await db
              .into(db.categories)
              .insert(
                CategoriesCompanion.insert(
                  name: name,
                  direction: Value(direction),
                  parentId: const Value(null),
                  isActive: Value(isActive),
                  sortOrder: Value(sortOrder),
                  createdAt: Value(createdAt),
                ),
              );
          if (oldId != null) catIdMap[oldId] = newId;
        }

        insertedCategories++;
      }

      // 2.2 回填 parentId
      for (final c in categories) {
        final m = (c as Map).cast<String, dynamic>();
        final oldId = (m['id'] as num?)?.toInt();
        final oldParentId = (m['parentId'] as num?)?.toInt();
        if (oldId == null || oldParentId == null) continue;

        final newId = catIdMap[oldId];
        final newParentId = catIdMap[oldParentId];
        if (newId == null || newParentId == null) continue;

        await (db.update(db.categories)..where((t) => t.id.equals(newId)))
            .write(CategoriesCompanion(parentId: Value(newParentId)));
      }

      // 3) Transactions
      int insertedTx = 0;
      int skippedTx = 0;

      for (final t in transactions) {
        final m = (t as Map).cast<String, dynamic>();

        final id = (m['id'] ?? '').toString();
        if (id.isEmpty) {
          skippedTx++;
          continue;
        }

        // 去重 1：UUID 主键
        final existsById = await (db.select(
          db.transactions,
        )..where((x) => x.id.equals(id))).getSingleOrNull();
        if (existsById != null) {
          skippedTx++;
          continue;
        }

        final source = (m['source'] ?? 'manual').toString();
        final sourceId = m['sourceId']?.toString();

        // 去重 2：source + sourceId（sourceId 非空时可靠）
        if (sourceId != null && sourceId.isNotEmpty) {
          final existsBySource =
              await (db.select(db.transactions)..where(
                    (x) =>
                        x.source.equals(source) & x.sourceId.equals(sourceId),
                  ))
                  .getSingleOrNull();
          if (existsBySource != null) {
            skippedTx++;
            continue;
          }
        }

        final oldAccountId = (m['accountId'] as num?)?.toInt();
        final newAccountId = oldAccountId != null
            ? (accIdMap[oldAccountId] ?? oldAccountId)
            : null;
        if (newAccountId == null) {
          skippedTx++;
          continue;
        }

        final oldCategoryId = (m['categoryId'] as num?)?.toInt();
        final newCategoryId = oldCategoryId == null
            ? null
            : (catIdMap[oldCategoryId] ?? oldCategoryId);

        final direction = (m['direction'] ?? 'expense').toString();
        final amountCents = (m['amountCents'] as num?)?.toInt() ?? 0;
        final currency = (m['currency'] ?? 'USD').toString();
        final merchant = m['merchant']?.toString();
        final memo = m['memo']?.toString();
        final occurredAt = DateTime.parse(m['occurredAt'].toString());
        final createdAt =
            DateTime.tryParse((m['createdAt'] ?? '').toString()) ??
            DateTime.now();
        final updatedAt =
            DateTime.tryParse((m['updatedAt'] ?? '').toString()) ??
            DateTime.now();
        final confidence = (m['confidence'] as num?)?.toDouble();

        // 兜底去重：manual + sourceId null 时
        if (sourceId == null || sourceId.isEmpty) {
          final existsLoose =
              await (db.select(db.transactions)..where(
                    (x) =>
                        x.source.equals(source) &
                        x.direction.equals(direction) &
                        x.amountCents.equals(amountCents) &
                        x.currency.equals(currency) &
                        x.accountId.equals(newAccountId) &
                        x.occurredAt.equals(occurredAt),
                  ))
                  .getSingleOrNull();
          if (existsLoose != null) {
            skippedTx++;
            continue;
          }
        }

        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion(
                id: Value(id),
                source: Value(source),
                sourceId: Value(sourceId),
                accountId: Value(newAccountId),
                direction: Value(direction),
                amountCents: Value(amountCents),
                currency: Value(currency),
                merchant: Value(merchant),
                memo: Value(memo),
                categoryId: Value(newCategoryId),
                occurredAt: Value(occurredAt),
                createdAt: Value(createdAt),
                updatedAt: Value(updatedAt),
                confidence: Value(confidence),
              ),
            );

        insertedTx++;
      }

      return ImportResult(
        insertedAccounts: insertedAccounts,
        insertedCategories: insertedCategories,
        insertedTransactions: insertedTx,
        skippedTransactions: skippedTx,
      );
    });
  }

  // ======== JSON helpers (注意：类型是单数 Account/Category/Transaction) ========

  Map<String, dynamic> _accountToJson(Account a) => {
    'id': a.id,
    'name': a.name,
    'type': a.type,
    'currency': a.currency,
    'isActive': a.isActive,
    'sortOrder': a.sortOrder,
    'createdAt': a.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _categoryToJson(Category c) => {
    'id': c.id,
    'name': c.name,
    'direction': c.direction,
    'parentId': c.parentId,
    'isActive': c.isActive,
    'sortOrder': c.sortOrder,
    'createdAt': c.createdAt.toIso8601String(),
  };

  Map<String, dynamic> _txToJson(Transaction t) => {
    'id': t.id,
    'source': t.source,
    'sourceId': t.sourceId,
    'accountId': t.accountId,
    'direction': t.direction,
    'amountCents': t.amountCents,
    'currency': t.currency,
    'merchant': t.merchant,
    'memo': t.memo,
    'categoryId': t.categoryId,
    'occurredAt': t.occurredAt.toIso8601String(),
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'confidence': t.confidence,
  };
}

class ImportResult {
  final int insertedAccounts;
  final int insertedCategories;
  final int insertedTransactions;
  final int skippedTransactions;

  const ImportResult({
    required this.insertedAccounts,
    required this.insertedCategories,
    required this.insertedTransactions,
    required this.skippedTransactions,
  });
}

class PickedBackup {
  final File file;
  final Map<String, dynamic> data;
  PickedBackup({required this.file, required this.data});
}

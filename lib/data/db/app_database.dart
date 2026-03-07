import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/accounts.dart';
import 'tables/categories.dart';
import 'tables/recurring_transactions.dart';
import 'tables/transactions.dart';
import 'tables/sync_state.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    RecurringTransactions,
    Transactions,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedDefaults();
    },
    onUpgrade: (m, from, to) async {
      // v2: categories.name stores a stable i18n key (e.g. 'food') instead of display text (e.g. 'Food')
      if (from < 2) {
        await _migrateCategoryNamesToKeys();
      }
      if (from < 3) {
        await _seedDefaults();
      }
      if (from < 4) {
        await m.createTable(recurringTransactions);
      }
    },
  );

  Future<void> _seedDefaults() async {
    // 榛樿璐︽埛
    await into(accounts).insert(
      AccountsCompanion.insert(name: 'Cash', type: const Value('cash')),
      mode: InsertMode.insertOrIgnore,
    );

    await into(accounts).insert(
      AccountsCompanion.insert(name: 'PayPal', type: const Value('paypal')),
      mode: InsertMode.insertOrIgnore,
    );

    // 榛樿鏀嚭鍒嗙被
    const expenseCategories = [
      'food',
      'transport',
      'shopping',
      'bills',
      'entertainment',
      'health',
      'rent',
      'travel',
      'transfer',
      'gift',
      'utilities',
      'other',
    ];

    for (final name in expenseCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          direction: const Value('expense'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }

    // 榛樿鏀跺叆鍒嗙被
    const incomeCategories = ['salary', 'refund', 'gift', 'transfer', 'other'];

    for (final name in incomeCategories) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: name,
          direction: const Value('income'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }

  Future<void> _migrateCategoryNamesToKeys() async {
    // Normalize existing category names (English/Chinese) to stable keys.
    // This keeps your UI fully i18n-driven and avoids mixed-language lists.
    const pairs = <String, List<String>>{
      'food': ['Food', 'FOOD', '餐饮'],
      'transport': ['Transport', 'TRANSPORT', '交通'],
      'shopping': ['Shopping', 'SHOPPING', '购物'],
      'bills': ['Bills', 'BILLS', '账单', '缴费'],
      'entertainment': ['Entertainment', 'ENTERTAINMENT', '娱乐'],
      'health': ['Health', 'HEALTH', '医疗', '健康'],
      'salary': ['Salary', 'SALARY', '工资'],
      'refund': ['Refund', 'REFUND', '退款'],
      'rent': ['Rent', 'RENT', '房租'],
      'utilities': ['Utilities', 'UTILITIES', '水电'],
      'travel': ['Travel', 'TRAVEL', '旅行'],
      'gift': ['Gift', 'GIFT', '礼物'],
      'transfer': ['Transfer', 'TRANSFER', '转账'],
      'other': ['Other', 'OTHER', '其他'],
    };

    for (final entry in pairs.entries) {
      final key = entry.key;
      for (final raw in entry.value) {
        await customStatement('UPDATE categories SET name = ? WHERE name = ?', [
          key,
          raw,
        ]);
      }
    }

    // Also normalize any title-cased keys (e.g. 'Food' -> 'food') not covered above
    await customStatement('UPDATE categories SET name = lower(name)');
  }

  Future<bool> hasAnyTransactions() async {
    final row = await (select(transactions)..limit(1)).getSingleOrNull();
    return row != null;
  }

  // Category deletion helpers:
  // Move all transactions under a category to "other", then delete the category.
  Future<int> ensureOtherCategoryId(String direction) async {
    final existing =
        await (select(categories)..where(
              (c) => c.name.equals('other') & c.direction.equals(direction),
            ))
            .getSingleOrNull();

    if (existing != null) {
      if (!existing.isActive) {
        await (update(categories)..where((c) => c.id.equals(existing.id)))
            .write(const CategoriesCompanion(isActive: Value(true)));
      }
      return existing.id;
    }

    return into(categories).insert(
      CategoriesCompanion.insert(
        name: 'other',
        direction: Value(direction),
        isActive: const Value(true),
      ),
    );
  }

  Future<void> deleteCategoryAndMoveToOther(int categoryId) async {
    await transaction(() async {
      final cat = await (select(
        categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (cat == null) return;

      if (cat.name == 'other') return;

      final otherId = await ensureOtherCategoryId(cat.direction);

      await (update(categories)..where((c) => c.parentId.equals(categoryId)))
          .write(const CategoriesCompanion(parentId: Value(null)));

      await (update(transactions)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(TransactionsCompanion(categoryId: Value(otherId)));

      await (delete(categories)..where((c) => c.id.equals(categoryId))).go();
    });
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'ledger.sqlite');
}

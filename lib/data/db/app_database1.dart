import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/accounts.dart';
import 'tables/categories.dart';
import 'tables/transactions.dart';
import 'tables/sync_state.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    SyncState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedDefaults();
        },
      );

  Future<void> _seedDefaults() async {
    // 默认账户
    await into(accounts).insert(
      AccountsCompanion.insert(
        name: 'Cash',
        type: const Value('cash'),
      ),
      mode: InsertMode.insertOrIgnore,
    );

    await into(accounts).insert(
      AccountsCompanion.insert(
        name: 'PayPal',
        type: const Value('paypal'),
      ),
      mode: InsertMode.insertOrIgnore,
    );

    // 默认支出分类
    const expenseCategories = [
      'Food',
      'Transport',
      'Shopping',
      'Bills',
      'Entertainment',
      'Health',
      'Other',
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

    // 默认收入分类
    const incomeCategories = [
      'Salary',
      'Refund',
      'Other',
    ];

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
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'ledger.sqlite',
  );
}
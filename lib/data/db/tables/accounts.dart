import 'package:drift/drift.dart';

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Cloud account binding (Supabase ledger_accounts.id)
  TextColumn get cloudAccountId => text().nullable()();

  // 账户名称：Cash / PayPal / Card ...
  TextColumn get name => text().withLength(min: 1, max: 50)();

  // 账户类型：cash / paypal / bank / card
  TextColumn get type =>
      text().withLength(min: 1, max: 20).withDefault(const Constant('cash'))();

  // 币种
  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {cloudAccountId},
      ];
}

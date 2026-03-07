import 'package:drift/drift.dart';

class SyncState extends Table {
  // provider: 'paypal'
  TextColumn get provider => text()();

  // 上次同步时间
  DateTimeColumn get lastSyncAt => dateTime().nullable()();

  // 游标/标记（可选）
  TextColumn get cursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {provider};
}
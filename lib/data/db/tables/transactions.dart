import 'package:drift/drift.dart';
import 'accounts.dart';
import 'categories.dart';

class Transactions extends Table {
  // 主键（UUID 字符串）
  TextColumn get id => text()();

  // 数据来源：manual / paypal
  TextColumn get source =>
      text().withLength(min: 1, max: 20).withDefault(const Constant('manual'))();

  // 外部来源 ID（例如 PayPal transaction_id）
  TextColumn get sourceId => text().nullable()();

  // 关联账户
  IntColumn get accountId => integer().references(Accounts, #id)();

  // income / expense
  TextColumn get direction =>
      text().withLength(min: 6, max: 7).withDefault(const Constant('expense'))();

  // 金额（单位：分，避免浮点误差）
  IntColumn get amountCents => integer()();

  // 币种
  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();

  // 商家名称
  TextColumn get merchant => text().nullable()();

  // 备注
  TextColumn get memo => text().nullable()();

  // 分类
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  // 发生时间
  DateTimeColumn get occurredAt => dateTime()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  // 自动识别置信度（以后AI用）
  RealColumn get confidence => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  // 同来源 + sourceId 唯一（用于去重）
  @override
  List<Set<Column>> get uniqueKeys => [
        {source, sourceId},
      ];
}
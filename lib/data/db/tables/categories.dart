import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 分类名称
  TextColumn get name => text().withLength(min: 1, max: 50)();

  // income / expense
  TextColumn get direction =>
      text().withLength(min: 6, max: 7).withDefault(const Constant('expense'))();

  // 父分类（可选）
  IntColumn get parentId => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {name, direction},
      ];
}
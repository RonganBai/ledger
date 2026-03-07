import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get accountId => integer().references(Accounts, #id)();

  TextColumn get title => text()
      .withLength(min: 1, max: 60)
      .withDefault(const Constant('Recurring'))();

  TextColumn get direction => text()
      .withLength(min: 6, max: 7)
      .withDefault(const Constant('expense'))();

  IntColumn get amountCents => integer()();

  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  TextColumn get memo => text().nullable()();

  // daily / weekly / monthly
  TextColumn get frequency => text()
      .withLength(min: 5, max: 7)
      .withDefault(const Constant('monthly'))();

  IntColumn get runHour => integer().withDefault(const Constant(9))();

  IntColumn get runMinute => integer().withDefault(const Constant(0))();

  // 1..7 (Mon..Sun), used by weekly
  IntColumn get dayOfWeek => integer().nullable()();

  // 1..28, used by monthly (keep <= 28 to avoid month-end edge cases)
  IntColumn get dayOfMonth => integer().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get startDate => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

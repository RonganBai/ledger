import 'package:drift/drift.dart' as d;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/app_database.dart';

class RecurringTransactionService {
  static final Uuid _uuid = const Uuid();

  static Future<int> applyDueForAllAccounts(AppDatabase db) async {
    final accounts =
        await (db.select(db.accounts)..where(
              (a) =>
                  a.isActive.equals(true) &
                  a.ownerUserId.equals(db.currentOwnerUserId),
            ))
            .get();
    var inserted = 0;
    for (final account in accounts) {
      inserted += await applyDueForAccount(
        db,
        accountId: account.id,
        accountCurrency: account.currency.toUpperCase(),
      );
    }
    debugPrint(
      '[Recurring] applyDueForAllAccounts finished, inserted=$inserted',
    );
    return inserted;
  }

  static Future<int> applyDueForAccount(
    AppDatabase db, {
    required int accountId,
    required String accountCurrency,
  }) async {
    final now = DateTime.now();
    final rules =
        await (db.select(db.recurringTransactions)..where(
              (r) =>
                  r.accountId.equals(accountId) &
                  r.isActive.equals(true) &
                  r.startDate.isSmallerOrEqualValue(now),
            ))
            .get();

    if (rules.isEmpty) {
      debugPrint('[Recurring] account=$accountId no active rules');
      return 0;
    }

    var insertedCount = 0;
    for (final rule in rules) {
      final dueTimes = _collectDueTimes(rule, now);
      if (dueTimes.isEmpty) continue;

      try {
        await db.transaction(() async {
          for (final dueAt in dueTimes) {
            final rowId = await db
                .into(db.transactions)
                .insert(
                  TransactionsCompanion.insert(
                    id: _uuid.v4(),
                    source: const d.Value('recurring'),
                    sourceId: d.Value(
                      'recurring:${rule.id}:${dueAt.millisecondsSinceEpoch}',
                    ),
                    accountId: rule.accountId,
                    direction: d.Value(rule.direction),
                    amountCents: rule.amountCents,
                    currency: d.Value(
                      rule.currency.isEmpty
                          ? accountCurrency
                          : rule.currency.toUpperCase(),
                    ),
                    merchant: d.Value(rule.title),
                    memo: d.Value(rule.memo),
                    categoryId: d.Value(rule.categoryId),
                    occurredAt: dueAt,
                  ),
                  mode: d.InsertMode.insertOrIgnore,
                );
            if (rowId > 0) {
              insertedCount++;
              debugPrint(
                '[Recurring] inserted account=$accountId rule=${rule.id} tx=$rowId due=$dueAt',
              );
            } else {
              debugPrint(
                '[Recurring] skipped(duplicate) account=$accountId rule=${rule.id} due=$dueAt',
              );
            }
          }

          final lastAt = dueTimes.last;
          await (db.update(
            db.recurringTransactions,
          )..where((r) => r.id.equals(rule.id))).write(
            RecurringTransactionsCompanion(
              lastGeneratedAt: d.Value(lastAt),
              updatedAt: d.Value(now),
            ),
          );
        });
      } catch (e, st) {
        debugPrint(
          '[Recurring] failed account=$accountId rule=${rule.id} error=$e',
        );
        debugPrint(st.toString());
      }
    }

    debugPrint('[Recurring] account=$accountId done inserted=$insertedCount');
    return insertedCount;
  }

  static List<DateTime> _collectDueTimes(
    RecurringTransaction rule,
    DateTime now,
  ) {
    final out = <DateTime>[];
    var next = rule.lastGeneratedAt == null
        ? _firstOccurrence(rule)
        : _nextOccurrence(rule, rule.lastGeneratedAt!);

    var guard = 0;
    while (next != null && !next.isAfter(now) && guard < 180) {
      out.add(next);
      next = _nextOccurrence(rule, next);
      guard++;
    }
    return out;
  }

  static DateTime? _firstOccurrence(RecurringTransaction rule) {
    final base = DateTime(
      rule.startDate.year,
      rule.startDate.month,
      rule.startDate.day,
      rule.runHour,
      rule.runMinute,
    );

    switch (rule.frequency) {
      case 'daily':
        return base;
      case 'weekly':
        final targetWeekday = _sanitizeWeekday(rule.dayOfWeek) ?? base.weekday;
        final delta = (targetWeekday - base.weekday + 7) % 7;
        return base.add(Duration(days: delta));
      case 'monthly':
      default:
        final day = _sanitizeMonthDay(rule.dayOfMonth) ?? base.day.clamp(1, 28);
        var candidate = DateTime(
          base.year,
          base.month,
          day,
          rule.runHour,
          rule.runMinute,
        );
        if (candidate.isBefore(base)) {
          candidate = DateTime(
            base.year,
            base.month + 1,
            day,
            rule.runHour,
            rule.runMinute,
          );
        }
        return candidate;
    }
  }

  static DateTime? _nextOccurrence(RecurringTransaction rule, DateTime from) {
    switch (rule.frequency) {
      case 'daily':
        return DateTime(
          from.year,
          from.month,
          from.day + 1,
          rule.runHour,
          rule.runMinute,
        );
      case 'weekly':
        return DateTime(
          from.year,
          from.month,
          from.day + 7,
          rule.runHour,
          rule.runMinute,
        );
      case 'monthly':
      default:
        final day = _sanitizeMonthDay(rule.dayOfMonth) ?? 1;
        return DateTime(
          from.year,
          from.month + 1,
          day,
          rule.runHour,
          rule.runMinute,
        );
    }
  }

  static int? _sanitizeWeekday(int? v) {
    if (v == null) return null;
    if (v < 1 || v > 7) return null;
    return v;
  }

  static int? _sanitizeMonthDay(int? v) {
    if (v == null) return null;
    if (v < 1) return 1;
    if (v > 28) return 28;
    return v;
  }
}

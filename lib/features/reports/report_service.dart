import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as d;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/app_database.dart';
import 'models.dart';
import 'widgets/balance_trend_line.dart';

class ReportService {
  final AppDatabase db;
  final int accountId;

  ReportService(this.db, {required this.accountId});

  static const _kLastArchivedMonthPrefix = 'last_archived_month_acc_'; // + accountId

  static String monthKey(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}';
  }

  static DateTime monthStart(DateTime dt) => DateTime(dt.year, dt.month, 1);
  static DateTime nextMonthStart(DateTime dt) =>
      (dt.month == 12) ? DateTime(dt.year + 1, 1, 1) : DateTime(dt.year, dt.month + 1, 1);

  static DateTime dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime weekStart(DateTime dt, {int weekStartDay = DateTime.monday}) {
    final d0 = dayStart(dt);
    final diff = (d0.weekday - weekStartDay) % 7;
    return d0.subtract(Duration(days: diff));
  }

  static Future<MonthlyReport> buildForRange(
    AppDatabase db,
    DateTime start,
    DateTime end, {
    required String label,
    int? accountId,
  }) async {
    final query = db.select(db.transactions)
      ..where((t) => t.occurredAt.isBetweenValues(start, end));

    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId));
    }

    query.orderBy([(t) => d.OrderingTerm(expression: t.occurredAt)]);

    final rows = await query.get();

    int income = 0;
    int expense = 0;
    final byCat = <String, int>{};
    final txs = <MonthlyTx>[];

    final catAll = await db.select(db.categories).get();
    final catNameById = {for (final c in catAll) c.id: c.name};

    for (final tx in rows) {
      final cents = tx.amountCents;
      final name = catNameById[tx.categoryId] ?? 'Uncategorized';

      if (tx.direction == 'income') {
        income += cents;
      } else if (tx.direction == 'expense') {
        expense += cents;
        byCat[name] = (byCat[name] ?? 0) + cents;
      }

      txs.add(
        MonthlyTx(
          id: tx.id,
          direction: tx.direction,
          amountCents: cents,
          occurredAt: tx.occurredAt,
          categoryName: name,
          merchant: tx.merchant,
          memo: tx.memo,
        ),
      );
    }

    return MonthlyReport(
      monthKey: label,
      incomeCents: income,
      expenseCents: expense,
      expenseByCategoryCents: byCat,
      transactions: txs,
      createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<MonthlyReport> buildForLastDays(AppDatabase db, int days, {DateTime? now, int? accountId}) async {
    final n = now ?? DateTime.now();
    final end = dayStart(n).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: days));
    String two(int n) => n.toString().padLeft(2, '0');
    final endD = end.subtract(const Duration(days: 1));
    final label =
        '${start.year}-${two(start.month)}-${two(start.day)} ~ ${endD.year}-${two(endD.month)}-${two(endD.day)}';
    return buildForRange(db, start, end, label: label, accountId: accountId);
  }

  static Future<MonthlyReport> buildForMonth(AppDatabase db, DateTime anyDayInMonth, {int? accountId}) async {
    final start = monthStart(anyDayInMonth);
    final end = nextMonthStart(anyDayInMonth);
    final mk = monthKey(anyDayInMonth);
    return buildForRange(db, start, end, label: mk, accountId: accountId);
  }

  static Future<MonthlyReport> buildForYear(AppDatabase db, int year, {int? accountId}) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    return buildForRange(db, start, end, label: '$year', accountId: accountId);
  }

  static Future<int> netBefore(AppDatabase db, DateTime before, {int? accountId}) async {
    final query = db.select(db.transactions)
      ..where((t) => t.occurredAt.isSmallerThanValue(before));
    if (accountId != null) {
      query.where((t) => t.accountId.equals(accountId));
    }
    final rows = await query.get();
    int net = 0;
    for (final tx in rows) {
      final cents = tx.amountCents;
      if (tx.direction == 'income') {
        net += cents;
      } else if (tx.direction == 'expense') {
        net -= cents;
      }
    }
    return net;
  }

  Future<MonthlyReport> getReportLast7Days() => buildForLastDays(db, 7, accountId: accountId);

  Future<MonthlyReport> getReportForMonth(DateTime anyDayInMonth) =>
      buildForMonth(db, anyDayInMonth, accountId: accountId);

  Future<MonthlyReport> getReportForYear(int year) => buildForYear(db, year, accountId: accountId);

  Future<List<TrendPoint>> getDailyBalanceTrendLast7Days({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final end = dayStart(n).add(const Duration(days: 1));
    final start = end.subtract(const Duration(days: 7));

    final query = db.select(db.transactions)
      ..where((t) => t.occurredAt.isBetweenValues(start, end))
      ..where((t) => t.accountId.equals(accountId))
      ..orderBy([(t) => d.OrderingTerm(expression: t.occurredAt)]);
    final rows = await query.get();

    int balance = await netBefore(db, start, accountId: accountId);

    final dailyNet = <DateTime, int>{};
    for (final tx in rows) {
      final d0 = dayStart(tx.occurredAt);
      if (tx.direction == 'income') {
        dailyNet[d0] = (dailyNet[d0] ?? 0) + tx.amountCents;
      } else if (tx.direction == 'expense') {
        dailyNet[d0] = (dailyNet[d0] ?? 0) - tx.amountCents;
      }
    }

    String two(int v) => v.toString().padLeft(2, '0');

    final out = <TrendPoint>[];
    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      balance += (dailyNet[dayStart(day)] ?? 0);
      final label = '${two(day.month)}/${two(day.day)}';
      out.add(TrendPoint(label, balance / 100.0, date: day));
    }
    return out;
  }

  Future<List<TrendPoint>> getDailyBalanceTrendForMonth(DateTime anyDayInMonth) async {
    final mStart = monthStart(anyDayInMonth);
    final mEnd = nextMonthStart(anyDayInMonth);

    final query = db.select(db.transactions)
      ..where((t) => t.occurredAt.isBetweenValues(mStart, mEnd))
      ..where((t) => t.accountId.equals(accountId))
      ..orderBy([(t) => d.OrderingTerm(expression: t.occurredAt)]);
    final rows = await query.get();

    int balance = await netBefore(db, mStart, accountId: accountId);

    final dailyNet = <DateTime, int>{};
    for (final tx in rows) {
      final d0 = dayStart(tx.occurredAt);
      if (tx.direction == 'income') {
        dailyNet[d0] = (dailyNet[d0] ?? 0) + tx.amountCents;
      } else if (tx.direction == 'expense') {
        dailyNet[d0] = (dailyNet[d0] ?? 0) - tx.amountCents;
      }
    }

    String two(int v) => v.toString().padLeft(2, '0');

    final out = <TrendPoint>[];
    DateTime cursor = mStart;
    while (cursor.isBefore(mEnd)) {
      balance += (dailyNet[dayStart(cursor)] ?? 0);
      final label = '${two(cursor.month)}/${two(cursor.day)}';
      out.add(TrendPoint(label, balance / 100.0, date: cursor));
      cursor = cursor.add(const Duration(days: 1));
    }

    if (out.length == 1) {
      out.insert(0, TrendPoint(out.first.label, out.first.value));
    }
    return out;
  }

  Future<List<TrendPoint>> getMonthlyBalanceTrendForYear(int year) async {
    final yStart = DateTime(year, 1, 1);
    final yEnd = DateTime(year + 1, 1, 1);

    final query = db.select(db.transactions)
      ..where((t) => t.occurredAt.isBetweenValues(yStart, yEnd))
      ..where((t) => t.accountId.equals(accountId))
      ..orderBy([(t) => d.OrderingTerm(expression: t.occurredAt)]);
    final rows = await query.get();

    int balance = await netBefore(db, yStart, accountId: accountId);

    final monthNet = <int, int>{};
    for (final tx in rows) {
      final m = tx.occurredAt.month;
      if (tx.direction == 'income') {
        monthNet[m] = (monthNet[m] ?? 0) + tx.amountCents;
      } else if (tx.direction == 'expense') {
        monthNet[m] = (monthNet[m] ?? 0) - tx.amountCents;
      }
    }

    final out = <TrendPoint>[];
    for (int m = 1; m <= 12; m++) {
      balance += (monthNet[m] ?? 0);
      out.add(TrendPoint(
        m.toString().padLeft(2, '0'),
        balance / 100.0,
        date: DateTime(year, m, 1),
      ));
    }
    return out;
  }

  static Future<Directory> _reportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final reports = Directory('${dir.path}/monthly_reports');
    if (!await reports.exists()) await reports.create(recursive: true);
    return reports;
  }

  static Future<File> _reportFile(String monthKey, {required int accountId}) async {
    final dir = await _reportsDir();
    return File('${dir.path}/acc_${accountId}_$monthKey.json');
  }

  static Future<void> archiveLastMonthIfNeeded(AppDatabase db, {required int accountId}) async {
    final sp = await SharedPreferences.getInstance();
    final prefKey = '$_kLastArchivedMonthPrefix$accountId';
    final lastKey = sp.getString(prefKey);

    final now = DateTime.now();
    final thisKey = monthKey(now);
    if (lastKey == thisKey) return;

    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final report = await buildForMonth(db, lastMonth, accountId: accountId);
    final file = await _reportFile(monthKey(lastMonth), accountId: accountId);
    await file.writeAsString(jsonEncode(report.toJson()));

    await sp.setString(prefKey, thisKey);
  }

  static Future<List<MonthlyReport>> loadAllReports({required int accountId}) async {
    final dir = await _reportsDir();
    final prefix = 'acc_${accountId}_';
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .where((f) => f.uri.pathSegments.last.startsWith(prefix))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    final out = <MonthlyReport>[];
    for (final f in files) {
      final txt = await f.readAsString();
      out.add(MonthlyReport.fromJson(jsonDecode(txt) as Map<String, dynamic>));
    }
    return out;
  }

  static Future<MonthlyReport?> loadReport(String monthKey, {required int accountId}) async {
    final f = await _reportFile(monthKey, accountId: accountId);
    if (!await f.exists()) return null;
    final txt = await f.readAsString();
    return MonthlyReport.fromJson(jsonDecode(txt) as Map<String, dynamic>);
  }

  static Future<void> deleteReport(String monthKey, {required int accountId}) async {
    final f = await _reportFile(monthKey, accountId: accountId);
    if (await f.exists()) await f.delete();
  }
}

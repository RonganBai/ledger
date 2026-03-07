import 'package:flutter/material.dart';

import '../../app/currency.dart';
import '../../data/db/app_database.dart';
import 'history_texts.dart';
import 'models.dart';
import 'report_detail_page.dart';
import 'report_service.dart';

class HistoryPage extends StatefulWidget {
  final AppDatabase db;
  final int accountId;
  final String accountCurrency;

  const HistoryPage({
    super.key,
    required this.db,
    required this.accountId,
    required this.accountCurrency,
  });

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<MonthlyReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MonthlyReport>> _load() async {
    await ReportService.archiveLastMonthIfNeeded(
      widget.db,
      accountId: widget.accountId,
    );
    return ReportService.loadAllReports(accountId: widget.accountId);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  String _money(int cents) {
    final v = cents.abs() / 100.0;
    final s = currencySymbol(widget.accountCurrency);
    return (cents >= 0 ? s : '-$s') + v.toStringAsFixed(2);
  }

  Future<void> _delete(BuildContext context, String monthKey) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(ht(context, 'Delete report?')),
        content: Text(
          ht(
            context,
            'This will remove the archived report file for $monthKey.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ht(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ht(context, 'Delete')),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ReportService.deleteReport(monthKey, accountId: widget.accountId);
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(ht(context, 'History')),
        actions: [
          IconButton(
            tooltip: ht(context, 'Refresh'),
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<MonthlyReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(ht(context, 'Error: ${snap.error}')),
              ),
            );
          }

          final list = snap.data ?? const <MonthlyReport>[];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  ht(
                    context,
                    'No archived monthly reports yet for this account.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = list[i];
              final net = r.netCents;
              final netColor = net >= 0 ? Colors.green : Colors.red;

              return Card(
                child: ListTile(
                  title: Text(
                    r.monthKey,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        Text(
                          '${ht(context, 'Income')}: ${_money(r.incomeCents)}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          '${ht(context, 'Expense')}: ${_money(r.expenseCents)}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(net),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: netColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ht(context, 'Tap to view'),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportDetailPage(
                          report: r,
                          currencyCode: widget.accountCurrency,
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _delete(context, r.monthKey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

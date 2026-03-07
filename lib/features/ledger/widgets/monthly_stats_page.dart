import 'package:flutter/material.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/tr.dart';
import '../../reports/report_service.dart';
import '../../reports/widgets/monthly_stats_sheet.dart';

class MonthlyStatsPage extends StatelessWidget {
  final AppDatabase db;
  final int accountId;
  final String accountCurrency;
  final VoidCallback? onBack;

  const MonthlyStatsPage({
    super.key,
    required this.db,
    required this.accountId,
    required this.accountCurrency,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null ? null : IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        title: Text(tr(context, en: 'Stats', zh: '统计')),
      ),
      body: SafeArea(
        child: MonthlyStatsSheet(
          service: ReportService(db, accountId: accountId),
          currencyCode: accountCurrency,
        ),
      ),
    );
  }
}

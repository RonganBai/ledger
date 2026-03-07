import 'package:flutter/material.dart';
import '../report_service.dart';
import 'balance_trend_line.dart';
import 'expense_pie.dart';


class MonthlyStatsSheet extends StatefulWidget {
  final ReportService service;

  const MonthlyStatsSheet({super.key, required this.service});

  @override
  State<MonthlyStatsSheet> createState() => _MonthlyStatsSheetState();
}

class _MonthlyStatsSheetState extends State<MonthlyStatsSheet> {
  int _selectedIndex = 0;

  final tabs = ['7日', '月', '年'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),

        /// 切换按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tabs.length, (index) {
            final selected = _selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: ChoiceChip(
                label: Text(tabs[index]),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          }),
        ),

        const SizedBox(height: 20),

        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      /// ===== 7日 =====
      case 0:
        return FutureBuilder<List<TrendPoint>>(
          future: widget.service.getDailyBalanceTrendLast7Days(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return BalanceTrendLine(data: snap.data!);
          },
        );

      /// ===== 月 =====
      case 1:
        return SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder<List<TrendPoint>>(
                future: widget.service.getWeeklyBalanceTrendForMonth(DateTime.now()),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return BalanceTrendLine(data: snap.data!);
                },
              ),
              const SizedBox(height: 20),
              FutureBuilder(
                future: widget.service.getMonthlyReport(DateTime.now()),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return ExpensePie(
                    expenseByCategoryCents: snap.data!.expenseByCategoryCents,
                  );
                },
              ),
            ],
          ),
        );

      /// ===== 年 =====
      case 2:
        return FutureBuilder<List<TrendPoint>>(
          future: widget.service.getMonthlyBalanceTrendForYear(DateTime.now().year),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return BalanceTrendLine(data: snap.data!);
          },
        );

      default:
        return const SizedBox();
    }
  }
}

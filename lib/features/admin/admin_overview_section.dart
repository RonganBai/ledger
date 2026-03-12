import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/admin_service.dart';
import 'admin_shared.dart';

class AdminOverviewSection extends StatefulWidget {
  const AdminOverviewSection({super.key});

  @override
  State<AdminOverviewSection> createState() => _AdminOverviewSectionState();
}

class _AdminOverviewSectionState extends State<AdminOverviewSection> {
  final AdminService _service = AdminService();

  bool _loading = true;
  String? _error;
  AdminDashboardMetrics? _metrics;

  String _t(String en, String zh) => tr(context, en: en, zh: zh);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metrics = await _service.getDashboardMetrics();
      if (!mounted) return;
      setState(() => _metrics = metrics);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = humanizeAdminError(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _metrics;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (metrics == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? _t('No dashboard data.', '暂无总览数据。')),
        ),
      );
    }

    final chartMax = metrics.trend.isEmpty
        ? 1.0
        : (metrics.trend.map((item) => item.count).reduce((a, b) => a > b ? a : b) + 1).toDouble();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: _t('Pending Feedback', '未处理反馈'),
              value: '${metrics.pendingFeedbackCount}',
              subtitle: _t('Needs admin follow-up', '等待管理员处理'),
            ),
            _MetricCard(
              title: _t('Suspicious Users', '疑似机器人用户'),
              value: '${metrics.suspiciousUserCount}',
              subtitle: _t(
                'High feedback request frequency in 24h',
                '24 小时内反馈请求频率过高',
              ),
            ),
            _MetricCard(
              title: _t('7-Day Requests', '7 天请求数'),
              value: '${metrics.totalRequestCount}',
              subtitle: metrics.requestDelta >= 0
                  ? _t(
                      'Up ${metrics.requestDelta} vs previous 7 days',
                      '较前 7 天增加 ${metrics.requestDelta}',
                    )
                  : _t(
                      'Down ${metrics.requestDelta.abs()} vs previous 7 days',
                      '较前 7 天减少 ${metrics.requestDelta.abs()}',
                    ),
            ),
            _MetricCard(
              title: _t('Users / Admins / Blocked', '用户 / 管理员 / 封禁'),
              value:
                  '${metrics.totalUserCount} / ${metrics.adminUserCount} / ${metrics.disabledUserCount}',
              subtitle: _t('Current platform breakdown', '当前平台账号分布'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Request Trend', '请求趋势'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _t(
                    'This chart currently uses recorded feedback requests as the request source.',
                    '当前图表暂以已记录的用户反馈请求作为请求来源。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: chartMax,
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: chartMax <= 4 ? 1 : null,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= metrics.trend.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  metrics.trend[index].label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (int i = 0; i < metrics.trend.length; i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: metrics.trend[i].count.toDouble(),
                                width: 20,
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

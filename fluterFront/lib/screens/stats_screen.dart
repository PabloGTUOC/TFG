import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';
import '../utils/json.dart';

/// Port of views/StatsView.vue. The ECharts panels are rendered as
/// lightweight custom bar rows in the same palette (member balances,
/// completion rates, status distribution).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    try {
      final data = await app.api.get('/api/stats/${app.familyId}');
      if (mounted) {
        setState(() {
          _stats = Map<String, dynamic>.from(data as Map);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _listOf(String key) =>
      ((_stats?[key] as List?) ?? [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) {
      return const Center(
          child: Text('No stats available yet.',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    final balances = _listOf('memberBalances');
    final completion = _listOf('completionRates');
    final statuses = _listOf('statusDistribution');
    final caregivers = (_stats?['activeCaregivers'] as List?) ?? [];
    final trend = _listOf('trendByMonth');
    final coinFlow = _listOf('coinFlowByReason');

    // Monthly totals for the trend line (same aggregation as StatsView.vue).
    final trendMonths = trend.map((t) => t['month'].toString()).toSet().toList()
      ..sort();
    final trendTotals = [
      for (final m in trendMonths)
        trend
            .where((t) => t['month'].toString() == m)
            .fold<double>(0, (sum, t) => sum + toNum(t['coins'])),
    ];

    // Stacked coin-flow series in the same order/colours as the Vue chart.
    const flowMeta = [
      ('activity_completed', 'Activities', AppColors.primary),
      ('bounty_earned', 'Bounties Earned', AppColors.success),
      ('bounty_escrow', 'Bounties Paid', AppColors.danger),
      ('redeemed', 'Rewards Redeemed', AppColors.warning),
      ('bounty_refunded', 'Bounties Refunded', Color(0xFF94A3B8)),
    ];
    final flowMonths =
        coinFlow.map((d) => d['month'].toString()).toSet().toList()..sort();
    final flowSeries = [
      for (final (reason, label, color) in flowMeta)
        if (coinFlow.any((d) => d['reason'] == reason))
          StackedBarSeries(label, color, [
            for (final m in flowMonths)
              toNum(coinFlow.firstWhere(
                (d) => d['month'].toString() == m && d['reason'] == reason,
                orElse: () => const {'total': 0},
              )['total'])
                  .toDouble(),
          ]),
    ];

    final maxBalance = balances.fold<num>(1,
        (m, b) => toNum(b['coin_balance']) > m ? toNum(b['coin_balance']) : m);

    const statusMeta = {
      'approved': ('Approved', AppColors.success, AppColors.successSoft),
      'completed': ('Completed', AppColors.primary, AppColors.primarySoft),
      'pending': ('Pending', AppColors.warning, AppColors.warningSoft),
      'pending_validation': (
        'Awaiting validation',
        AppColors.warning,
        AppColors.warningSoft
      ),
      'rejected': ('Rejected', AppColors.danger, AppColors.dangerSoft),
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const PageHeading(
              title: 'Family Stats',
              subtitle: 'How care work is distributed across the family.'),
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > kMobileBreakpoint ? 2 : 1;
            final w = (c.maxWidth - (perRow - 1) * 16) / perRow;
            final totalDone = completion.fold<num>(
                0, (acc, r) => acc + toNum(r['completed']));
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                    width: w,
                    child: KpiCard(
                        label: 'Active caregivers',
                        value: '${caregivers.length}',
                        subtitle: 'Sharing the load right now')),
                SizedBox(
                    width: w,
                    child: KpiCard(
                        label: 'Tasks completed',
                        value: '$totalDone',
                        accent: AppColors.success,
                        subtitle: 'Across all caregivers')),
              ],
            );
          }),
          const SizedBox(height: 24),
          if (trendMonths.isNotEmpty)
            VCard(
              title: 'Coins Earned Trend',
              child: LineAreaChart(labels: trendMonths, values: trendTotals),
            ),
          if (flowSeries.isNotEmpty)
            VCard(
              title: 'Coin Flow by Month',
              child: StackedBarChart(labels: flowMonths, series: flowSeries),
            ),
          if (balances.isNotEmpty)
            VCard(
              title: 'Member Balances',
              child: Column(
                children: [
                  for (final b in balances)
                    _BarRow(
                      label: (b['name'] ?? '').toString(),
                      valueLabel: '${b['coin_balance'] ?? 0} cc',
                      fraction: toNum(b['coin_balance']) / maxBalance,
                      color: b['role'] == 'caregiver'
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                ],
              ),
            ),
          if (completion.isNotEmpty)
            VCard(
              title: 'Completion Rates',
              child: Column(
                children: [
                  for (final r in completion)
                    Builder(builder: (_) {
                      final total = toNum(r['total']);
                      final done = toNum(r['completed']);
                      final rate = total > 0 ? (100 * done / total).round() : 0;
                      return _BarRow(
                        label: (r['caregiver'] ?? '').toString(),
                        valueLabel: '$rate% ($done/$total)',
                        fraction: rate / 100,
                        color: rate >= 80
                            ? AppColors.success
                            : rate >= 50
                                ? AppColors.warning
                                : AppColors.danger,
                      );
                    }),
                ],
              ),
            ),
          if (statuses.isNotEmpty)
            VCard(
              title: 'Task Status Distribution',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final s in statuses)
                    Builder(builder: (_) {
                      final meta = statusMeta[s['status']] ??
                          (
                            s['status'].toString(),
                            AppColors.textSecondary,
                            AppColors.bg
                          );
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: meta.$3,
                            borderRadius: BorderRadius.circular(AppRadii.md)),
                        child: Column(
                          children: [
                            Text('${s['count'] ?? 0}',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: meta.$2)),
                            Text(meta.$1,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: meta.$2)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double fraction;
  final Color color;

  const _BarRow(
      {required this.label,
      required this.valueLabel,
      required this.fraction,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(valueLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.bg,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

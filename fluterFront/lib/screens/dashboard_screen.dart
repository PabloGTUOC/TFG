import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import '../utils/json.dart';
import 'daily_screen.dart';

/// Port of views/DashboardView.vue: Family Hub — member cards, week strip,
/// task offers and KPI summary.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboard = {
    'members': [],
    'calendar': [],
    'objectsOfCare': []
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    if (app.familyId == 0) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await app.api.get('/api/dashboard/${app.familyId}');
      if (mounted) {
        setState(() {
          _dashboard = Map<String, dynamic>.from(data as Map);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _members =>
      ((_dashboard['members'] as List?) ?? [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  List<Map<String, dynamic>> get _calendar =>
      ((_dashboard['calendar'] as List?) ?? [])
          .cast<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  Future<void> _approveMember(dynamic userId) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api
          .post('/api/families/${app.familyId}/members/$userId/approve');
      await _load();
    }, 'Member approved!');
  }

  void _openDaily(DateTime day) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            DailyScreen(date: DateFormat('yyyy-MM-dd').format(day))));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final active = _members.where((m) => m['status'] != 'pending').toList();
    final pending = _members.where((m) => m['status'] == 'pending').toList();
    final objects = ((_dashboard['objectsOfCare'] as List?) ?? [])
        .cast<Map>()
        .map((m) => m.cast<String, dynamic>())
        .toList();
    final totalCoins =
        _members.fold<num>(0, (acc, m) => acc + toNum(m['coin_balance']));

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final today = DateTime(now.year, now.month, now.day);
    final todayActs = _calendar.where((a) {
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null && DateTime(ts.year, ts.month, ts.day) == today;
    }).toList();
    final offers = _calendar
        .where(
            (a) => toNum(a['bounty_amount']) > 0 && a['status'] != 'completed')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const PageHeading(
              title: 'Family Hub',
              subtitle:
                  'Everyone\'s balances, this week\'s care plan and open offers.'),

          // ── Active members ──
          const _SectionTitle('Active Family Members'),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (var i = 0; i < active.length; i++)
                _MemberCard(
                  name: (active[i]['name'] ?? 'User ${active[i]['user_id']}')
                      .toString(),
                  balance: toNum(active[i]['coin_balance']),
                  colorIndex: i,
                ),
              for (var i = 0; i < objects.length; i++)
                _MemberCard(
                  name: (objects[i]['name'] ?? 'Dependent').toString(),
                  balance: null,
                  colorIndex: active.length + i,
                ),
            ],
          ),

          if (pending.isNotEmpty) ...[
            const SizedBox(height: 28),
            const _SectionTitle('Pending Approval'),
            for (final pm in pending)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    AvatarCircle(
                        name: (pm['name'] ?? '?').toString(),
                        size: 40,
                        background: AppColors.bg,
                        foreground: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            (pm['name'] ?? 'User ${pm['user_id']}').toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    VButton(
                        type: VButtonType.outline,
                        onPressed: () => _approveMember(pm['user_id']),
                        child: const Text('Approve')),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 32),

          // ── Week strip ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 20,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('MMM d').format(monday)} – ${DateFormat('MMM d').format(monday.add(const Duration(days: 6)))}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, height: 1),
                ),
                const SizedBox(height: 4),
                const Text('This week',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var d = 0; d < 7; d++)
                        _DayColumn(
                          day: monday.add(Duration(days: d)),
                          acts: _calendar.where((a) {
                            final ts = DateTime.tryParse(
                                a['starts_at']?.toString() ?? '');
                            if (ts == null) return false;
                            final dd = monday.add(Duration(days: d));
                            return ts.year == dd.year &&
                                ts.month == dd.month &&
                                ts.day == dd.day;
                          }).toList(),
                          onTap: () =>
                              _openDaily(monday.add(Duration(days: d))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Offers ──
          if (offers.isNotEmpty) ...[
            const _SectionTitle('Task Offers & Bribes'),
            for (final offer in offers)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: AppColors.bg, shape: BoxShape.circle),
                      child: Text(offer['category'] == 'care' ? '❤️' : '🍽️',
                          style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((offer['title'] ?? '').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          if (offer['starts_at'] != null)
                            Text(
                                DateFormat('EEE d MMM · HH:mm').format(
                                    DateTime.parse(
                                        offer['starts_at'].toString())),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    PillBadge(text: '+${offer['bounty_amount']}cc'),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],

          // ── KPIs ──
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > kMobileBreakpoint ? 3 : 1;
            final w = (c.maxWidth - (perRow - 1) * 16) / perRow;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                    width: w,
                    child: KpiCard(
                        label: 'Family coins',
                        value: NumberFormat.decimalPattern().format(totalCoins),
                        unit: 'cc',
                        subtitle: 'Combined balance of all members')),
                SizedBox(
                    width: w,
                    child: KpiCard(
                        label: 'Tasks today',
                        value:
                            '${todayActs.where((a) => a['status'] == 'completed').length}/${todayActs.length}',
                        accent: AppColors.success,
                        subtitle: 'Completed vs scheduled',
                        progress: todayActs.isEmpty
                            ? 0
                            : 100 *
                                todayActs
                                    .where((a) => a['status'] == 'completed')
                                    .length /
                                todayActs.length)),
                SizedBox(
                    width: w,
                    child: KpiCard(
                        label: 'Members',
                        value: '${active.length}',
                        accent: AppColors.warning,
                        subtitle: pending.isEmpty
                            ? 'All approved'
                            : '${pending.length} pending approval')),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String name;
  final num? balance;
  final int colorIndex;

  const _MemberCard(
      {required this.name, required this.balance, required this.colorIndex});

  @override
  Widget build(BuildContext context) {
    final soft = AppColors.softAccents[colorIndex % 4];
    final accent = AppColors.accents[colorIndex % 4];
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        children: [
          AvatarCircle(
              name: name, size: 56, background: soft, foreground: accent),
          const SizedBox(height: 10),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (balance != null)
            PillBadge(text: '$balance cc')
          else
            const PillBadge(
                text: 'cared for',
                color: AppColors.textSecondary,
                background: AppColors.bg),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final DateTime day;
  final List<Map<String, dynamic>> acts;
  final VoidCallback onTap;

  const _DayColumn(
      {required this.day, required this.acts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minHeight: 220),
        decoration: BoxDecoration(
          color: isToday ? AppColors.primarySoft : AppColors.bg,
          border:
              Border.all(color: isToday ? AppColors.primary : AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Text(DateFormat('EEE').format(day),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color:
                        isToday ? AppColors.primary : AppColors.textSecondary)),
            Text('${day.day}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color:
                        isToday ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 8),
            for (final a in acts) _ActChip(a: a),
          ],
        ),
      ),
    );
  }
}

class _ActChip extends StatelessWidget {
  final Map<String, dynamic> a;
  const _ActChip({required this.a});

  @override
  Widget build(BuildContext context) {
    final status = a['status']?.toString() ?? '';
    final isCare = a['category'] == 'care';

    Color bg, fg;
    Border? border;
    if (status == 'rejected') {
      bg = AppColors.dangerSoft;
      fg = AppColors.danger;
    } else if (status == 'completed') {
      bg = isCare ? AppColors.success : AppColors.warning;
      fg = Colors.white;
    } else {
      bg = AppColors.surface;
      fg = AppColors.textPrimary;
      border = Border.all(color: AppColors.border);
    }

    final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          border: border,
          borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${status == 'rejected' ? '⚠️ ' : ''}${a['title'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
              if (toNum(a['bounty_amount']) > 0)
                Text('+${a['bounty_amount']}cc',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.warning)),
            ],
          ),
          if (ts != null)
            Text(DateFormat('HH:mm').format(ts),
                style:
                    TextStyle(fontSize: 9, color: fg.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

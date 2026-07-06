import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/json.dart';
import '../widgets/absence_dialog.dart';
import '../widgets/ui.dart';
import 'daily_screen.dart';

/// Port of views/DashboardView.vue: Family Hub — member cards, paginated week
/// strip with absences, task offers, KPI summary and the Recent Activity feed.
class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenStats;

  const DashboardScreen({super.key, this.onOpenStats});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboard = {
    'members': [],
    'calendar': [],
    'objectsOfCare': []
  };
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _claimed = [];
  List<Map<String, dynamic>> _absences = [];
  int _weekOffset = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _asMaps(dynamic list) => ((list as List?) ?? [])
      .cast<Map>()
      .map((m) => m.cast<String, dynamic>())
      .toList();

  Future<void> _load() async {
    final app = context.read<AppState>();
    if (app.familyId == 0) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await app.api.get('/api/dashboard/${app.familyId}');
      final acts = await app.api.get('/api/activities?familyId=${app.familyId}');
      List<Map<String, dynamic>> claimed = [];
      try {
        final rewards =
            await app.api.get('/api/marketplace/rewards/${app.familyId}');
        claimed = _asMaps(rewards['claimed']);
      } catch (_) {}
      List<Map<String, dynamic>> absences = [];
      try {
        final abs = await app.api.get('/api/absences?familyId=${app.familyId}');
        absences = _asMaps(abs['absences']);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _dashboard = Map<String, dynamic>.from(data as Map);
          _activities = _asMaps(acts['activities']);
          _claimed = claimed;
          _absences = absences;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _members => _asMaps(_dashboard['members']);

  /// Port of scheduledInstances: non-template activities with a start time.
  List<Map<String, dynamic>> get _scheduled => _activities
      .where((a) => a['is_template'] != true && a['starts_at'] != null)
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

  Future<void> _logTimeOff() async {
    final created = await showLogAbsenceDialog(context, day: DateTime.now());
    if (created) await _load();
  }

  // ── Week strip (port of weekDays / processedWeekDays) ────────────

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: _weekOffset * 7));
    return [for (var d = 0; d < 7; d++) monday.add(Duration(days: d))];
  }

  String get _weekLabel {
    final first = _weekDays.first, last = _weekDays.last;
    if (first.month == last.month) {
      return '${DateFormat('MMM').format(first)} ${first.day} — ${last.day}';
    }
    return '${DateFormat('MMM d').format(first)} — ${DateFormat('MMM d').format(last)}';
  }

  List<Map<String, dynamic>> _absencesOn(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _absences.where((a) {
      final start = DateTime.tryParse(a['start_time']?.toString() ?? '');
      final end = DateTime.tryParse(a['end_time']?.toString() ?? '');
      if (start == null || end == null) return false;
      return start.isBefore(dayEnd) && end.isAfter(dayStart);
    }).toList();
  }

  List<Map<String, dynamic>> _actsOn(DateTime day) {
    final acts = _scheduled.where((a) {
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null &&
          ts.year == day.year &&
          ts.month == day.month &&
          ts.day == day.day;
    }).toList();
    acts.sort((a, b) => (a['starts_at']?.toString() ?? '')
        .compareTo(b['starts_at']?.toString() ?? ''));
    return acts;
  }

  // ── Recent activity feed (port of recentActivitiesList) ─────────

  List<_FeedItem> get _recentActivity {
    final items = <_FeedItem>[
      for (final a in _scheduled)
        if (a['status'] == 'completed')
          _FeedItem(
            icon: '✓',
            color: AppColors.primary,
            background: AppColors.primarySoft,
            actor: (a['assigned_to_name'] ?? 'Someone').toString(),
            verb: 'completed',
            subject: (a['title'] ?? '').toString(),
            time: DateTime.tryParse(a['starts_at']?.toString() ?? ''),
            coinText: '+${toNum(a['coin_value'])} cc',
            coinColor: AppColors.success,
          ),
      for (final r in _claimed)
        _FeedItem(
          icon: '🛍️',
          color: AppColors.danger,
          background: AppColors.dangerSoft,
          actor: (r['buyer_name'] ?? 'Someone').toString(),
          verb: 'got',
          subject: (r['title'] ?? '').toString(),
          time: DateTime.tryParse(r['redeemed_at']?.toString() ?? ''),
          coinText: '-${toNum(r['cost'])} cc',
          coinColor: AppColors.danger,
        ),
    ].where((i) => i.time != null).toList();
    items.sort((a, b) => b.time!.compareTo(a.time!));
    return items.take(3).toList();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final app = context.watch<AppState>();
    final active = _members.where((m) => m['status'] != 'pending').toList();
    final pending = _members.where((m) => m['status'] == 'pending').toList();
    final objects = _asMaps(_dashboard['objectsOfCare']);
    final totalCoins =
        _members.fold<num>(0, (acc, m) => acc + toNum(m['coin_balance']));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday = _scheduled.where((a) {
      if (a['status'] != 'completed') return false;
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null && DateTime(ts.year, ts.month, ts.day) == today;
    }).length;
    final todayActs = _scheduled.where((a) {
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null && DateTime(ts.year, ts.month, ts.day) == today;
    }).length;
    final pendingTasks = _activities
        .where((a) =>
            a['status'] == 'pending_validation' || a['status'] == 'pending')
        .length;
    final offers = _scheduled
        .where(
            (a) => toNum(a['bounty_amount']) > 0 && a['status'] != 'completed')
        .toList();
    final bountyTotal =
        offers.fold<num>(0, (acc, o) => acc + toNum(o['bounty_amount']));
    final recent = _recentActivity;
    final greetName =
        (app.family?['alias'] ?? app.profile?['display_name'] ?? 'Caregiver')
            .toString();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          PageHeading(
              title: 'Family Hub',
              subtitle:
                  '$_greeting, $greetName! Your family has earned $totalCoins cc today. '
                  '$pendingTasks tasks are waiting for attention.'),

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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('This week',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(_weekLabel,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VButton(
                            type: VButtonType.outline,
                            onPressed: _logTimeOff,
                            child: const Text('+ Log Time Off')),
                        const SizedBox(width: 8),
                        _PaginationButton(
                            label: '«',
                            onTap: () => setState(() => _weekOffset--)),
                        const SizedBox(width: 8),
                        _PaginationButton(
                            label: '»',
                            onTap: () => setState(() => _weekOffset++)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in _weekDays)
                        _DayColumn(
                          day: day,
                          acts: _actsOn(day),
                          absences: _absencesOn(day),
                          onTap: () => _openDaily(day),
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
            Row(
              children: [
                const Expanded(child: _SectionTitle('Task Offers & Bribes')),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PillBadge(text: '${offers.length} open'),
                ),
              ],
            ),
            for (final offer in offers)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () {
                  final ts =
                      DateTime.tryParse(offer['starts_at']?.toString() ?? '');
                  if (ts != null) _openDaily(ts);
                },
                child: Container(
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
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
              ),
            const SizedBox(height: 20),
          ],

          // ── KPIs ──
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth > kMobileBreakpoint ? 4 : 2;
            final w = (c.maxWidth - (perRow - 1) * 14) / perRow;
            return InkWell(
              onTap: widget.onOpenStats,
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                      width: w,
                      child: KpiCard(
                          label: 'Family Balance',
                          value:
                              NumberFormat.decimalPattern().format(totalCoins),
                          unit: 'cc',
                          subtitle:
                              'across ${_members.length} ${_members.length == 1 ? 'member' : 'members'}')),
                  SizedBox(
                      width: w,
                      child: KpiCard(
                          label: 'Tasks Today',
                          value: '$completedToday/$todayActs',
                          accent: AppColors.success,
                          subtitle: pendingTasks > 0
                              ? '$pendingTasks awaiting validation'
                              : 'on track',
                          progress: todayActs == 0
                              ? 0
                              : 100 * completedToday / todayActs)),
                  SizedBox(
                      width: w,
                      child: KpiCard(
                          label: 'Open Bounties',
                          value: '${offers.length}',
                          accent: AppColors.warning,
                          subtitle: offers.isEmpty
                              ? 'No bounties open'
                              : '$bountyTotal cc up for grabs')),
                  SizedBox(
                      width: w,
                      child: KpiCard(
                          label: 'Recent Activity',
                          value: '${recent.length}',
                          accent: AppColors.textPrimary,
                          subtitle: recent.isEmpty
                              ? 'no recent activity'
                              : 'completed recently')),
                ],
              ),
            );
          }),

          const SizedBox(height: 32),

          // ── Recent Activity feed ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Activity',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                if (recent.isEmpty)
                  const Text('No activity yet.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                for (final item in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: item.background, shape: BoxShape.circle),
                          child: Text(item.icon,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: item.color)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(text: '${item.actor} '),
                                  TextSpan(
                                      text: item.verb,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary)),
                                  TextSpan(text: ' ${item.subject}'),
                                ]),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    height: 1.3),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Text(item.timeAgo,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(width: 8),
                                  Text(item.coinText,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: item.coinColor)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                VButton(
                    type: VButtonType.outline,
                    block: true,
                    onPressed: widget.onOpenStats,
                    child: const Text('See all activity')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the Recent Activity feed (activity completed / reward claimed).
class _FeedItem {
  final String icon;
  final Color color;
  final Color background;
  final String actor;
  final String verb;
  final String subject;
  final DateTime? time;
  final String coinText;
  final Color coinColor;

  _FeedItem({
    required this.icon,
    required this.color,
    required this.background,
    required this.actor,
    required this.verb,
    required this.subject,
    required this.time,
    required this.coinText,
    required this.coinColor,
  });

  String get timeAgo {
    final ms = DateTime.now().difference(time!);
    if (ms.inHours > 24) return '${ms.inHours ~/ 24} days ago';
    if (ms.inHours > 0) return '${ms.inHours} hours ago';
    return '${ms.inMinutes.clamp(1, 59)} mins ago';
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PaginationButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border),
          shape: BoxShape.circle,
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
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
  final List<Map<String, dynamic>> absences;
  final VoidCallback onTap;

  const _DayColumn(
      {required this.day,
      required this.acts,
      required this.absences,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final hasAbsence = absences.isNotEmpty;

    final bg = hasAbsence
        ? AppColors.dangerSoft
        : (isToday ? AppColors.primarySoft : AppColors.bg);
    final borderColor = hasAbsence
        ? AppColors.dangerSoft
        : (isToday ? AppColors.primary : AppColors.border);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minHeight: 220),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    Text(DateFormat('EEE').format(day),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textSecondary)),
                    Text('${day.day}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textPrimary)),
                  ],
                ),
                if (hasAbsence)
                  const Positioned(
                      top: -2,
                      right: -34,
                      child: Text('✈️', style: TextStyle(fontSize: 13))),
              ],
            ),
            const SizedBox(height: 8),
            for (final abs in absences) _AbsenceChip(abs: abs),
            for (final a in acts) _ActChip(a: a),
          ],
        ),
      ),
    );
  }
}

class _AbsenceChip extends StatelessWidget {
  final Map<String, dynamic> abs;
  const _AbsenceChip({required this.abs});

  @override
  Widget build(BuildContext context) {
    final who = (abs['user_alias'] ?? abs['user_name'] ?? '').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadii.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('✈️ ${who.toUpperCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.danger)),
          Text((abs['title'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: AppColors.danger)),
        ],
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

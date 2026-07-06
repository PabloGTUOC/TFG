import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/DailyView.vue: day timeline with schedule/validate/remove,
/// bounties (delegate / take over), recurrence, absences and day-swipe.
class DailyScreen extends StatefulWidget {
  final String date; // yyyy-MM-dd
  const DailyScreen({super.key, required this.date});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _absences = [];
  bool _loading = true;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    _day = DateTime.parse(widget.date);
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    try {
      final results = await Future.wait([
        app.api.get('/api/activities?familyId=${app.familyId}'),
        app.api.get('/api/absences?familyId=${app.familyId}'),
      ]);
      final acts = results[0] is List
          ? results[0] as List
          : (results[0]['activities'] as List? ?? []);
      final abs = results[1] is List
          ? results[1] as List
          : (results[1]['absences'] as List? ?? []);
      if (mounted) {
        setState(() {
          _activities = acts.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
          _absences = abs.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Map<String, dynamic>> get _dayItems {
    final items = _activities.where((a) {
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null && _sameDay(ts.toLocal(), _day);
    }).toList();
    items.sort((a, b) =>
        (a['starts_at']?.toString() ?? '').compareTo(b['starts_at']?.toString() ?? ''));
    return items;
  }

  List<Map<String, dynamic>> get _dayAbsences => _absences.where((a) {
        final start = DateTime.tryParse(a['start_time']?.toString() ?? '');
        final end = DateTime.tryParse(a['end_time']?.toString() ?? '');
        if (start == null) return false;
        final dayStart = DateTime(_day.year, _day.month, _day.day);
        final dayEnd = dayStart.add(const Duration(days: 1));
        return start.isBefore(dayEnd) && (end ?? start).isAfter(dayStart);
      }).toList();

  /// Same predicate as the Vue task sheet: approved templates only.
  List<Map<String, dynamic>> get _templates => _activities
      .where((a) => a['is_template'] == true && a['status'] == 'approved')
      .toList();

  int get _completedCount =>
      _dayItems.where((a) => a['status'] == 'completed').length;

  void _changeDay(int delta) =>
      setState(() => _day = _day.add(Duration(days: delta)));

  // ── Actions (payloads mirror DailyView.vue) ─────────────────────

  Future<void> _validate(dynamic id) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post('/api/activities/$id/validate');
      await _load();
    }, 'Activity validated! Coins awarded to the user.');
  }

  Future<void> _unschedule(dynamic id, {required bool series}) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.delete('/api/activities/$id${series ? '?series=true' : ''}');
      await _load();
    }, series ? 'Entire recurring series removed.' : 'Activity removed from schedule.');
  }

  Future<void> _removeFlow(Map<String, dynamic> a) async {
    if (a['is_recurrent'] == true) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          title: const Text('Remove recurring task?',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Text('"${a['title']}" repeats. Remove just this one or the whole series?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'single'),
                child: const Text('This one')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'series'),
                child: const Text('Whole series',
                    style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (choice == null) return;
      await _unschedule(a['id'], series: choice == 'series');
    } else {
      await _unschedule(a['id'], series: false);
    }
  }

  Future<void> _openBountyDialog(Map<String, dynamic> a) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Delegate with a bounty',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Offer CareCoins so another caretaker takes "${a['title']}".',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            VInput(
                controller: controller,
                label: 'Bounty (cc)',
                placeholder: 'e.g. 15',
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Offer bounty')),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post('/api/activities/${a['id']}/bounty', {'bountyAmount': amount});
      await _load();
    }, 'Bounty added! Another caretaker can now take this task.');
  }

  Future<void> _acceptBounty(Map<String, dynamic> a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Take over this task?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'You\'ll take "${a['title']}" and earn +${a['bounty_amount']}cc on top of its value.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Take over')),
        ],
      ),
    );
    if (ok != true) return;
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post('/api/activities/${a['id']}/accept-bounty');
      await app.fetchUserData();
      await _load();
    }, 'Task taken! Coins added to your account.');
  }

  Future<void> _openRecurrenceDialog(Map<String, dynamic> a) async {
    var frequency = 'daily';
    DateTime? until;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          title: const Text('Schedule Future Copies',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repeat "${a['title']}" at this time into the future.',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: frequency,
                decoration: const InputDecoration(labelText: 'Frequency'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Every Day')),
                  DropdownMenuItem(
                      value: 'weekdays', child: Text('Every Working Day (Mon–Fri)')),
                  DropdownMenuItem(
                      value: 'weekly', child: Text('Every Week (same day)')),
                ],
                onChanged: (v) => setLocal(() => frequency = v ?? 'daily'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _day.add(const Duration(days: 7)),
                    firstDate: _day,
                    lastDate: _day.add(const Duration(days: 365)),
                  );
                  if (picked != null) setLocal(() => until = picked);
                },
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(until == null
                    ? 'Pick until date'
                    : 'Until ${DateFormat('d MMM yyyy').format(until!)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
                onPressed: until == null ? null : () => Navigator.pop(ctx, true),
                child: const Text('Create copies')),
          ],
        ),
      ),
    );
    if (confirmed != true || until == null) return;
    final app = context.read<AppState>();
    await app.runAction(() async {
      final res = await app.api.post('/api/activities/${a['id']}/recurrence', {
        'frequency': frequency,
        'untilDate': DateFormat('yyyy-MM-dd').format(until!),
      });
      await _load();
      app.setSuccess('Created ${res['created']} future instances!');
    });
  }

  Future<void> _openAbsenceDialog() async {
    final title = TextEditingController();
    var start = DateTime(_day.year, _day.month, _day.day, 9);
    var end = DateTime(_day.year, _day.month, _day.day, 18);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          title: const Text('Log time off', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VInput(controller: title, label: 'Title', placeholder: 'e.g. Business trip'),
              const SizedBox(height: 12),
              for (final (label, get, set) in [
                ('From', () => start, (DateTime d) => start = d),
                ('To', () => end, (DateTime d) => end = d),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: ctx,
                          initialDate: get(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d == null || !ctx.mounted) return;
                      final t = await showTimePicker(
                          context: ctx, initialTime: TimeOfDay.fromDateTime(get()));
                      if (t == null) return;
                      setLocal(() =>
                          set(DateTime(d.year, d.month, d.day, t.hour, t.minute)));
                    },
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                        '$label: ${DateFormat('d MMM HH:mm').format(get())}'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final app = context.read<AppState>();
    if (title.text.trim().isEmpty) {
      app.setError('Please fill in all fields.');
      return;
    }
    await app.runAction(() async {
      await app.api.post('/api/absences', {
        'familyId': app.familyId,
        'title': title.text.trim(),
        'startTime': start.toUtc().toIso8601String(),
        'endTime': end.toUtc().toIso8601String(),
      });
      await _load();
    }, 'Time off logged successfully!');
  }

  Future<void> _absenceDetail(Map<String, dynamic> abs) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: Text('✈️ ${abs['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            '${abs['user_alias'] ?? abs['user_name'] ?? 'A caregiver'} is away\n'
            '${DateFormat('d MMM HH:mm').format(DateTime.parse(abs['start_time'].toString()).toLocal())}'
            ' → ${DateFormat('d MMM HH:mm').format(DateTime.parse(abs['end_time'].toString()).toLocal())}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (delete != true) return;
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.delete('/api/absences/${abs['id']}');
      await _load();
    }, 'Time off record removed.');
  }

  Future<void> _openScheduleSheet() async {
    if (_templates.isEmpty) {
      context
          .read<AppState>()
          .setError('No approved tasks in the library yet — create one in Activities.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _TaskSheet(templates: _templates),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted) return;

    final app = context.read<AppState>();
    final startsAt = DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);

    // Same guard as the Vue app: block scheduling inside your own absence.
    final overlaps = _dayAbsences.any((abs) {
      if (abs['user_id']?.toString() != app.userId?.toString()) return false;
      final s = DateTime.tryParse(abs['start_time']?.toString() ?? '');
      final e = DateTime.tryParse(abs['end_time']?.toString() ?? '');
      if (s == null || e == null) return false;
      return s.isBefore(startsAt.add(const Duration(hours: 1))) && e.isAfter(startsAt);
    });
    if (overlaps) {
      app.setError('You cannot schedule activities during a logged absence.');
      return;
    }

    await app.runAction(() async {
      await app.api.post('/api/activities/${picked['id']}/schedule',
          {'startsAt': startsAt.toUtc().toIso8601String()});
      await _load();
    }, 'Activity successfully scheduled!');
  }

  @override
  Widget build(BuildContext context) {
    final items = _dayItems;
    final absences = _dayAbsences;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                onPressed: () => _changeDay(-1),
                icon: const Icon(Icons.chevron_left_rounded)),
            Text(DateFormat('EEE, MMM d').format(_day),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            IconButton(
                onPressed: () => _changeDay(1),
                icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log time off',
            onPressed: _openAbsenceDialog,
            icon: const Icon(Icons.flight_takeoff_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScheduleSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              // Day-swipe like useDaySwipe.js
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -300) _changeDay(1);
                if (v > 300) _changeDay(-1);
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      // Done-today progress (completed-bar)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Done today',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    child: LinearProgressIndicator(
                                      value: items.isEmpty
                                          ? 0
                                          : _completedCount / items.length,
                                      minHeight: 6,
                                      backgroundColor: AppColors.bg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text('$_completedCount / ${items.length} done',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ),
                      ),

                      // Absences
                      for (final abs in absences)
                        GestureDetector(
                          onTap: () => _absenceDetail(abs),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Row(
                              children: [
                                const Text('✈️', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${abs['user_alias'] ?? abs['user_name'] ?? 'Away'} · ${abs['title']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 28, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              const Text('Your day is wide open.',
                                  style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: _openScheduleSheet,
                                child: const Text('Tap here to schedule a task.'),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final a in items) _buildCard(a),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a) {
    final status = a['status']?.toString() ?? 'pending';
    final removable = status != 'completed';

    final card = _TimelineCard(
      item: a,
      onValidate: () => _validate(a['id']),
      onDelegate: () => _openBountyDialog(a),
      onTakeOver: () => _acceptBounty(a),
      onRecurrence: () => _openRecurrenceDialog(a),
    );

    if (!removable) return card;

    // Swipe-to-remove with a visible affordance (revealed trash background).
    return Dismissible(
      key: ValueKey('act-${a['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _removeFlow(a);
        return false; // list refresh handles removal
      },
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12, left: 52),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: AppColors.danger),
            SizedBox(width: 6),
            Text('Remove',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      child: card,
    );
  }
}

/// Bottom sheet task library with search + category filter (mobile task sheet).
class _TaskSheet extends StatefulWidget {
  final List<Map<String, dynamic>> templates;
  const _TaskSheet({required this.templates});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _search = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.toLowerCase();
    final filtered = widget.templates.where((t) {
      if (_filter == 1 && t['category'] != 'care') return false;
      if (_filter == 2 && t['category'] != 'household') return false;
      if (q.isNotEmpty && !(t['title']?.toString().toLowerCase().contains(q) ?? false)) {
        return false;
      }
      return true;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add a task',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Search tasks…',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SegmentedTabs(
                      tabs: const ['All', 'Care', 'Household'],
                      selected: _filter,
                      onChanged: (i) => setState(() => _filter = i),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  children: [
                    for (final t in filtered)
                      ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md)),
                        leading: Text(t['category'] == 'care' ? '❤️' : '🍽️',
                            style: const TextStyle(fontSize: 20)),
                        title: Text((t['title'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: PillBadge(text: '${t['coin_value'] ?? 0} cc'),
                        onTap: () => Navigator.of(context).pop(t),
                      ),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('No matching tasks.',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onValidate;
  final VoidCallback onDelegate;
  final VoidCallback onTakeOver;
  final VoidCallback onRecurrence;

  const _TimelineCard({
    required this.item,
    required this.onValidate,
    required this.onDelegate,
    required this.onTakeOver,
    required this.onRecurrence,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final status = item['status']?.toString() ?? 'pending';
    final isCare = item['category'] == 'care';
    final ts = DateTime.tryParse(item['starts_at']?.toString() ?? '')?.toLocal();
    final bounty = (item['bounty_amount'] as num?) ?? 0;
    final mine = item['assigned_to']?.toString() == app.userId?.toString();
    final isRecurrent = item['is_recurrent'] == true;

    // Same decision tree as the Vue timeline card actions.
    Widget action;
    if (status == 'pending_validation') {
      action = (!mine && app.isCaregiver)
          ? VButton(
              type: VButtonType.outline,
              onPressed: onValidate,
              child: const Text('✓ Validate', style: TextStyle(fontSize: 13)))
          : const PillBadge(
              text: 'Awaiting validation',
              color: AppColors.warning,
              background: AppColors.warningSoft,
              fontSize: 11);
    } else if (status == 'completed') {
      action = const PillBadge(
          text: '✓ Done',
          color: AppColors.success,
          background: AppColors.successSoft,
          fontSize: 11);
    } else if (status == 'rejected') {
      action = const PillBadge(
          text: '⚠️ Rejected',
          color: AppColors.danger,
          background: AppColors.dangerSoft,
          fontSize: 11);
    } else {
      // pending / approved
      if (mine && bounty == 0 && app.isCaregiver) {
        action = TextButton(
          onPressed: onDelegate,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.warningSoft,
            foregroundColor: AppColors.warning,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                side: const BorderSide(color: AppColors.warning)),
          ),
          child: const Text('Delegate (-cc)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        );
      } else if (mine && bounty > 0) {
        action = PillBadge(
            text: 'Offering: ${bounty}cc',
            color: AppColors.warning,
            background: AppColors.warningSoft,
            fontSize: 11);
      } else if (!mine && bounty > 0 && app.isCaregiver) {
        action = TextButton(
          onPressed: onTakeOver,
          style: TextButton.styleFrom(
            backgroundColor: AppColors.successSoft,
            foregroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                side: const BorderSide(color: AppColors.success)),
          ),
          child: Text('Take Over (+${bounty}cc)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        );
      } else {
        action = PillBadge(
            text: 'Assigned to ${item['assigned_alias'] ?? 'Caregiver'}',
            color: AppColors.textSecondary,
            background: AppColors.bg,
            fontSize: 11);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(ts != null ? DateFormat('HH:mm').format(ts) : '—',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: isRecurrent && status != 'completed' ? onRecurrence : null,
            onLongPress: status != 'completed' ? onRecurrence : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == 'completed'
                    ? (isCare ? AppColors.success : AppColors.warning)
                    : AppColors.surface,
                border: Border.all(
                    color: status == 'completed' ? Colors.transparent : AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(isCare ? '❤️' : '🍽️', style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            if (status == 'rejected')
                              const TextSpan(text: '⚠️ '),
                            TextSpan(text: (item['title'] ?? '').toString()),
                            if (isRecurrent) const TextSpan(text: '  🔁'),
                          ]),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: status == 'completed'
                                  ? Colors.white
                                  : AppColors.textPrimary),
                        ),
                      ),
                      if (bounty > 0 && status != 'completed')
                        PillBadge(text: '+${bounty}cc'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [action],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

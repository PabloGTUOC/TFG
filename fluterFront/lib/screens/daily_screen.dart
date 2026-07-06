import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of the core of views/DailyView.vue: timeline of scheduled activities
/// for one date, validation, and scheduling a task from the family library.
/// (Recurrence, bounties, absences and swipe gestures are follow-up work.)
class DailyScreen extends StatefulWidget {
  final String date; // yyyy-MM-dd
  const DailyScreen({super.key, required this.date});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  List<Map<String, dynamic>> _activities = [];
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
      final data = await app.api.get('/api/activities?familyId=${app.familyId}');
      final list = data is List ? data : (data['activities'] as List? ?? []);
      if (mounted) {
        setState(() {
          _activities =
              list.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _dayItems {
    final items = _activities.where((a) {
      final ts = DateTime.tryParse(a['starts_at']?.toString() ?? '');
      return ts != null &&
          ts.year == _day.year &&
          ts.month == _day.month &&
          ts.day == _day.day;
    }).toList();
    items.sort((a, b) =>
        (a['starts_at']?.toString() ?? '').compareTo(b['starts_at']?.toString() ?? ''));
    return items;
  }

  List<Map<String, dynamic>> get _templates =>
      _activities.where((a) => a['starts_at'] == null).toList();

  Future<void> _validate(dynamic id) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post('/api/activities/$id/validate');
      await _load();
    }, 'Activity validated! Coins awarded to the user.');
  }

  Future<void> _remove(dynamic id) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.delete('/api/activities/$id');
      await _load();
    }, 'Activity removed.');
  }

  void _changeDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
  }

  Future<void> _openScheduleSheet() async {
    if (_templates.isEmpty) {
      context.read<AppState>().setError('No tasks in the library yet — create one in Activities.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Add a task',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            for (final t in _templates)
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md)),
                leading: Text(t['category'] == 'care' ? '❤️' : '🍽️',
                    style: const TextStyle(fontSize: 20)),
                title: Text((t['title'] ?? '').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: PillBadge(text: '${t['coin_value'] ?? 0} cc'),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (time == null || !mounted) return;

    final app = context.read<AppState>();
    final startsAt =
        DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);
    await app.runAction(() async {
      await app.api.post('/api/activities/${picked['id']}/schedule',
          {'startsAt': startsAt.toUtc().toIso8601String()});
      await _load();
    }, 'Activity successfully scheduled!');
  }

  @override
  Widget build(BuildContext context) {
    final items = _dayItems;

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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: items.isEmpty
                    ? const Center(
                        child: Text('Nothing scheduled for this day yet.',
                            style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _TimelineCard(
                          item: items[i],
                          onValidate: () => _validate(items[i]['id']),
                          onRemove: () => _remove(items[i]['id']),
                        ),
                      ),
              ),
            ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onValidate;
  final VoidCallback onRemove;

  const _TimelineCard(
      {required this.item, required this.onValidate, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'pending';
    final isCare = item['category'] == 'care';
    final ts = DateTime.tryParse(item['starts_at']?.toString() ?? '');
    final canValidate = status == 'completed' || status == 'pending_validation';

    final (badgeText, badgeColor, badgeBg) = switch (status) {
      'approved' => ('Approved', AppColors.success, AppColors.successSoft),
      'completed' => ('Done · awaiting validation', AppColors.warning, AppColors.warningSoft),
      'pending_validation' => ('Awaiting validation', AppColors.warning, AppColors.warningSoft),
      'rejected' => ('Rejected', AppColors.danger, AppColors.dangerSoft),
      _ => ('Pending', AppColors.textSecondary, AppColors.bg),
    };

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
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: isCare ? AppColors.successSoft : AppColors.warningSoft,
                          shape: BoxShape.circle),
                      child: Text(isCare ? '❤️' : '🍽️',
                          style: const TextStyle(fontSize: 15)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text((item['title'] ?? '').toString(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    if (((item['bounty_amount'] as num?) ?? 0) > 0)
                      PillBadge(text: '+${item['bounty_amount']}cc'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PillBadge(
                        text: badgeText,
                        color: badgeColor,
                        background: badgeBg,
                        fontSize: 11),
                    const Spacer(),
                    if (canValidate)
                      VButton(
                          type: VButtonType.outline,
                          onPressed: onValidate,
                          child: const Text('Validate',
                              style: TextStyle(fontSize: 13))),
                    if (status == 'pending') ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onRemove,
                        tooltip: 'Remove',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: AppColors.danger),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

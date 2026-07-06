import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// Port of views/ActivitiesView.vue: family task library with category
/// filters and the "New Activity" form (title, category, duration, coin slider).
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<Map<String, dynamic>> _activities = [];
  bool _loading = true;
  int _filter = 0; // 0 all, 1 care, 2 household

  final _title = TextEditingController();
  String _category = 'care';
  double _duration = 30;
  double _coins = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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

  int get _baseScore => (_duration / 15).ceil() * 5;

  Future<void> _create() async {
    final app = context.read<AppState>();
    if (_title.text.trim().isEmpty) {
      app.setError('Give the activity a name first.');
      return;
    }
    final ok = await app.runAction(() async {
      await app.api.post('/api/activities', {
        'familyId': app.familyId,
        'title': _title.text.trim(),
        'category': _category,
        'durationMinutes': _duration.round(),
        'coinValue': _coins.round(),
      });
      await _load();
    }, 'Activity created!');
    if (ok) _title.clear();
  }

  Future<void> _delete(dynamic id) async {
    final app = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Delete activity?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This removes the task template from your family library.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.runAction(() async {
      await app.api.delete('/api/activities/$id');
      await _load();
    }, 'Activity deleted.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final templates = _activities.where((a) => a['starts_at'] == null).toList();
    final filtered = templates.where((a) {
      if (_filter == 1) return a['category'] == 'care';
      if (_filter == 2) return a['category'] == 'household';
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        const PageHeading(
            title: 'Activities',
            subtitle: 'Your family\'s task library — schedule these from the Daily view.'),
        SegmentedTabs(
          tabs: const ['All', 'Care', 'Household'],
          selected: _filter,
          onChanged: (i) => setState(() => _filter = i),
        ),
        const SizedBox(height: 20),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No activities yet — create the first one below.',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          for (final a in filtered)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                    decoration: BoxDecoration(
                        color: a['category'] == 'care'
                            ? AppColors.successSoft
                            : AppColors.warningSoft,
                        shape: BoxShape.circle),
                    child: Text(a['category'] == 'care' ? '❤️' : '🍽️',
                        style: const TextStyle(fontSize: 17)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((a['title'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(
                            '${a['duration_minutes'] ?? a['durationMinutes'] ?? '—'} min · ${(a['category'] ?? '').toString()}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  PillBadge(text: '${a['coin_value'] ?? a['coinValue'] ?? 0} cc'),
                  IconButton(
                    onPressed: () => _delete(a['id']),
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.danger),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 24),
        VCard(
          title: 'New Activity',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VInput(
                  controller: _title,
                  label: 'Title',
                  placeholder: 'e.g. Prepare dinner'),
              const SizedBox(height: 16),
              const Text('Category',
                  style: TextStyle(
                      fontSize: 13.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (value, label) in [('care', '❤️ Care'), ('household', '🍽️ Household')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _category == value,
                        selectedColor: AppColors.primarySoft,
                        labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _category == value
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            side: BorderSide(
                                color: _category == value
                                    ? AppColors.primary
                                    : AppColors.border)),
                        onSelected: (_) => setState(() => _category = value),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Duration: ${_duration.round()} min',
                  style: const TextStyle(
                      fontSize: 13.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              Slider(
                value: _duration,
                min: 15,
                max: 180,
                divisions: 11,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _duration = v),
              ),
              const SizedBox(height: 8),
              Text('Coin value: ${_coins.round()} cc',
                  style: const TextStyle(
                      fontSize: 13.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              Slider(
                value: _coins,
                min: 1,
                max: 100,
                divisions: 99,
                activeColor: AppColors.warning,
                onChanged: (v) => setState(() => _coins = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Min: 1',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  Text('Suggested: $_baseScore',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const Text('Max: 100',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 20),
              VButton(onPressed: _create, block: true, child: const Text('Create Activity')),
            ],
          ),
        ),
      ],
    );
  }
}

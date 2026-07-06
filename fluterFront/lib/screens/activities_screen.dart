import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/json.dart';
import '../widgets/ui.dart';

/// Port of views/ActivitiesView.vue: Catalogue / New Activity / Budget tabs.
/// Coin suggestions come from the family budget (`baseRatePerHour`), the
/// slider is bounded to 0.5×–1.5× of the suggestion, and pending templates
/// carry an Approve action.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  List<Map<String, dynamic>> _activities = [];
  Map<String, dynamic>? _budget;
  bool _loading = true;
  int _tab = 0; // 0 catalogue, 1 new, 2 budget
  int _filter = 0; // 0 all, 1 care, 2 household

  final _title = TextEditingController();
  String _category = 'care';
  int _durationMinutes = 60;
  bool _isRecurrent = false;
  double _coins = 0;

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
      final data =
          await app.api.get('/api/activities?familyId=${app.familyId}');
      final list = data is List ? data : (data['activities'] as List? ?? []);
      Map<String, dynamic>? budget;
      try {
        final b = await app.api.get('/api/families/${app.familyId}/budget');
        budget = Map<String, dynamic>.from(b as Map);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _activities =
              list.cast<Map>().map((m) => m.cast<String, dynamic>()).toList();
          _budget = budget;
          _coins = _baseScore.toDouble().clamp(1, double.infinity);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Budget economics (port of baseScore / minCoins / maxCoins) ──

  int get _baseScore {
    final rate = toNum(_budget?['baseRatePerHour']);
    return (rate * _durationMinutes / 60).round();
  }

  int get _minCoins => math.max(1, (_baseScore * 0.5).floor());
  int get _maxCoins => math.max(1, (_baseScore * 1.5).ceil());

  void _onDurationChanged(int minutes) {
    setState(() {
      _durationMinutes = minutes;
      if (_baseScore > 0) _coins = _baseScore.toDouble();
    });
  }

  static String _durationLabel(int mins) {
    final h = mins ~/ 60, m = mins % 60;
    if (h == 0) return '$m mins';
    if (m == 0) return h == 1 ? '1 hour' : '$h hours';
    return '${h}h ${m}m';
  }

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
        'durationMinutes': _durationMinutes,
        'coinValue': _coins.round() > 0 ? _coins.round() : _baseScore,
        'isRecurrent': _isRecurrent,
      });
      await _load();
    }, 'Activity template created — pending approval.');
    if (ok) {
      _title.clear();
      setState(() => _tab = 0);
    }
  }

  Future<void> _approve(dynamic id) async {
    final app = context.read<AppState>();
    await app.runAction(() async {
      await app.api.post('/api/activities/$id/approve');
      await _load();
    }, 'Activity approved! It can now be scheduled from the Daily view.');
  }

  Future<void> _delete(dynamic id) async {
    final app = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Delete activity?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'This removes the task template from your family library.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.runAction(() async {
      await app.api.delete('/api/activities/$id');
      await _load();
    }, 'Activity template deleted.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          const PageHeading(
              title: 'Activity Library',
              subtitle:
                  'Your family\'s task templates, coin economics and monthly budget.'),
          SegmentedTabs(
            tabs: const ['Catalogue', 'New Activity', 'Budget'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 20),
          if (_tab == 0) ..._buildCatalogue(),
          if (_tab == 1) _buildNewActivity(),
          if (_tab == 2) _buildBudget(),
        ],
      ),
    );
  }

  // ── Catalogue tab ────────────────────────────────────────────────

  List<Widget> _buildCatalogue() {
    final templates =
        _activities.where((a) => a['is_template'] == true).toList()
          ..sort((a, b) => (a['title'] ?? '')
              .toString()
              .compareTo((b['title'] ?? '').toString()));
    final filtered = templates.where((a) {
      if (_filter == 1) return a['category'] == 'care';
      if (_filter == 2) return a['category'] == 'household';
      return true;
    }).toList();

    return [
      Row(
        children: [
          for (final (i, label) in ['All', 'Care', 'Household'].indexed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == i,
                selectedColor: AppColors.primarySoft,
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _filter == i
                        ? AppColors.primary
                        : AppColors.textSecondary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    side: BorderSide(
                        color: _filter == i
                            ? AppColors.primary
                            : AppColors.border)),
                onSelected: (_) => setState(() => _filter = i),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('No activities found.',
              textAlign: TextAlign.center,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                                '${a['title'] ?? ''}${a['is_recurrent'] == true ? ' 🔁' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                          ),
                          if (a['status'] == 'approved') ...[
                            const SizedBox(width: 6),
                            const PillBadge(
                                text: 'approved',
                                fontSize: 10,
                                color: Colors.white,
                                background: AppColors.success),
                          ],
                        ],
                      ),
                      Text(
                          '${(a['category'] ?? '').toString()} · ${_durationLabel(toNum(a['duration_minutes'] ?? a['durationMinutes']).toInt())} · 🪙 ${a['coin_value'] ?? a['coinValue'] ?? 0}cc',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (a['status'] == 'pending')
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: VButton(
                        type: VButtonType.outline,
                        onPressed: () => _approve(a['id']),
                        child: const Text('Approve')),
                  ),
                IconButton(
                  onPressed: () => _delete(a['id']),
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.danger),
                ),
              ],
            ),
          ),
      const SizedBox(height: 12),
      VButton(
          type: VButtonType.secondary,
          block: true,
          onPressed: () => setState(() => _tab = 1),
          child: const Text('+ New Activity')),
    ];
  }

  // ── New Activity tab ─────────────────────────────────────────────

  Widget _buildNewActivity() {
    return VCard(
      title: 'New Activity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
              'Define a reusable activity template. Once approved, it can be '
              'scheduled from the Daily view any number of times.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          VInput(
              controller: _title,
              label: 'Title',
              placeholder: 'Park Visit, Bedtime routine…'),
          const SizedBox(height: 16),
          const Text('Category',
              style: TextStyle(
                  fontSize: 13.6,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (value, label) in [
                ('care', '❤️ Care / Nurture'),
                ('household', '🍽️ Household')
              ])
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
          const Text('Duration',
              style: TextStyle(
                  fontSize: 13.6,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _durationMinutes,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (var i = 1; i <= 24; i++)
                DropdownMenuItem(
                    value: i * 30, child: Text(_durationLabel(i * 30))),
            ],
            onChanged: (v) {
              if (v != null) _onDurationChanged(v);
            },
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => setState(() => _isRecurrent = !_isRecurrent),
            child: Row(
              children: [
                Checkbox(
                    value: _isRecurrent,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _isRecurrent = v ?? false)),
                const Text('🔁 This is a recurring activity',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Divider(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Coin Value Reward (cc)',
                  style: TextStyle(
                      fontSize: 13.6, color: AppColors.textSecondary)),
              Text('${_coins.round()} cc',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
          Slider(
            value: _coins.clamp(_minCoins.toDouble(), _maxCoins.toDouble()),
            min: _minCoins.toDouble(),
            max: _maxCoins.toDouble(),
            divisions: math.max(1, _maxCoins - _minCoins),
            activeColor: AppColors.warning,
            onChanged: (v) => setState(() => _coins = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min: $_minCoins',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text('Suggested: $_baseScore',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              Text('Max: $_maxCoins',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),
          VButton(
              onPressed: _create,
              block: true,
              child: const Text('Create activity template')),
        ],
      ),
    );
  }

  // ── Budget tab ───────────────────────────────────────────────────

  Widget _buildBudget() {
    final b = _budget;
    if (b == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Text('Budget information is unavailable.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final monthly = toNum(b['monthlyBudget']);
    final remaining = toNum(b['remainingBudget']);
    final used = toNum(b['usedThisMonth']);
    final rate = toNum(b['baseRatePerHour']);
    final fraction =
        monthly > 0 ? (remaining / monthly).clamp(0.0, 1.0) : 0.0;

    return VCard(
      title: 'Family Budget Health',
      child: Column(
        children: [
          const Text('REMAINING THIS MONTH',
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            height: 130,
            child: CustomPaint(
              painter: _GaugePainter(fraction: fraction.toDouble()),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '$remaining'),
                    const TextSpan(
                        text: ' cc',
                        style: TextStyle(
                            fontSize: 18, color: AppColors.primary)),
                  ]),
                  style: const TextStyle(
                      fontSize: 40, fontWeight: FontWeight.w800, height: 1),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bg,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (final (label, value, color) in [
                  ('Total Monthly Pool', '$monthly cc', AppColors.textPrimary),
                  ('Scheduled/Used', '$used cc', AppColors.textPrimary),
                  ('Estimated Rate', '~$rate cc / hr', AppColors.warning),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                        Text(value,
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: color)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Semicircular budget gauge (port of the SVG arc in ActivitiesView.vue).
class _GaugePainter extends CustomPainter {
  final double fraction;

  _GaugePainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = math.min(size.width / 2 - 14, size.height - 24);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = AppColors.border;
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    if (fraction > 0) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primary;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.fraction != fraction;
}

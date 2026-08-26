import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/json.dart';
import 'ui.dart';

/// The self-activity types the API accepts, with the glyph the timeline uses.
const kPersonalTimeTypes = ['sport', 'social', 'rest', 'appointment', 'other'];

String personalTimeTypeLabel(AppLocalizations l, String type) => switch (type) {
      'sport' => l.ptTypeSport,
      'social' => l.ptTypeSocial,
      'rest' => l.ptTypeRest,
      'appointment' => l.ptTypeAppointment,
      _ => l.ptTypeOther,
    };

String personalTimeTypeGlyph(String type) => switch (type) {
      'sport' => '🏃',
      'social' => '👥',
      'rest' => '😴',
      'appointment' => '🩺',
      _ => '✨',
    };

const _durations = [30, 60, 90, 120, 180, 240, 480, 720];

String _durationLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h$m';
}

/// "Book personal time" sheet, opened by double-tapping the hour grid.
///
/// Personal time always carries a coverage offer to another caretaker and is
/// only real once they accept, so this asks for the window *and* what the offer
/// is worth — the baseline comes from the family budget, and anything on top
/// comes out of the requester's own wallet. Returns true when a request was
/// created.
Future<bool> showPersonalTimeSheet(BuildContext context,
    {required DateTime start}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _PersonalTimeSheet(start: start),
    ),
  );
  return created == true;
}

class _PersonalTimeSheet extends StatefulWidget {
  final DateTime start;
  const _PersonalTimeSheet({required this.start});

  @override
  State<_PersonalTimeSheet> createState() => _PersonalTimeSheetState();
}

class _PersonalTimeSheetState extends State<_PersonalTimeSheet> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  late DateTime _start = widget.start;
  String _type = 'sport';
  int _minutes = 60;
  bool _coverageNeeded = true;
  int _sweetener = 0;

  bool _quoting = true;
  int _baseline = 0;
  int _balance = 0;
  String? _coverName;
  List<String> _conflicts = const [];
  bool _submitting = false;

  DateTime get _end => _start.add(Duration(minutes: _minutes));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _quote());
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Prices the window server-side, so the sheet never invents a number the
  /// API would disagree with.
  Future<void> _quote() async {
    if (!mounted) return;
    setState(() => _quoting = true);
    final app = context.read<AppState>();
    try {
      final q = await app.api.post('/api/personal-time/quote', {
        'familyId': app.familyId,
        'startsAt': _start.toUtc().toIso8601String(),
        'endsAt': _end.toUtc().toIso8601String(),
        'coverageNeeded': _coverageNeeded,
      });
      if (!mounted) return;
      setState(() {
        _baseline = toNum(q['baselineCoins']).toInt();
        _balance = toNum(q['yourBalance']).toInt();
        _conflicts = ((q['theirConflicts'] as List?) ?? [])
            .map((e) => e.toString())
            .toList();
        final candidates = (q['candidates'] as List?) ?? [];
        final target = q['requestedOf'];
        _coverName = target == null
            ? null
            : candidates
                .cast<Map>()
                .firstWhere((c) => c['user_id'].toString() == target.toString(),
                    orElse: () => {})['name']
                ?.toString();
        if (_sweetener > _balance) _sweetener = _balance;
        _quoting = false;
      });
    } catch (_) {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_start));
    if (t == null || !mounted) return;
    setState(() => _start =
        DateTime(_start.year, _start.month, _start.day, t.hour, t.minute));
    await _quote();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final app = context.read<AppState>();
    if (_title.text.trim().isEmpty) {
      app.setError(l.errNameFirst);
      return;
    }
    setState(() => _submitting = true);
    final ok = await app.runAction(() async {
      await app.api.post('/api/personal-time', {
        'familyId': app.familyId,
        'title': _title.text.trim(),
        'type': _type,
        'description': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'startsAt': _start.toUtc().toIso8601String(),
        'endsAt': _end.toUtc().toIso8601String(),
        'coverageNeeded': _coverageNeeded,
        'sweetenerCoins': _coverageNeeded ? _sweetener : 0,
      });
    }, _coverageNeeded ? l.toastPersonalTimeAsked : l.toastPersonalTimeBooked);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = l.localeName;
    final total = _baseline + _sweetener;
    final who = _coverName ?? l.personalTimeAnyone;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.personalTimeSheetTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            VInput(
                controller: _title,
                label: l.fieldTitle,
                placeholder: l.personalTimeNameHint),
            const SizedBox(height: 14),
            _Label(l.personalTimeTypeLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kPersonalTimeTypes)
                  ChoiceChip(
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                    label: Text(
                        '${personalTimeTypeGlyph(t)} ${personalTimeTypeLabel(l, t)}'),
                    labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _type == t
                            ? AppColors.primary
                            : AppColors.textSecondary),
                    selectedColor: AppColors.primarySoft,
                    backgroundColor: AppColors.bg,
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStart,
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(
                        '${l.personalTimeStartLabel}: ${DateFormat('HH:mm').format(_start)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _minutes,
                    decoration: InputDecoration(
                      labelText: l.personalTimeDurationLabel,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      for (final m in _durations)
                        DropdownMenuItem(
                            value: m, child: Text(_durationLabel(m))),
                    ],
                    onChanged: (m) {
                      if (m == null) return;
                      setState(() => _minutes = m);
                      _quote();
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '${DateFormat('EEE d MMM', loc).format(_start)} · '
                  '${DateFormat('HH:mm').format(_start)}–${DateFormat('HH:mm').format(_end)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            VInput(
                controller: _note,
                label: l.personalTimeNoteLabel,
                placeholder: l.personalTimeNoteHint),
            const SizedBox(height: 6),
            SwitchListTile.adaptive(
              value: _coverageNeeded,
              onChanged: (v) {
                setState(() {
                  _coverageNeeded = v;
                  if (!v) _sweetener = 0;
                });
                _quote();
              },
              contentPadding: EdgeInsets.zero,
              title: Text(l.personalTimeCoverageLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: _coverageNeeded
                  ? null
                  : Text(l.personalTimeCoverageOff,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
            ),
            if (_coverageNeeded) ...[
              const SizedBox(height: 6),
              _Label(l.personalTimeSweetenerLabel),
              Row(
                children: [
                  _StepButton(
                      icon: Icons.remove_rounded,
                      onTap: _sweetener > 0
                          ? () => setState(() => _sweetener--)
                          : null),
                  Expanded(
                    child: Center(
                      child: Text('$_sweetener cc',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  _StepButton(
                      icon: Icons.add_rounded,
                      onTap: _sweetener < _balance
                          ? () => setState(() => _sweetener++)
                          : null),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quoting ? '…' : l.personalTimeQuote(who, total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary),
                    ),
                    if (!_quoting && _sweetener > 0)
                      Text(l.personalTimeQuoteExtra(_baseline, _sweetener),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.primary)),
                    if (!_quoting)
                      Text(l.personalTimeBalanceAfter(_balance - _sweetener),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (_conflicts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.personalTimeTheirConflict(_conflicts.first),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.warning)),
                ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: VButton(
                    type: VButtonType.outline,
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: VButton(
                    disabled: _submitting,
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                        _coverageNeeded ? l.personalTimeAsk : l.scheduleAction),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary)),
      );
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.bg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md)),
        ),
      );
}

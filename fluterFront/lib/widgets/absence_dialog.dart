import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Shared "Log time off" dialog (DailyView.vue / DashboardView.vue absence
/// modal). Returns true when an absence was created.
Future<bool> showLogAbsenceDialog(BuildContext context,
    {required DateTime day}) async {
  final title = TextEditingController();
  var start = DateTime(day.year, day.month, day.day, 9);
  var end = DateTime(day.year, day.month, day.day, 17);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Log time off',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VInput(
                controller: title,
                label: 'Title',
                placeholder: 'e.g. Business trip'),
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
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d == null || !ctx.mounted) return;
                    final t = await showTimePicker(
                        context: ctx, initialTime: TimeOfDay.fromDateTime(get()));
                    if (t == null) return;
                    setLocal(() =>
                        set(DateTime(d.year, d.month, d.day, t.hour, t.minute)));
                  },
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label:
                      Text('$label: ${DateFormat('d MMM HH:mm').format(get())}'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log')),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final app = context.read<AppState>();
  if (title.text.trim().isEmpty) {
    app.setError('Please fill in all fields.');
    return false;
  }
  return app.runAction(() async {
    await app.api.post('/api/absences', {
      'familyId': app.familyId,
      'title': title.text.trim(),
      'startTime': start.toUtc().toIso8601String(),
      'endTime': end.toUtc().toIso8601String(),
    });
  }, 'Time off logged successfully!');
}

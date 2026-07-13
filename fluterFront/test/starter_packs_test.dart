import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/data/starter_packs.dart';
import 'package:carecoins_flutter/l10n/app_localizations.dart';

/// Starter packs (docs/family-setup-questionnaire-plan.md): the payload
/// sent to POST /api/families must carry titles in the user's language and
/// valid task shapes, and the implicit area selection must mirror the
/// legacy backend rules.
void main() {
  test('areas derive from dependent types like the legacy backend rules', () {
    final base = areasForDependents([]);
    expect(
        base,
        {
          StarterArea.meals,
          StarterArea.cleaning,
          StarterArea.errands,
          StarterArea.elderCare,
        });

    final withChild = areasForDependents(['child']);
    expect(withChild.contains(StarterArea.kidsRoutines), isTrue);
    expect(withChild.contains(StarterArea.nightCare), isTrue);
    expect(withChild.contains(StarterArea.pets), isFalse);

    final withPet = areasForDependents(['Pet']); // case-insensitive
    expect(withPet.contains(StarterArea.pets), isTrue);
    expect(withPet.contains(StarterArea.kidsRoutines), isFalse);
  });

  test('payload carries localized titles and valid task shapes', () {
    final es = lookupAppLocalizations(const Locale('es'));
    final payload = buildStarterTasksPayload(
        es, areasForDependents(['child', 'pet']));

    // Every task has the shape the backend contract expects.
    for (final t in payload) {
      expect(t['title'], isNotEmpty);
      expect(['care', 'household'], contains(t['category']));
      expect(t['durationMinutes'], greaterThanOrEqualTo(15));
      expect(t['isRecurrent'], isA<bool>());
    }

    // Titles are in Spanish, not English.
    final titles = payload.map((t) => t['title'] as String).toList();
    expect(titles, contains('Preparar el desayuno'));
    expect(titles, contains('Hora del baño'));
    expect(titles, isNot(contains('Breakfast prep')));

    // Full selection: all 8 areas → every pack task exactly once.
    final all = buildStarterTasksPayload(es, StarterArea.values.toSet());
    expect(all.length,
        starterPacks.values.fold<int>(0, (n, pack) => n + pack.length));
    expect(all.map((t) => t['title']).toSet().length, all.length,
        reason: 'no duplicate titles across packs');
  });

  test('titles differ across all four languages (no silent fallback)', () {
    final seen = <String>{};
    for (final locale in AppLocalizations.supportedLocales) {
      final l = lookupAppLocalizations(locale);
      seen.add(l.taskBedtimeRoutine);
    }
    expect(seen.length, AppLocalizations.supportedLocales.length);
  });
}

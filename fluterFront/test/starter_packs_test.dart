import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/data/starter_packs.dart';
import 'package:carecoins_flutter/l10n/app_localizations.dart';

/// Starter catalogue (docs/family-setup-questionnaire-plan.md Stage A):
/// area derivation from the wizard's dependents, and a payload the backend's
/// validateStarterTasks will accept — in the user's language.
Future<AppLocalizations> _localizations(WidgetTester tester, Locale locale) async {
  late AppLocalizations l;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) {
      l = AppLocalizations.of(context);
      return const SizedBox.shrink();
    }),
  ));
  await tester.pumpAndSettle();
  return l;
}

void main() {
  group('areasForDependents', () {
    test('a family with no dependents still gets the universal areas', () {
      expect(areasForDependents([]), kUniversalAreas);
    });

    test('a child adds routines, homework and night care', () {
      final areas = areasForDependents(['child']);
      expect(
          areas,
          containsAll([
            StarterArea.kidsRoutines,
            StarterArea.homework,
            StarterArea.nightCare,
          ]));
      expect(areas, isNot(contains(StarterArea.pets)));
      expect(areas, isNot(contains(StarterArea.elderCare)));
    });

    test('pets and elderly add only their own area', () {
      expect(areasForDependents(['pet']), contains(StarterArea.pets));
      expect(areasForDependents(['elderly']), contains(StarterArea.elderCare));
      // The old backend gave every family "Doctor accompany"; now it is
      // only seeded when someone actually cares for an elderly dependent.
      expect(areasForDependents(['pet']), isNot(contains(StarterArea.elderCare)));
    });

    test('type matching is case-insensitive and de-duplicated', () {
      final two = areasForDependents(['Child', 'child']);
      expect(two, areasForDependents(['child']));
    });
  });

  group('starterTasksPayload', () {
    testWidgets('emits backend-valid rows for every seeded task',
        (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      final payload = starterTasksPayload(l, areasForDependents(['child', 'pet']));

      expect(payload, isNotEmpty);
      // Mirrors backend validateStarterTasks: <= 40 items, non-empty title,
      // known category, duration >= 15 (the activities table CHECK).
      expect(payload.length, lessThanOrEqualTo(40));
      for (final task in payload) {
        expect((task['title'] as String).trim(), isNotEmpty);
        expect(task['category'], anyOf('care', 'household'));
        expect(task['durationMinutes'], isA<int>());
        expect(task['durationMinutes'] as int, greaterThanOrEqualTo(15));
        expect(task['isRecurrent'], isA<bool>());
      }
    });

    testWidgets('titles are localized, not English fallbacks', (tester) async {
      final en = await _localizations(tester, const Locale('en'));
      final es = await _localizations(tester, const Locale('es'));
      final areas = areasForDependents(['child']);

      final enTitles = starterTasksPayload(en, areas).map((t) => t['title']);
      final esTitles = starterTasksPayload(es, areas).map((t) => t['title']);

      expect(esTitles.length, enTitles.length);
      // This is the bug Stage A fixes: a Spanish family used to be seeded
      // with English rows from the backend's defaultActivities.js.
      expect(esTitles, isNot(equals(enTitles)));
      expect(esTitles, contains('Preparar el desayuno'));
    });

    testWidgets('no dependents seeds household tasks only', (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      final payload = starterTasksPayload(l, areasForDependents([]));
      expect(payload.every((t) => t['category'] == 'household'), isTrue);
    });

    testWidgets('an empty area set produces an empty payload', (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      expect(starterTasksPayload(l, {}), isEmpty);
    });
  });

  // ── Stage B: the questionnaire's preview list and per-task exclusion ──

  group('starterEntries', () {
    test('lists every task of the selected areas in declaration order', () {
      final areas = {StarterArea.meals, StarterArea.pets};
      final entries = starterEntries(areas);

      expect(entries.length,
          starterPacks[StarterArea.meals]!.length +
              starterPacks[StarterArea.pets]!.length);
      // Areas follow enum order, so meals (declared first) comes before pets.
      expect(entries.first.area, StarterArea.meals);
      expect(entries.last.area, StarterArea.pets);
      // Indexes restart within each area.
      expect(entries.first.index, 0);
    });

    test('keys are unique and stable across rebuilds', () {
      final keys = starterEntries(StarterArea.values.toSet())
          .map((e) => starterTaskKey(e.area, e.index))
          .toList();
      expect(keys.toSet().length, keys.length);
      // Stability matters: the checkbox state is keyed by this, and the
      // localized title changes with the app language.
      expect(starterTaskKey(StarterArea.meals, 0),
          starterTaskKey(StarterArea.meals, 0));
      expect(starterTaskKey(StarterArea.meals, 0),
          isNot(starterTaskKey(StarterArea.cleaning, 0)));
    });
  });

  group('starterTasksPayload with exclusions', () {
    testWidgets('unchecked tasks are dropped, the rest survive',
        (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      final areas = {StarterArea.meals};
      final all = starterTasksPayload(l, areas);
      final excludedKey = starterTaskKey(StarterArea.meals, 0);
      final dropped = starterPacks[StarterArea.meals]![0].title(l);

      final kept = starterTasksPayload(l, areas, excluded: {excludedKey});

      expect(kept.length, all.length - 1);
      expect(kept.map((t) => t['title']), isNot(contains(dropped)));
    });

    testWidgets('excluding everything yields an empty payload',
        (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      final areas = {StarterArea.cleaning};
      final allKeys = starterEntries(areas)
          .map((e) => starterTaskKey(e.area, e.index))
          .toSet();
      expect(starterTasksPayload(l, areas, excluded: allKeys), isEmpty);
    });

    testWidgets('exclusions for unselected areas are harmless',
        (tester) async {
      final l = await _localizations(tester, const Locale('en'));
      final areas = {StarterArea.meals};
      final stale = starterTaskKey(StarterArea.pets, 0);
      expect(starterTasksPayload(l, areas, excluded: {stale}).length,
          starterTasksPayload(l, areas).length);
    });
  });

  group('starterAreaLabel', () {
    testWidgets('every area has a distinct, localized label', (tester) async {
      for (final locale in const [Locale('en'), Locale('es')]) {
        final l = await _localizations(tester, locale);
        final labels =
            StarterArea.values.map((a) => starterAreaLabel(l, a)).toList();
        expect(labels.every((s) => s.trim().isNotEmpty), isTrue);
        expect(labels.toSet().length, StarterArea.values.length,
            reason: 'labels must be distinct in $locale');
      }
    });
  });
}

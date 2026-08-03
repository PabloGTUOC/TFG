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
}

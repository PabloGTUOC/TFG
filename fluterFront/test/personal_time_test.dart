import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:carecoins_flutter/l10n/app_localizations.dart';
import 'package:carecoins_flutter/state/app_state.dart';
import 'package:carecoins_flutter/widgets/personal_time_dialog.dart';

void main() {
  group('personal-time types', () {
    test('every type the API accepts has a label and a glyph', () {
      // Mirrors SELF_TYPES in backend/src/services/personalTimeService.js —
      // a type the app cannot name is a type the picker cannot offer.
      expect(kPersonalTimeTypes,
          ['sport', 'social', 'rest', 'appointment', 'other']);
      final glyphs = kPersonalTimeTypes.map(personalTimeTypeGlyph).toSet();
      expect(glyphs.length, kPersonalTimeTypes.length,
          reason: 'each type needs a glyph of its own');
    });

    test('an unknown type falls back rather than crashing the timeline', () {
      expect(personalTimeTypeGlyph('yoga'), personalTimeTypeGlyph('other'));
    });
  });

  testWidgets('the sheet asks for a name, a type, a window and an offer',
      (tester) async {
    final app = AppState();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showPersonalTimeSheet(ctx,
                  start: DateTime(2026, 9, 4, 18)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Book personal time'), findsOneWidget);
    // Every self type is offered, so nothing forces "other" by default.
    expect(find.textContaining('Sport'), findsWidgets);
    expect(find.textContaining('Appointment'), findsWidgets);
    // The window is seeded from the slot that was double-tapped.
    expect(find.textContaining('18:00'), findsWidgets);
    // Coverage is requested by default — asking is the norm, not the exception.
    expect(find.text('Someone needs to cover'), findsOneWidget);
    expect(find.text('Add from your own coins'), findsOneWidget);
    expect(find.text('Ask'), findsOneWidget);
  });
}

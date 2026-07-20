import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carecoins_flutter/l10n/app_localizations.dart';
import 'package:carecoins_flutter/state/app_state.dart';

/// Locks in the persisted-language behaviour (review fixes 2, 8, 9):
/// the stored code is validated on read, the seeded locale reaches the first
/// frame through the Selector, and switching language rebuilds MaterialApp.
void main() {
  group('AppState.loadPersistedLocale', () {
    test('returns the stored locale when it is a supported code', () async {
      SharedPreferences.setMockInitialValues({'app_locale': 'es'});
      expect(await AppState.loadPersistedLocale(), const Locale('es'));
    });

    test('rejects an unsupported stored code (falls back to device)', () async {
      // A stale/corrupt value must not reach the picker or ship an
      // untranslated UI — it resolves to null (follow the device locale).
      SharedPreferences.setMockInitialValues({'app_locale': 'xx'});
      expect(await AppState.loadPersistedLocale(), isNull);
    });

    test('returns null when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await AppState.loadPersistedLocale(), isNull);
    });
  });

  testWidgets('seeded locale renders on the first frame and survives a switch',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState()..seedLocale(const Locale('es'));

    // Mirror main.dart: a Selector<AppState, Locale?> feeds MaterialApp so only
    // locale changes rebuild it.
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: Selector<AppState, Locale?>(
          selector: (_, a) => a.locale,
          builder: (_, locale, __) => MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
                builder: (context) =>
                    Text(AppLocalizations.of(context).tabFamily)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Seeded Spanish is present from the first settled frame (no English flash
    // to reconcile).
    expect(find.text('Familia'), findsOneWidget);
    expect(find.text('Family'), findsNothing);

    // Switching language rebuilds MaterialApp through the Selector.
    await app.setLocale(const Locale('fr'));
    await tester.pumpAndSettle();

    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('Familia'), findsNothing);
  });
}

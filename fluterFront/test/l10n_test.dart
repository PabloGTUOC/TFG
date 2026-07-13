import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/l10n/app_localizations.dart';

/// Locale smoke test (docs/i18n-plan.md §6): every supported locale must
/// resolve through the generated delegates, and no language may silently
/// fall back to English for the starter keys.
void main() {
  testWidgets('all supported locales resolve and differ where expected',
      (tester) async {
    expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        {'en', 'es', 'fr', 'de'});

    final seenLogout = <String>{};
    for (final locale in AppLocalizations.supportedLocales) {
      late AppLocalizations l;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (context) {
            l = AppLocalizations.of(context);
            return Text(l.tabFamily);
          }),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.tabFamily), findsOneWidget,
          reason: 'tabFamily should render for $locale');
      seenLogout.add(l.menuLogout);
    }

    // Four locales must yield four distinct translations, which fails if a
    // language file ever loses a key and falls back to the template.
    expect(seenLogout.length, AppLocalizations.supportedLocales.length,
        reason: 'menuLogout should be translated in every language');
  });
}

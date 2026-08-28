import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carecoins_flutter/l10n/app_localizations.dart';
import 'package:carecoins_flutter/utils/legal_links.dart';

/// Both stores require a reachable privacy policy, and Apple requires the
/// privacy policy *and* the terms of use to be reachable from inside the app
/// when it sells subscriptions (Guideline 3.1.2). These guard the two ways that
/// silently breaks: a malformed URL, or a language where the links are missing.
void main() {
  group('legal document URLs', () {
    test('are absolute https URLs', () {
      for (final url in [kPrivacyPolicyUrl, kTermsOfUseUrl]) {
        final uri = Uri.tryParse(url);
        expect(uri, isNotNull, reason: '$url must parse');
        expect(uri!.isAbsolute, isTrue, reason: '$url must be absolute');
        expect(uri.scheme, 'https',
            reason: 'app stores reject plaintext links; $url must be https');
        expect(uri.host, isNotEmpty);
      }
    });

    test('point at two different documents', () {
      expect(kPrivacyPolicyUrl, isNot(kTermsOfUseUrl));
    });

    test('match the paths nginx.conf serves', () {
      // fluterFront/nginx.conf maps these exact extensionless paths to the
      // pages in web/. A change here without a change there is a 404.
      expect(Uri.parse(kPrivacyPolicyUrl).path, '/privacy');
      expect(Uri.parse(kTermsOfUseUrl).path, '/terms');
    });
  });

  testWidgets('both links are labelled in every shipped language',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      late AppLocalizations l;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l = AppLocalizations.of(context);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();

      for (final label in [l.legalTitle, l.legalPrivacyPolicy, l.legalTerms]) {
        expect(label.trim(), isNotEmpty,
            reason: 'empty legal label in ${locale.languageCode}');
      }
      expect(l.legalPrivacyPolicy, isNot(l.legalTerms),
          reason: 'the two links must be distinguishable in '
              '${locale.languageCode}');
      // The failure message has to name the document the user should open.
      expect(l.legalOpenFailed(kPrivacyPolicyUrl), contains(kPrivacyPolicyUrl));
    }
  });
}

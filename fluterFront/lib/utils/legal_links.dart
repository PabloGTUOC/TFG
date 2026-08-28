import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// The hosted legal documents.
///
/// Both stores require a reachable privacy policy for the listing, and Apple
/// requires the privacy policy *and* the terms of use (EULA) to be reachable
/// from inside the app when it sells auto-renewable subscriptions
/// (App Review Guideline 3.1.2) — a paywall without them is a routine
/// rejection. The pages are served from `fluterFront/web/`, so the web build
/// and the native apps point at the same URLs.
///
/// Overridable at build time in case the documents ever move:
///   --dart-define=PRIVACY_URL=… --dart-define=TERMS_URL=…
const String kPrivacyPolicyUrl = String.fromEnvironment(
  'PRIVACY_URL',
  defaultValue: 'https://mycarecoins.app/privacy',
);

const String kTermsOfUseUrl = String.fromEnvironment(
  'TERMS_URL',
  defaultValue: 'https://mycarecoins.app/terms',
);

/// Opens [url] in the platform browser. Failure is reported through the normal
/// toast channel rather than thrown: a legal link that cannot open should tell
/// the user where to go, never crash the settings screen.
Future<void> openLegalLink(BuildContext context, String url) async {
  final l = AppLocalizations.of(context);
  final app = context.read<AppState>();
  try {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) app.setError(l.legalOpenFailed(url));
  } catch (_) {
    app.setError(l.legalOpenFailed(url));
  }
}

/// The privacy-policy and terms links, as a labelled block.
///
/// Rendered on every platform — the web build needs them as much as the store
/// builds do — and deliberately placed next to the subscription entry point so
/// they are visible at the moment of purchase.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.legalTitle,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        _LegalLink(label: l.legalPrivacyPolicy, url: kPrivacyPolicyUrl),
        _LegalLink(label: l.legalTerms, url: kTermsOfUseUrl),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String url;
  const _LegalLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: () => openLegalLink(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
            ),
            const Icon(Icons.open_in_new_rounded,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

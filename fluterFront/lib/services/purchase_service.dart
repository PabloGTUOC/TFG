import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat integration (docs/admin-family-management-plan.md Phase 4).
///
/// Division of labour, deliberately:
///  - RevenueCat handles the NATIVE side: StoreKit / Play Billing, receipt
///    validation, the paywall UI, the customer center.
///  - Our BACKEND stays the source of truth for what a family may do:
///    RevenueCat webhooks write `family_plans`, and every client reads
///    entitlements from `/api/families/:id/entitlements` — never from the
///    local store state. That is what makes one caregiver's iPhone purchase
///    light up Premium for the Android grandparent.
///
/// Identity: `appUserID` is our backend user id (set after login), so
/// webhook events carry it as `app_user_id`. Family attribution rides on a
/// `family_id` subscriber attribute set just before the paywall opens — a
/// user can belong to several families, and the purchase must name one.
///
/// Web: purchases_flutter has no web support; every method here no-ops.
class PurchaseService {
  /// Public SDK keys (safe to embed). Override per store at build time:
  ///   --dart-define=RC_IOS_KEY=appl_… --dart-define=RC_ANDROID_KEY=goog_…
  /// The default is the RevenueCat *test store* key — fine for development,
  /// never for a store release.
  static const _iosKey = String.fromEnvironment('RC_IOS_KEY',
      defaultValue: 'test_saYAgPCBMgqULqgVbklrttaqFBh');
  static const _androidKey = String.fromEnvironment('RC_ANDROID_KEY',
      defaultValue: 'test_saYAgPCBMgqULqgVbklrttaqFBh');

  /// RevenueCat entitlement identifier (dashboard: Project → Entitlements).
  static const entitlementId = 'MyCareCoins Pro';

  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  static bool _configured = false;

  static Future<void> _ensureConfigured() async {
    if (!supported || _configured) return;
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
    await Purchases.configure(
        PurchasesConfiguration(Platform.isIOS ? _iosKey : _androidKey));
    _configured = true;
  }

  /// Ties the RevenueCat identity to our backend user id. Called by AppState
  /// after /api/me resolves; safe to call repeatedly.
  static Future<void> syncIdentity(String? backendUserId) async {
    if (!supported || backendUserId == null || backendUserId.isEmpty) return;
    try {
      await _ensureConfigured();
      await Purchases.logIn(backendUserId);
    } on PlatformException catch (e) {
      debugPrint('RevenueCat logIn failed: ${e.message}');
    }
  }

  static Future<void> logOut() async {
    if (!supported || !_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      // Already-anonymous is expected after a failed logIn; not an error.
      debugPrint('RevenueCat logOut: ${e.message}');
    }
  }

  /// Device-local entitlement check — immediate UX feedback only. The
  /// family-wide truth is the backend's entitlements endpoint.
  static Future<bool> hasProLocally() async {
    if (!supported) return false;
    try {
      await _ensureConfigured();
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      debugPrint('RevenueCat getCustomerInfo failed: ${e.message}');
      return false;
    }
  }

  /// Opens the RevenueCat paywall for the current offering, attributing the
  /// purchase to [familyId] first. Returns true when a purchase or restore
  /// completed (the webhook then upgrades the family server-side).
  static Future<bool> presentPaywall({required int familyId}) async {
    if (!supported) return false;
    try {
      await _ensureConfigured();
      await Purchases.setAttributes({'family_id': '$familyId'});
      final result = await RevenueCatUI.presentPaywallIfNeeded(entitlementId,
          displayCloseButton: true);
      return result == PaywallResult.purchased ||
          result == PaywallResult.restored;
    } on PlatformException catch (e) {
      debugPrint('RevenueCat paywall failed: ${e.message}');
      return false;
    }
  }

  /// RevenueCat Customer Center: subscription management, refund requests,
  /// and cancellation flows — all against the user's own store account.
  static Future<void> presentCustomerCenter() async {
    if (!supported) return;
    try {
      await _ensureConfigured();
      await RevenueCatUI.presentCustomerCenter();
    } on PlatformException catch (e) {
      debugPrint('RevenueCat customer center failed: ${e.message}');
    }
  }

  /// Restore purchases — Apple requires this to be reachable. Returns true
  /// when the entitlement is active after the restore.
  static Future<bool> restorePurchases() async {
    if (!supported) return false;
    try {
      await _ensureConfigured();
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementId);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('RevenueCat restore failed: ${e.message}');
      }
      return false;
    }
  }
}

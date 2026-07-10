import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Onboarding instrumentation (docs/onboarding-help-plan.md Phase 4).
///
/// Fire-and-forget: measurement must never break or slow the UX, so every
/// call swallows failures. Events land in the backend's onboarding_events
/// table via POST /api/events (whitelisted names, tiny detail payloads).
abstract final class Telemetry {
  static ApiClient? _api;

  /// Wire up once from AppState so call sites don't need a BuildContext.
  static void init(ApiClient api) => _api = api;

  static void log(String event, [Map<String, dynamic>? detail]) {
    final api = _api;
    if (api == null) return;
    api.post('/api/events', {
      'event': event,
      if (detail != null) 'detail': detail,
    }).catchError((e) {
      debugPrint('telemetry: $event failed ($e)');
      return null;
    });
  }
}

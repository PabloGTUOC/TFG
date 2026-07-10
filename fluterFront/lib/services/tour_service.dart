import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guided-tour state (docs/onboarding-help-plan.md Phase 2).
///
/// Tracks which coach-mark tours the user has seen, device-locally in
/// SharedPreferences. Screens listen to this notifier: it fires when the
/// welcome dialog completes and when the tour is reset from the help sheet,
/// so an already-visible tab can start (or re-run) its tour immediately.
class TourService extends ChangeNotifier {
  TourService._();

  static final TourService I = TourService._();

  /// The welcome dialog's id; tab tours are gated until it has been decided.
  static const welcome = 'welcome';

  /// All tour ids, for suppress/reset.
  static const tabTours = [
    'dashboard',
    'activities',
    'marketplace',
    'stats',
    'profile',
    'daily',
  ];

  static String _key(String id) => 'tour.seen.$id';

  Future<bool> hasSeen(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(id)) ?? false;
  }

  /// Whether the [id] tour should run now. Tab tours wait for the welcome
  /// dialog so two overlays never compete for the first screen.
  Future<bool> shouldShow(String id) async {
    if (await hasSeen(id)) return false;
    if (id != welcome && !await hasSeen(welcome)) return false;
    return true;
  }

  Future<void> markSeen(String id, {bool notify = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(id), true);
    if (notify) notifyListeners();
  }

  /// "Explore on my own": the user opted out of the guided tour.
  Future<void> suppressAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in [welcome, ...tabTours]) {
      await prefs.setBool(_key(id), true);
    }
  }

  /// "Replay the guided tour" from the help sheet: forget the tab tours
  /// (the welcome dialog stays seen) and nudge listening screens.
  Future<void> resetTabTours() async {
    final prefs = await SharedPreferences.getInstance();
    for (final id in tabTours) {
      await prefs.remove(_key(id));
    }
    notifyListeners();
  }
}

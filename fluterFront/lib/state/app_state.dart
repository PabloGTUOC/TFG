import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/api_client.dart';
import '../services/telemetry.dart';
import '../utils/json.dart';

/// App-wide state: Firebase auth session + `/api/me` payload + toast messages.
/// Mirrors stores/auth.js + stores/family.js from the Vue frontend.
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();

  AppState() {
    Telemetry.init(api);
  }

  fb.User? user;
  bool authReady = false;
  bool firebaseAvailable = true;

  Map<String, dynamic>? profile;
  List<dynamic> families = [];
  List<dynamic> actors = [];
  List<dynamic> pendingRequests = [];
  int? loginEventId;

  String success = '';
  String error = '';
  Timer? _dismissTimer;

  Map<String, dynamic>? get family => families.isNotEmpty
      ? Map<String, dynamic>.from(families.first as Map)
      : null;

  int get familyId => toNum(family?['family_id']).toInt();
  bool get hasFamilies => families.isNotEmpty;

  bool get isCaregiver {
    final role =
        family?['role']?.toString() ?? profile?['role']?.toString() ?? '';
    return role.isEmpty || role == 'caregiver';
  }

  /// Backend user id (from /api/me), used to tell "my" tasks from others'.
  dynamic get userId => profile?['id'];

  void init() {
    if (!firebaseAvailable) {
      authReady = true;
      notifyListeners();
      return;
    }
    fb.FirebaseAuth.instance.idTokenChanges().listen((u) async {
      user = u;
      if (u != null) {
        api.token = await u.getIdToken() ?? '';
        if (!authReady) await fetchUserData();
      } else {
        api.token = '';
        loginEventId = null;
        profile = null;
        families = [];
        actors = [];
        pendingRequests = [];
      }
      authReady = true;
      notifyListeners();
    });
  }

  Future<void> fetchUserData() async {
    try {
      final data = await api.get('/api/me');
      profile = (data['user'] as Map?)?.cast<String, dynamic>();
      families = (data['families'] as List?) ?? [];
      pendingRequests = (data['pendingRequests'] as List?) ?? [];
      actors = (data['actors'] as List?) ?? [];

      if (loginEventId == null) {
        final loginData = await api.post('/api/me/login-event');
        loginEventId = toNumOrNull(loginData['eventId'])?.toInt();
      }
    } catch (e) {
      debugPrint('Backend auth sync failed: $e');
    }
    notifyListeners();
  }

  // ── Auth actions ────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    clearMessages();
    try {
      final cred = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _afterSignIn(cred.user!);
      setSuccess('Logged in successfully!');
    } catch (e) {
      setError(_authMessage(e));
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    clearMessages();
    try {
      final cred = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await _afterSignIn(cred.user!);
      setSuccess('Account created successfully!');
    } catch (e) {
      setError(_authMessage(e));
      rethrow;
    }
  }

  Future<void> loginWithGoogle() async {
    clearMessages();
    try {
      fb.UserCredential cred;
      if (kIsWeb) {
        cred = await fb.FirebaseAuth.instance
            .signInWithPopup(fb.GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return; // user cancelled
        final googleAuth = await googleUser.authentication;
        cred = await fb.FirebaseAuth.instance.signInWithCredential(
          fb.GoogleAuthProvider.credential(
            idToken: googleAuth.idToken,
            accessToken: googleAuth.accessToken,
          ),
        );
      }
      await _afterSignIn(cred.user!);
      setSuccess('Logged in with Google successfully!');
    } catch (e) {
      setError(_authMessage(e));
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    clearMessages();
    try {
      await fb.FirebaseAuth.instance
          .sendPasswordResetEmail(email: email.trim());
      setSuccess('Password reset email sent to ${email.trim()}.');
    } catch (e) {
      setError(_authMessage(e));
    }
  }

  Future<void> _afterSignIn(fb.User u) async {
    user = u;
    api.token = await u.getIdToken() ?? '';
    await fetchUserData();
  }

  Future<void> logout() async {
    clearMessages();
    try {
      if (api.token.isNotEmpty) {
        await api.post('/api/me/logout-event', {'eventId': loginEventId});
      }
    } catch (e) {
      debugPrint('Failed to safely track backend logout: $e');
    }
    api.token = '';
    loginEventId = null;
    await fb.FirebaseAuth.instance.signOut();
  }

  String _authMessage(Object e) =>
      e is fb.FirebaseAuthException ? (e.message ?? e.code) : e.toString();

  // ── Toast messages (mirrors setSuccess / setError / runAction) ──

  Future<bool> runAction(Future<void> Function() fn,
      [String? okMessage]) async {
    clearMessages();
    try {
      await fn();
      if (okMessage != null) setSuccess(okMessage);
      return true;
    } catch (e) {
      setError(e.toString());
      return false;
    }
  }

  void setSuccess(String message) {
    success = message;
    error = '';
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 3500), () {
      success = '';
      notifyListeners();
    });
    notifyListeners();
  }

  void setError(String message) {
    error = message;
    success = '';
    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(milliseconds: 5000), () {
      error = '';
      notifyListeners();
    });
    notifyListeners();
  }

  void clearMessages() {
    success = '';
    error = '';
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

/// Handles Firebase Core initialization, Anonymous Authentication, and fallback guest IDs.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _isInitialized = false;
  String? _cachedUserId;

  bool get isFirebaseAvailable => _isInitialized;
  String get currentUserId => _cachedUserId ?? 'guest_${const Uuid().v4().substring(0, 8)}';

  /// Initializes Firebase and anonymously authenticates the player.
  Future<bool> init() async {
    try {
      await Firebase.initializeApp();
      _isInitialized = true;

      // Ensure Anonymous Authentication (no email, password, or phone required)
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        final userCredential = await auth.signInAnonymously();
        user = userCredential.user;
      }
      _cachedUserId = user?.uid;
      debugPrint('Firebase initialized successfully. Anonymous UID: $_cachedUserId');
      return true;
    } catch (e) {
      debugPrint('Firebase not configured yet ($e). Running in offline/local mode.');
      _isInitialized = false;
      // Fallback guest identifier for local matches
      _cachedUserId ??= 'guest_${const Uuid().v4().substring(0, 8)}';
      return false;
    }
  }

  /// Get current anonymous user or sign in if not signed in yet.
  Future<String> ensureAnonymousUser() async {
    if (!_isInitialized) {
      return currentUserId;
    }

    try {
      final auth = FirebaseAuth.instance;
      User? user = auth.currentUser;
      if (user == null) {
        final cred = await auth.signInAnonymously();
        user = cred.user;
      }
      _cachedUserId = user?.uid ?? currentUserId;
      return _cachedUserId!;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      return currentUserId;
    }
  }
}

import 'package:flutter/foundation.dart';

/// Provides global authentication state for the app.
class AuthState extends ChangeNotifier {
  bool _loggedIn = true;
  bool get loggedIn => _loggedIn;

  /// Call this to update login status and notify listeners.
  void setLoggedIn(bool value) {
    _loggedIn = value;
    notifyListeners();
  }
} 
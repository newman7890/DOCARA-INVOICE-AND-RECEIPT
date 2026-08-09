import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  final _service = SupabaseService();

  String? _businessId;
  bool _isLoading = false;
  String? _error;

  String? get businessId => _businessId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _service.isLoggedIn && _businessId != null;
  User? get currentUser => _service.currentUser;

  AuthProvider() {
    _init();
    _service.authStateChanges.listen((data) async {
      try {
        if (data.event == AuthChangeEvent.signedIn) {
          await _loadBusinessId();
        } else if (data.event == AuthChangeEvent.passwordRecovery) {
          _isRecoveringPassword = true;
          notifyListeners();
        } else if (data.event == AuthChangeEvent.signedOut) {
          _businessId = null;
          _isRecoveringPassword = false;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_business_id');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Auth state change error (likely offline): $e');
      }
    });
  }

  bool _isRecoveringPassword = false;
  bool get isRecoveringPassword => _isRecoveringPassword;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _businessId = prefs.getString('cached_business_id');
    if (_businessId != null) notifyListeners();

    if (_service.isLoggedIn) {
      try {
        await _loadBusinessId();
      } catch (e) {
        debugPrint('Init: could not reach Supabase (offline?): $e');
        // Keep the cached _businessId so the app still works offline
      }
    }
  }

  Future<void> _loadBusinessId() async {
    try {
      final newId = await _service.getBusinessId();
      if (newId != null) {
        _businessId = newId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_business_id', _businessId!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Could not load business ID (offline?): $e');
      // Keep the cached _businessId — don't clear it
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.signIn(email, password);
      await _loadBusinessId();
      _isLoading = false;
      notifyListeners();
      return null; // No error
    } catch (e) {
      _error = _friendlyError(e.toString());
      _isLoading = false;
      notifyListeners();
      return _error;
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _service.resetPassword(email);
      return null;
    } catch (e) {
      return _friendlyError(e.toString());
    }
  }

  Future<String?> signUp(String email, String password, String businessName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.signUp(email, password);
      _businessId = await _service.createBusiness(businessName);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _error = _friendlyError(e.toString());
      _isLoading = false;
      notifyListeners();
      return _error;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    _businessId = null;
    _isRecoveringPassword = false;
    notifyListeners();
  }

  Future<String?> updatePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _service.updatePassword(newPassword);
      _isRecoveringPassword = false;
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return _friendlyError(e.toString());
    }
  }

  String _friendlyError(String raw) {
    debugPrint('Auth Error: $raw'); // Log to console for debugging
    if (raw.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (raw.contains('Email not found')) return 'No account found with this email.';
    if (raw.contains('rate limit')) return 'Too many requests. Please wait a while.';
    if (raw.contains('NetworkParent')) return 'No internet connection.';
    if (raw.contains('SocketException') || raw.contains('Failed host lookup') || raw.contains('No address associated')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (raw.contains('AuthRetryableFetchException') || raw.contains('ClientException')) {
      return 'Could not connect to the server. Please check your internet connection.';
    }
    return 'Error: ${raw.replaceAll('Exception: ', '').replaceAll('AuthException: ', '')}';
  }
}

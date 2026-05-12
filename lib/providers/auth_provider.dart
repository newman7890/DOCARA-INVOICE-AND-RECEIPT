import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      if (data.event == AuthChangeEvent.signedIn) {
        await _loadBusinessId();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _businessId = null;
        notifyListeners();
      }
    });
  }

  Future<void> _init() async {
    if (_service.isLoggedIn) {
      await _loadBusinessId();
    }
  }

  Future<void> _loadBusinessId() async {
    _businessId = await _service.getBusinessId();
    notifyListeners();
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
    notifyListeners();
  }

  String _friendlyError(String raw) {
    if (raw.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (raw.contains('rate limit exceeded') || raw.contains('over_email_send_rate_limit')) {
      return 'Supabase email limit reached. Please disable "Confirm email" in your Supabase Auth settings.';
    }
    return 'Something went wrong. Please try again.';
  }
}

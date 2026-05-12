import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';
import '../services/supabase_service.dart';

class SettingsProvider with ChangeNotifier {
  final _supabase = SupabaseService();
  ThemeMode _themeMode = ThemeMode.light;
  BusinessInfo? _businessInfo;
  String _stationName = 'Station 1';
  String? _businessId;

  ThemeMode get themeMode => _themeMode;
  BusinessInfo? get businessInfo => _businessInfo;
  String get stationName => _stationName;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;

    _stationName = prefs.getString('stationName') ?? 'Station 1';

    final bizJson = prefs.getString('businessInfo');
    if (bizJson != null) {
      _businessInfo = BusinessInfo.fromJson(bizJson);
    } else {
      _businessInfo = BusinessInfo(
        name: 'My Business',
        email: '',
        phone: '',
        address: '',
        terms: 'Payment is due within 30 days. Thank you for your business!',
      );
    }
    notifyListeners();
  }

  /// Called by ProxyProvider when businessId changes
  Future<void> updateBusinessConfig(String? businessId) async {
    if (_businessId == businessId) return;
    _businessId = businessId;
    if (_businessId != null) {
      await loadFromSupabase();
    }
  }

  Future<void> loadFromSupabase() async {
    if (_businessId == null) return;
    try {
      final cloudInfo = await _supabase.getFullBusinessInfo(_businessId!);
      if (cloudInfo != null) {
        _businessInfo = cloudInfo;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('businessInfo', cloudInfo.toJson());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading business info from cloud: $e');
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
    notifyListeners();
  }

  Future<void> updateBusinessInfo(BusinessInfo info) async {
    _businessInfo = info;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('businessInfo', info.toJson());
    notifyListeners(); // Immediate local update

    // Sync to Supabase
    if (_businessId != null) {
      try {
        String? logoUrl = info.logoPath;
        if (logoUrl != null && !logoUrl.startsWith('http') && logoUrl.isNotEmpty) {
          final uploaded = await _supabase.uploadBusinessAsset(_businessId!, logoUrl, 'logo.png');
          if (uploaded != null) logoUrl = uploaded;
        }

        String? sigUrl = info.signaturePath;
        if (sigUrl != null && !sigUrl.startsWith('http') && sigUrl.isNotEmpty) {
          final uploaded = await _supabase.uploadBusinessAsset(_businessId!, sigUrl, 'signature.png');
          if (uploaded != null) sigUrl = uploaded;
        }

        final updatedInfo = info.copyWith(logoPath: logoUrl, signaturePath: sigUrl);
        await _supabase.updateBusinessInfo(_businessId!, updatedInfo);

        // Update local again with URLs
        _businessInfo = updatedInfo;
        await prefs.setString('businessInfo', updatedInfo.toJson());
        notifyListeners();
      } catch (e) {
        debugPrint('Error syncing business info to cloud: $e');
      }
    }
  }

  Future<void> updateStationName(String name) async {
    _stationName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stationName', name);
    notifyListeners();
  }
}

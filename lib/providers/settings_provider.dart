import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  BusinessInfo? _businessInfo;
  
  ThemeMode get themeMode => _themeMode;
  BusinessInfo? get businessInfo => _businessInfo;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final isDark = prefs.getBool('isDark') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    // Load Business Info
    final bizJson = prefs.getString('businessInfo');
    if (bizJson != null) {
      _businessInfo = BusinessInfo.fromJson(bizJson);
    } else {
      // Default placeholder
      _businessInfo = BusinessInfo(
        name: 'Docara Solutions',
        email: 'contact@docara.com',
        phone: '+233 24 000 0000',
        address: 'Accra, Ghana',
        terms: 'Payment is due within 30 days. Thank you for your business!',
      );
    }
    notifyListeners();
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
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  BusinessInfo? _businessInfo;
  String _stationName = 'Station 1';

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

  Future<void> updateStationName(String name) async {
    _stationName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('stationName', name);
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _themeKey = 'theme_mode';
  static const String _pdfPasswordKey = 'pdf_password';
  static const String _pdfWatermarkKey = 'pdf_watermark';
  static const String _appLockKey = 'app_lock';
  static const String _onboardingKey = 'onboarding_done';
  static const String _dynamicColorKey = 'dynamic_color';
  static const String _ocrScriptKey = 'ocr_script';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // Theme
  ThemeMode getThemeMode() {
    final value = _prefs.getString(_themeKey);
    if (value == 'light') return ThemeMode.light;
    if (value == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value = 'system';
    if (mode == ThemeMode.light) value = 'light';
    if (mode == ThemeMode.dark) value = 'dark';
    await _prefs.setString(_themeKey, value);
  }

  // PDF Password
  String? getPdfPassword() {
    return _prefs.getString(_pdfPasswordKey);
  }

  Future<void> setPdfPassword(String? password) async {
    if (password == null || password.isEmpty) {
      await _prefs.remove(_pdfPasswordKey);
    } else {
      await _prefs.setString(_pdfPasswordKey, password);
    }
  }

  // PDF Watermark
  String? getPdfWatermark() {
    return _prefs.getString(_pdfWatermarkKey);
  }

  Future<void> setPdfWatermark(String? watermark) async {
    if (watermark == null || watermark.isEmpty) {
      await _prefs.remove(_pdfWatermarkKey);
    } else {
      await _prefs.setString(_pdfWatermarkKey, watermark);
    }
  }

  // Biometric app lock
  bool getAppLock() => _prefs.getBool(_appLockKey) ?? false;

  Future<void> setAppLock(bool enabled) async {
    await _prefs.setBool(_appLockKey, enabled);
  }

  // Onboarding
  bool getOnboardingDone() => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingDone(bool done) async {
    await _prefs.setBool(_onboardingKey, done);
  }

  // Dynamic color (Material You)
  bool getDynamicColor() => _prefs.getBool(_dynamicColorKey) ?? true;

  Future<void> setDynamicColor(bool enabled) async {
    await _prefs.setBool(_dynamicColorKey, enabled);
  }

  // Default OCR script
  String getOcrScript() => _prefs.getString(_ocrScriptKey) ?? 'Latin';

  Future<void> setOcrScript(String script) async {
    await _prefs.setString(_ocrScriptKey, script);
  }
}

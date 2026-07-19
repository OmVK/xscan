import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xscan/core/services/settings_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

// Theme Mode Provider
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsService _settingsService;

  ThemeModeNotifier(this._settingsService) : super(_settingsService.getThemeMode());

  void setThemeMode(ThemeMode mode) {
    _settingsService.setThemeMode(mode);
    state = mode;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return ThemeModeNotifier(settingsService);
});

// PDF Password Provider
class PdfPasswordNotifier extends StateNotifier<String?> {
  final SettingsService _settingsService;

  PdfPasswordNotifier(this._settingsService) : super(null) {
    _loadPassword();
  }

  Future<void> _loadPassword() async {
    final password = await _settingsService.getPdfPassword();
    if (mounted) state = password;
  }

  Future<void> setPassword(String? password) async {
    await _settingsService.setPdfPassword(password);
    state = password;
  }
}

final pdfPasswordProvider = StateNotifierProvider<PdfPasswordNotifier, String?>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return PdfPasswordNotifier(settingsService);
});

// PDF Watermark Provider
class PdfWatermarkNotifier extends StateNotifier<String?> {
  final SettingsService _settingsService;

  PdfWatermarkNotifier(this._settingsService) : super(_settingsService.getPdfWatermark());

  void setWatermark(String? watermark) {
    _settingsService.setPdfWatermark(watermark);
    state = watermark;
  }
}

final pdfWatermarkProvider = StateNotifierProvider<PdfWatermarkNotifier, String?>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return PdfWatermarkNotifier(settingsService);
});

// Biometric App Lock Provider
class AppLockNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;

  AppLockNotifier(this._settingsService) : super(_settingsService.getAppLock());

  void setEnabled(bool enabled) {
    _settingsService.setAppLock(enabled);
    state = enabled;
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, bool>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return AppLockNotifier(settingsService);
});

// Dynamic Color (Material You) Provider
class DynamicColorNotifier extends StateNotifier<bool> {
  final SettingsService _settingsService;

  DynamicColorNotifier(this._settingsService)
      : super(_settingsService.getDynamicColor());

  void setEnabled(bool enabled) {
    _settingsService.setDynamicColor(enabled);
    state = enabled;
  }
}

final dynamicColorProvider =
    StateNotifierProvider<DynamicColorNotifier, bool>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return DynamicColorNotifier(settingsService);
});

// Default OCR script Provider
class OcrScriptNotifier extends StateNotifier<String> {
  final SettingsService _settingsService;

  OcrScriptNotifier(this._settingsService)
      : super(_settingsService.getOcrScript());

  void setScript(String script) {
    _settingsService.setOcrScript(script);
    state = script;
  }
}

final ocrScriptProvider =
    StateNotifierProvider<OcrScriptNotifier, String>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  return OcrScriptNotifier(settingsService);
});

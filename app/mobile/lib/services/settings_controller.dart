import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app's language choice. `system` (the default) resolves against the device locale each time
/// rather than being captured once, so a phone-wide language change is picked up on next launch.
enum AppLanguage { system, zh, en }

/// Persisted app-wide preferences: theme and language. Reuses `flutter_secure_storage` (already a
/// dependency for the pairing token) instead of adding a second storage package for two small values.
class SettingsController extends ChangeNotifier {
  static const _themeModeKey = 'settings.themeMode';
  static const _languageKey = 'settings.language';

  final FlutterSecureStorage _storage;
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.system;

  SettingsController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;

  /// The device's language, collapsed to the two this app supports (anything non-Chinese is English).
  static AppLanguage get systemLanguage =>
      PlatformDispatcher.instance.locale.languageCode == 'zh' ? AppLanguage.zh : AppLanguage.en;

  /// The language actually in effect right now — resolves `system` against the device locale.
  AppLanguage get effectiveLanguage =>
      _language == AppLanguage.system ? systemLanguage : _language;

  Future<void> load() async {
    final storedTheme = await _storage.read(key: _themeModeKey);
    final storedLanguage = await _storage.read(key: _languageKey);
    _themeMode = _parseThemeMode(storedTheme) ?? ThemeMode.system;
    _language = _parseLanguage(storedLanguage) ?? AppLanguage.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.write(key: _themeModeKey, value: mode.name);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    await _storage.write(key: _languageKey, value: language.name);
  }

  ThemeMode? _parseThemeMode(String? value) {
    for (final mode in ThemeMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  AppLanguage? _parseLanguage(String? value) {
    for (final language in AppLanguage.values) {
      if (language.name == value) return language;
    }
    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppThemePreference.system => ThemeMode.system,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    AppThemePreference.system => 'System',
    AppThemePreference.light => 'Light',
    AppThemePreference.dark => 'Dark',
  };
}

class AppThemeController extends ChangeNotifier {
  static const preferenceKey = 'appearance_theme';

  AppThemePreference _preference = AppThemePreference.system;
  bool _isLoaded = false;
  Future<void> _saveQueue = Future<void>.value();

  AppThemePreference get preference => _preference;
  ThemeMode get themeMode => _preference.themeMode;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final storedValue = preferences.getString(preferenceKey);
      _preference = AppThemePreference.values.firstWhere(
        (preference) => preference.name == storedValue,
        orElse: () => AppThemePreference.system,
      );
    } catch (_) {
      _preference = AppThemePreference.system;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setPreference(AppThemePreference preference) async {
    if (_preference == preference && _isLoaded) return;

    _preference = preference;
    _isLoaded = true;
    notifyListeners();

    _saveQueue = _saveQueue
        .then((_) async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setString(preferenceKey, preference.name);
        })
        .catchError((Object _) {});
    await _saveQueue;
  }
}

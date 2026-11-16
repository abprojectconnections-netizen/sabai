import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferences stored ON THIS DEVICE only (the backend has no preferences endpoint yet).
/// They change how the app looks (theme) and which reminders the app may ask for; they do not change anything on the server.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs)
      : themeMode = _decodeTheme(_prefs.getString(_kTheme)),
        notifyTrip = _prefs.getBool(_kTrip) ?? true,
        notifyPromo = _prefs.getBool(_kPromo) ?? false;

  static const _kTheme = 'settings.theme';
  static const _kTrip = 'settings.notify.trip';
  static const _kPromo = 'settings.notify.promo';

  final SharedPreferences _prefs;

  ThemeMode themeMode;
  bool notifyTrip;
  bool notifyPromo;

  static ThemeMode _decodeTheme(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setString(_kTheme, m.name);
  }

  Future<void> setNotifyTrip(bool v) async {
    notifyTrip = v;
    notifyListeners();
    await _prefs.setBool(_kTrip, v);
  }

  Future<void> setNotifyPromo(bool v) async {
    notifyPromo = v;
    notifyListeners();
    await _prefs.setBool(_kPromo, v);
  }
}

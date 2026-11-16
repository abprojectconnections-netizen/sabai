import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sabai_app/src/state/settings_controller.dart';

void main() {
  test('defaults, then persisted values survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);
    expect(s.themeMode, ThemeMode.system);
    expect(s.notifyTrip, isTrue);
    expect(s.notifyPromo, isFalse);

    await s.setThemeMode(ThemeMode.dark);
    await s.setNotifyTrip(false);
    await s.setNotifyPromo(true);

    final again = SettingsController(await SharedPreferences.getInstance());
    expect(again.themeMode, ThemeMode.dark);
    expect(again.notifyTrip, isFalse);
    expect(again.notifyPromo, isTrue);
  });

  test('an unknown stored theme falls back to system', () async {
    SharedPreferences.setMockInitialValues({'settings.theme': 'neon'});
    final s = SettingsController(await SharedPreferences.getInstance());
    expect(s.themeMode, ThemeMode.system);
  });
}

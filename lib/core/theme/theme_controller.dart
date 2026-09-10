import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's light/dark preference and persists it.
///
/// `shared_preferences` is used rather than a database because this is a single
/// scalar and it has to work on web and Windows as well as mobile.
class ThemeController extends ChangeNotifier {
  ThemeController(this._preferences)
      : _mode = _decode(_preferences.getString(_storageKey));

  static const String _storageKey = 'theme_mode';

  final SharedPreferences _preferences;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  /// Loads the saved preference. Falls back to following the system when the
  /// store is unavailable, so a storage failure never blocks startup.
  static Future<ThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    return ThemeController(preferences);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _preferences.setString(_storageKey, mode.name);
  }

  /// Cycles system -> light -> dark -> system, which is what the toggle button
  /// in the app bar does.
  Future<void> cycle() => setMode(switch (_mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      });

  /// Flips between explicit light and dark, ignoring the system option.
  Future<void> toggle(Brightness current) => setMode(
        current == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );

  static ThemeMode _decode(String? stored) => switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  static const _prefsKey = 'theme_mode';

  ThemeMode get mode => _mode;

  ThemeController() {
    // Restore persisted theme mode if available
    _restore();
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    _persist(mode);
  }

  void toggleDark(bool isDark) {
    setMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefsKey);
      if (value != null) {
        switch (value) {
          case 'light':
            _mode = ThemeMode.light;
            break;
          case 'dark':
            _mode = ThemeMode.dark;
            break;
          case 'system':
          default:
            _mode = ThemeMode.system;
        }
        notifyListeners();
      }
    } catch (_) {
      // Ignore persistence errors; fall back to default
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await prefs.setString(_prefsKey, value);
    } catch (_) {
      // Ignore persistence errors
    }
  }
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    return scope!.notifier!;
  }
}

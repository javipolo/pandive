/// Preferencias de la app: escala de texto (accesibilidad, presbicia) y ruta
/// de la base de datos activa. Persistido con shared_preferences.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _kTextScale = 'text_scale';
  static const _kDbPath = 'db_path';
  static const _kLocale = 'locale';
  static const _kMergeGap = 'merge_gap';
  static const _kNightStart = 'night_start';
  static const _kNightEnd = 'night_end';
  static const _kTheme = 'theme_mode';

  /// Por defecto grande (uso sin gafas). Configurable de 1.0 a 2.2.
  static const double defaultTextScale = 1.4;
  static const double minTextScale = 1.0;
  static const double maxTextScale = 2.2;

  final SharedPreferences _prefs;

  Settings._(this._prefs);

  static Future<Settings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return Settings._(prefs);
  }

  double get textScale => _prefs.getDouble(_kTextScale) ?? defaultTextScale;

  Future<void> setTextScale(double value) async {
    final v = value.clamp(minTextScale, maxTextScale);
    await _prefs.setDouble(_kTextScale, v);
    notifyListeners();
  }

  String? get dbPath => _prefs.getString(_kDbPath);

  Future<void> setDbPath(String? path) async {
    if (path == null) {
      await _prefs.remove(_kDbPath);
    } else {
      await _prefs.setString(_kDbPath, path);
    }
    notifyListeners();
  }

  /// Idioma de la app: null = seguir el del sistema; si no, 'es' / 'en'.
  Locale? get locale {
    final code = _prefs.getString(_kLocale);
    return code == null ? null : Locale(code);
  }

  /// Máximo intervalo en superficie (min) para poder fusionar inmersiones.
  int get mergeGapMinutes => _prefs.getInt(_kMergeGap) ?? 15;

  Future<void> setMergeGapMinutes(int minutes) async {
    await _prefs.setInt(_kMergeGap, minutes.clamp(1, 240));
    notifyListeners();
  }

  /// Tema: claro / oscuro / seguir el sistema (por defecto).
  ThemeMode get themeMode => switch (_prefs.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString(_kTheme, m.name);
    notifyListeners();
  }

  /// Franja horaria de inmersión nocturna (por defecto 18:00 → 07:00).
  int get nightStartHour => _prefs.getInt(_kNightStart) ?? 18;
  int get nightEndHour => _prefs.getInt(_kNightEnd) ?? 7;

  Future<void> setNightStartHour(int h) async {
    await _prefs.setInt(_kNightStart, h % 24);
    notifyListeners();
  }

  Future<void> setNightEndHour(int h) async {
    await _prefs.setInt(_kNightEnd, h % 24);
    notifyListeners();
  }

  /// ¿Es nocturna una inmersión que entra al agua a esta [hour]? Maneja la
  /// franja que cruza medianoche (p.ej. 18 → 7).
  bool isNight(int hour) {
    final s = nightStartHour, e = nightEndHour;
    return s <= e ? (hour >= s && hour < e) : (hour >= s || hour < e);
  }

  Future<void> setLocale(String? code) async {
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
    notifyListeners();
  }
}

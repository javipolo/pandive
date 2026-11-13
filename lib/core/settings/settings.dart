/// Preferencias de la app: escala de texto (accesibilidad, presbicia) y ruta
/// de la base de datos activa. Persistido con shared_preferences.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _kTextScale = 'text_scale';
  static const _kDbPath = 'db_path';

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

  /// Fingerprint (hex) de la última inmersión descargada de un ordenador, para
  /// descargas incrementales (solo buceos nuevos).
  String? dcFingerprint(String address) => _prefs.getString('fp_$address');

  Future<void> setDcFingerprint(String address, String fingerprint) =>
      _prefs.setString('fp_$address', fingerprint);
}

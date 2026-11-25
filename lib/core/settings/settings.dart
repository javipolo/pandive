/// App preferences: text scale (accessibility, presbyopia) and path
/// of the active database. Persisted with shared_preferences.
library;

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  static const _kTextScale = 'text_scale';
  static const _kDbPath = 'db_path';
  static const _kLocale = 'locale';
  static const _kMergeGap = 'merge_gap';
  static const _kNightStart = 'night_start';
  static const _kNightEnd = 'night_end';
  static const _kTheme = 'theme_mode';
  static const _kBackupAuto = 'backup_auto';
  static const _kBackupTime = 'backup_last_time';
  static const _kBackupHash = 'backup_last_hash';
  static const _kSyncOn = 'sync_enabled';
  static const _kSyncMd5 = 'sync_base_md5';
  static const _kSyncStamp = 'sync_base_stamp';
  static const _kSyncDocs = 'sync_docs_sig';
  static const _kDeviceId = 'device_id';
  static const _kBackupWifi = 'backup_wifi_only';
  static const _kSyncWifi = 'sync_wifi_only';

  /// Large by default (use without glasses). Configurable from 1.0 to 2.2.
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

  /// App language: null = follow the system's; otherwise 'es' / 'en'.
  Locale? get locale {
    final code = _prefs.getString(_kLocale);
    return code == null ? null : Locale(code);
  }

  /// Maximum surface interval (min) to be able to merge dives.
  int get mergeGapMinutes => _prefs.getInt(_kMergeGap) ?? 15;

  Future<void> setMergeGapMinutes(int minutes) async {
    await _prefs.setInt(_kMergeGap, minutes.clamp(1, 240));
    notifyListeners();
  }

  /// Theme: light / dark / follow the system (default).
  ThemeMode get themeMode => switch (_prefs.getString(_kTheme)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode m) async {
    await _prefs.setString(_kTheme, m.name);
    notifyListeners();
  }

  /// Night dive time window (default 18:00 → 07:00).
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

  /// Is a dive entering the water at this [hour] a night dive? Handles the
  /// window crossing midnight (e.g. 18 → 7).
  bool isNight(int hour) {
    final s = nightStartHour, e = nightEndHour;
    return s <= e ? (hour >= s && hour < e) : (hour >= s || hour < e);
  }

  /// Daily automatic backup to Drive enabled.
  bool get autoBackup => _prefs.getBool(_kBackupAuto) ?? false;
  Future<void> setAutoBackup(bool v) async {
    await _prefs.setBool(_kBackupAuto, v);
    notifyListeners();
  }

  /// Automatic backups only on WiFi (manual ones always).
  bool get backupWifiOnly => _prefs.getBool(_kBackupWifi) ?? true;
  Future<void> setBackupWifiOnly(bool v) async {
    await _prefs.setBool(_kBackupWifi, v);
    notifyListeners();
  }

  /// On mobile data, sync does nothing by itself (only the manual button).
  bool get syncWifiOnly => _prefs.getBool(_kSyncWifi) ?? true;
  Future<void> setSyncWifiOnly(bool v) async {
    await _prefs.setBool(_kSyncWifi, v);
    notifyListeners();
  }

  int get backupLastTime => _prefs.getInt(_kBackupTime) ?? 0;
  String? get backupLastHash => _prefs.getString(_kBackupHash);

  Future<void> setBackupState(String hash, int timeMs) async {
    await _prefs.setString(_kBackupHash, hash);
    await _prefs.setInt(_kBackupTime, timeMs);
    notifyListeners();
  }

  /// Cross-device sync via Drive (layer 1, see sync_logic).
  bool get syncEnabled => _prefs.getBool(_kSyncOn) ?? false;
  Future<void> setSyncEnabled(bool v) async {
    await _prefs.setBool(_kSyncOn, v);
    notifyListeners();
  }

  /// Rereads from disk (another isolate, e.g. WorkManager, may have changed them).
  Future<void> reload() => _prefs.reload();

  /// Base of the last sync: md5 of the file on Drive and local stamp
  /// (raw lastWriteUtc) at that moment. Without notifying (internal state).
  String? get syncBaseMd5 => _prefs.getString(_kSyncMd5);
  String? get syncBaseStamp => _prefs.getString(_kSyncStamp);
  Future<void> setSyncBase(String? md5, String? stamp) async {
    await (md5 == null ? _prefs.remove(_kSyncMd5) : _prefs.setString(_kSyncMd5, md5));
    await (stamp == null
        ? _prefs.remove(_kSyncStamp)
        : _prefs.setString(_kSyncStamp, stamp));
  }

  /// Signature (names+sizes) of documents/ at the last zip upload.
  String? get syncDocsSig => _prefs.getString(_kSyncDocs);
  Future<void> setSyncDocsSig(String sig) => _prefs.setString(_kSyncDocs, sig);

  /// Stable id of this device (presence on Drive).
  String get deviceId {
    var id = _prefs.getString(_kDeviceId);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
      _prefs.setString(_kDeviceId, id);
    }
    return id;
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

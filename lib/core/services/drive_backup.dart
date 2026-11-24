/// Backup/restauración de la DB en Google Drive (carpeta visible "Pandive
/// Backups", scope drive.file). Auth OAuth nativo con `flutter_appauth` que
/// persiste un refresh token (en `flutter_secure_storage`), de modo que el
/// backup en segundo plano puede refrescar el access token sin Activity (headless).
/// Requiere un OAuth client **de tipo iOS** (da el esquema invertido sin secreto);
/// ver README. En Linux (sin flutter_appauth) usa [DesktopOAuth] con un client
/// **Desktop app** del mismo proyecto (así ve los mismos backups). La lógica de operaciones está en el `part`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/storage/documents_storage.dart';
import 'backup_util.dart';
import 'desktop_oauth.dart';

part 'drive_backup_ops.dart';

/// OAuth client ID **de tipo iOS** del proyecto Google Cloud (sin secreto; da el
/// esquema invertido `com.googleusercontent.apps.<id>`). Pásalo con
/// `--dart-define=GDRIVE_NATIVE_CLIENT_ID=...`. No es secreto.
const _clientId = String.fromEnvironment(
  'GDRIVE_NATIVE_CLIENT_ID',
  defaultValue: '',
);

/// OAuth client **Desktop app** (mismo proyecto Google Cloud) para la app Linux.
/// Por `--dart-define=GDRIVE_DESKTOP_CLIENT_ID=...` / `..._SECRET=...`.
const _desktopClientId = String.fromEnvironment('GDRIVE_DESKTOP_CLIENT_ID');
const _desktopClientSecret =
    String.fromEnvironment('GDRIVE_DESKTOP_CLIENT_SECRET');

// Endpoints explícitos de Google (sin discovery: evita el fetch a
// accounts.google.com/.well-known, frágil en el isolate de background).
const _serviceConfig = AuthorizationServiceConfiguration(
  authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenEndpoint: 'https://oauth2.googleapis.com/token',
);
const _scopes = [drive.DriveApi.driveFileScope, 'email', 'openid'];
const _kRefresh = 'drive_refresh_token';
const _kEmail = 'drive_email';

/// Un backup listado en Drive (para restaurar).
class BackupEntry {
  final String id;
  final String name;
  final DateTime? modified;
  final bool isLatest;
  const BackupEntry(this.id, this.name, this.modified, this.isLatest);
}

class DriveBackupService {
  static const _folderName = 'Pandive Backups';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _refreshToken;
  String? _email;
  String? _accessToken;
  DateTime? _accessExp;
  String? _folderId;

  String? get email => _email;
  bool get connected => _refreshToken != null;

  /// Escritorio: OAuth loopback propio (flutter_appauth es solo móvil).
  static bool get _desktop => Platform.isLinux;
  static const _desktopAuth = DesktopOAuth(_desktopClientId, _desktopClientSecret);

  /// ¿Se compiló con el client ID de esta plataforma? Sin él no hay login.
  static bool get configured => _desktop
      ? _desktopClientId.isNotEmpty && _desktopClientSecret.isNotEmpty
      : _clientId.isNotEmpty;

  // scheme invertido a partir del client id -> redirect de AppAuth.
  String get _scheme =>
      'com.googleusercontent.apps.${_clientId.replaceAll('.apps.googleusercontent.com', '')}';
  String get _redirectUrl => '$_scheme:/oauth2redirect';

  /// Conexión interactiva: consentimiento en el navegador y guarda el refresh
  /// token. Lanza si falla (para mostrar el error). [browserDoneText]: texto
  /// de la pestaña del navegador al volver (solo escritorio).
  Future<void> signIn({String browserDoneText = ''}) async {
    if (_desktop) {
      final r = await _desktopAuth.authorize(_scopes, doneText: browserDoneText);
      await _saveTokens(r.accessToken, r.expiresAt, r.refreshToken, r.idToken);
      return;
    }
    final res = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: _serviceConfig,
        scopes: _scopes,
        promptValues: const ['consent'],
        additionalParameters: const {'access_type': 'offline'},
      ),
    );
    await _saveTokens(res.accessToken, res.accessTokenExpirationDateTime,
        res.refreshToken, res.idToken);
  }

  Future<void> _saveTokens(String? access, DateTime? exp, String? refresh,
      String? idToken) async {
    _accessToken = access;
    _accessExp = exp;
    _email = _emailFromIdToken(idToken);
    if (refresh != null) {
      _refreshToken = refresh;
      await _storage.write(key: _kRefresh, value: _refreshToken);
    }
    if (_email != null) await _storage.write(key: _kEmail, value: _email);
  }

  Future<void> signOut() async {
    _refreshToken = _accessToken = _email = _folderId = null;
    _accessExp = null;
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kEmail);
  }

  /// Reconexión silenciosa (sin UI): true si hay refresh token guardado.
  /// Funciona en el isolate de background (solo lee el storage).
  Future<bool> signInSilently() async {
    _refreshToken ??= await _storage.read(key: _kRefresh);
    _email ??= await _storage.read(key: _kEmail);
    return _refreshToken != null;
  }

  /// Access token válido (refresca con el refresh token si hace falta). Headless.
  Future<String?> _freshAccessToken() async {
    final exp = _accessExp;
    if (_accessToken != null &&
        exp != null &&
        exp.isAfter(DateTime.now().add(const Duration(minutes: 2)))) {
      return _accessToken;
    }
    final refresh = _refreshToken ??= await _storage.read(key: _kRefresh);
    if (refresh == null) return null;
    if (_desktop) {
      final r = await _desktopAuth.refresh(refresh);
      _accessToken = r.accessToken;
      _accessExp = r.expiresAt;
      return _accessToken;
    }
    final res = await _appAuth.token(TokenRequest(
      _clientId,
      _redirectUrl,
      serviceConfiguration: _serviceConfig,
      scopes: _scopes,
      refreshToken: refresh,
    ));
    _accessToken = res.accessToken;
    _accessExp = res.accessTokenExpirationDateTime;
    if (res.refreshToken != null && res.refreshToken != refresh) {
      _refreshToken = res.refreshToken;
      await _storage.write(key: _kRefresh, value: _refreshToken);
    }
    return _accessToken;
  }

  /// Cliente Drive autenticado, o null si no hay sesión. Si [interactive] y no
  /// hay refresh token, lanza el consentimiento.
  Future<drive.DriveApi?> _api({bool interactive = false}) async {
    var token = await _freshAccessToken();
    if (token == null && interactive) {
      await signIn();
      token = await _freshAccessToken();
    }
    if (token == null) return null;
    return drive.DriveApi(_BearerClient(token));
  }

  Future<String> _ensureFolder(drive.DriveApi api) async {
    if (_folderId != null) return _folderId!;
    final res = await api.files.list(
      q: "mimeType='application/vnd.google-apps.folder' and "
          "name='$_folderName' and trashed=false",
      $fields: 'files(id)',
    );
    final found = res.files;
    if (found != null && found.isNotEmpty) return _folderId = found.first.id!;
    final created = await api.files.create(drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder');
    return _folderId = created.id!;
  }

  Future<String?> dbHash(String? path) async {
    if (path == null) return null;
    final f = File(path);
    if (!f.existsSync()) return null;
    return sha256.convert(await f.readAsBytes()).toString();
  }

  String? _emailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    final parts = idToken.split('.');
    if (parts.length < 2) return null;
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return (jsonDecode(payload) as Map<String, dynamic>)['email'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// http.Client que añade el bearer token a cada petición (para googleapis).
class _BearerClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final String _token;
  _BearerClient(this._token);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

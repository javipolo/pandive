/// DB backup/restore on Google Drive (visible folder "Pandive
/// Backups", scope drive.file). Native OAuth with `flutter_appauth` that
/// persists a refresh token (in `flutter_secure_storage`), so the
/// background backup can refresh the access token without an Activity (headless).
/// Requires an OAuth client **of type iOS** (gives the reversed scheme without a secret);
/// see docs/DEVELOPMENT.md. On Linux (no flutter_appauth) it uses [DesktopOAuth] with a
/// **Desktop app** client of the same project (so it sees the same backups). On web,
/// [DriveWebSession] (popup, short-lived token, nothing stored) with a
/// **Web application** client. The operations logic is in the `part`.
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
import 'drive_web_session.dart';
import 'network.dart';
import '../platform.dart';

part 'drive_backup_ops.dart';
part 'drive_sync_ops.dart';

/// OAuth client ID **of type iOS** of the Google Cloud project (no secret; gives the
/// reversed scheme `com.googleusercontent.apps.<id>`). Pass it with
/// `--dart-define=GDRIVE_NATIVE_CLIENT_ID=...`. It is not secret.
const _clientId = String.fromEnvironment(
  'GDRIVE_NATIVE_CLIENT_ID',
  defaultValue: '',
);

/// OAuth **Desktop app** client (same Google Cloud project) for the Linux app.
/// Via `--dart-define=GDRIVE_DESKTOP_CLIENT_ID=...` / `..._SECRET=...`.
const _desktopClientId = String.fromEnvironment('GDRIVE_DESKTOP_CLIENT_ID');
const _desktopClientSecret =
    String.fromEnvironment('GDRIVE_DESKTOP_CLIENT_SECRET');

// Explicit Google endpoints (no discovery: avoids fetching
// accounts.google.com/.well-known, fragile in the background isolate).
const _serviceConfig = AuthorizationServiceConfiguration(
  authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
  tokenEndpoint: 'https://oauth2.googleapis.com/token',
);
const _scopes = [drive.DriveApi.driveFileScope, 'email', 'openid'];
const _kRefresh = 'drive_refresh_token';
const _kEmail = 'drive_email';

/// A backup listed on Drive (to restore).
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

  String? get email => isWeb ? DriveWebSession.email : _email;
  bool get connected => isWeb ? DriveWebSession.active : _refreshToken != null;

  /// Desktop: our own loopback OAuth (flutter_appauth is mobile only).
  static bool get _desktop => isLinux;
  static const _desktopAuth = DesktopOAuth(_desktopClientId, _desktopClientSecret);

  /// Was it built with this platform's client ID? Without it there's no login.
  static bool get configured => isWeb
      ? webClientId.isNotEmpty
      : _desktop
          ? _desktopClientId.isNotEmpty && _desktopClientSecret.isNotEmpty
          : _clientId.isNotEmpty;

  // reversed scheme from the client id -> AppAuth redirect.
  String get _scheme =>
      'com.googleusercontent.apps.${_clientId.replaceAll('.apps.googleusercontent.com', '')}';
  String get _redirectUrl => '$_scheme:/oauth2redirect';

  /// Interactive connection: consent in the browser and stores the refresh
  /// token. Throws on failure (to show the error). [browserDoneText]: text
  /// of the browser tab on return (desktop only).
  Future<void> signIn({String browserDoneText = ''}) async {
    if (isWeb) return DriveWebSession.signIn(_scopes);
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
    if (isWeb) {
      DriveWebSession.signOut();
      _folderId = null;
      return;
    }
    _refreshToken = _accessToken = _email = _folderId = null;
    _accessExp = null;
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kEmail);
  }

  /// Silent reconnection (no UI): true if a refresh token is stored.
  /// Works in the background isolate (only reads the storage).
  Future<bool> signInSilently() async {
    if (isWeb) return DriveWebSession.active; // no silent refresh on web
    _refreshToken ??= await _storage.read(key: _kRefresh);
    _email ??= await _storage.read(key: _kEmail);
    return _refreshToken != null;
  }

  /// Valid access token (refreshes with the refresh token if needed). Headless.
  Future<String?> _freshAccessToken() async {
    if (isWeb) return DriveWebSession.token;
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

  /// Authenticated Drive client, or null if there's no session. If [interactive] and there's
  /// no refresh token, starts the consent.
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

/// http.Client that adds the bearer token to each request (for googleapis).
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

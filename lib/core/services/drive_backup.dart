/// Backup/restauración de la DB en Google Drive (carpeta visible "Pandive
/// Backups", scope drive.file). Requiere un OAuth client Android en Google Cloud
/// (paquete + SHA-1); ver README. La lógica de operaciones está en el `part`.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/storage/documents_storage.dart';
import 'backup_util.dart';

part 'drive_backup_ops.dart';

/// OAuth client ID **de tipo Web** del proyecto Google Cloud. google_sign_in v7
/// lo exige en Android como `serverClientId`. Pégalo aquí (termina en
/// `.apps.googleusercontent.com`) o pásalo con
/// `--dart-define=GDRIVE_SERVER_CLIENT_ID=...`. No es secreto.
const _serverClientId = String.fromEnvironment(
  'GDRIVE_SERVER_CLIENT_ID',
  defaultValue: '',
);

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
  static const _scope = drive.DriveApi.driveFileScope;

  final GoogleSignIn _gsi = GoogleSignIn.instance;
  bool _inited = false;
  GoogleSignInAccount? _account;
  String? _folderId;

  String? get email => _account?.email;
  bool get connected => _account != null;

  Future<void> _ensureInit() async {
    if (_inited) return;
    if (_serverClientId.isEmpty) {
      throw Exception('Falta el OAuth Web client ID (serverClientId). '
          'Ver README › Backup en Google Drive.');
    }
    await _gsi.initialize(serverClientId: _serverClientId);
    _inited = true;
  }

  /// Reconexión silenciosa (sin UI). Devuelve true si hay cuenta.
  Future<bool> signInSilently() async {
    try {
      await _ensureInit();
      _account = await _gsi.attemptLightweightAuthentication();
    } catch (_) {
      return false;
    }
    return _account != null;
  }

  /// Conexión interactiva: selector de cuenta del teléfono + consentimiento de
  /// Drive en un solo paso (como DiveMate). Lanza si falla (para mostrar el error).
  Future<void> signIn() async {
    await _ensureInit();
    final acc = await _gsi.authenticate(scopeHint: const [_scope]);
    await acc.authorizationClient.authorizeScopes(const [_scope]);
    _account = acc;
  }

  Future<void> signOut() async {
    await _gsi.signOut();
    _account = null;
    _folderId = null;
  }

  /// Cliente Drive autenticado, o null si no hay autorización. Si [interactive]
  /// se pedirá el consentimiento de scopes cuando falte.
  Future<drive.DriveApi?> _api({bool interactive = false}) async {
    final acc = _account;
    if (acc == null) return null;
    GoogleSignInClientAuthorization? authz =
        await acc.authorizationClient.authorizationForScopes(const [_scope]);
    if (authz == null && interactive) {
      try {
        authz = await acc.authorizationClient.authorizeScopes(const [_scope]);
      } on GoogleSignInException {
        return null;
      }
    }
    if (authz == null) return null;
    return drive.DriveApi(authz.authClient(scopes: const [_scope]));
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
}

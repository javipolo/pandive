/// Compartir un fichero generado (export .ddb, .ssrf, JSON, PDF…). En el
/// móvil abre la hoja de compartir; en Linux, donde share_plus no comparte
/// ficheros, abre "Guardar como…" y avisa de dónde quedó.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/l10n/app_localizations.dart';

/// ScaffoldMessenger de la app (MaterialApp.scaffoldMessengerKey): avisos
/// desde lógica sin BuildContext.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Comparte [file] (móvil) o lo guarda donde elija el usuario (Linux).
Future<void> shareOrSaveFile(File file, {String? text}) async {
  if (!Platform.isLinux) {
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], text: text));
    return;
  }
  final messenger = appMessengerKey.currentState;
  final t = messenger == null ? null : AppLocalizations.of(messenger.context);
  final dest = await FilePicker.platform.saveFile(
    dialogTitle: t?.saveAs,
    fileName: file.uri.pathSegments.last,
  );
  if (dest == null) return; // cancelado
  await file.copy(dest);
  if (t != null) {
    messenger!.showSnackBar(SnackBar(content: Text(t.savedTo(dest))));
  }
}

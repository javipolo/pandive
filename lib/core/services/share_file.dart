/// Share a generated file (export .ddb, .ssrf, JSON, PDF…). On
/// mobile it opens the share sheet; on Linux, where share_plus can't share
/// files, it opens "Save as…" and tells where it went.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/l10n/app_localizations.dart';

/// The app's ScaffoldMessenger (MaterialApp.scaffoldMessengerKey): messages
/// from logic without a BuildContext.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shares [file] (mobile) or saves it where the user chooses (Linux).
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

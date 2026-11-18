/// Al recibir un .ddb (abrir con / compartir): ofrece rellenar, previsualizar
/// o reemplazar la base de datos activa.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/settings/screens/fill_from_ddb_screen.dart';
import 'package:pandive/features/settings/screens/preview_ddb_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<void> handleOpenedDdb(BuildContext context, DivemateDb db,
    Settings settings, void Function(String path) onReplace, String path) async {
  final t = AppLocalizations.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.group_add_outlined),
          title: Text(t.fillFromDdb),
          onTap: () => Navigator.pop(context, 'fill'),
        ),
        ListTile(
          leading: const Icon(Icons.visibility_outlined),
          title: Text(t.previewDdb),
          onTap: () => Navigator.pop(context, 'preview'),
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: Text(t.replaceDb),
          subtitle: Text(t.replaceDbWarning),
          onTap: () => Navigator.pop(context, 'replace'),
        ),
      ]),
    ),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case 'fill':
      await openFillFromDdb(context, db, sourcePath: path);
    case 'preview':
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PreviewDdbScreen(path: path, settings: settings)));
    case 'replace':
      if (await confirmDialog(context, t.replaceDbConfirm,
          confirmLabel: t.replaceDb)) {
        onReplace(path);
      }
  }
}

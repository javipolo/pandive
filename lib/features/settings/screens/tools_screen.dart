/// Herramientas: importar hashtags, exportar logbook y utilidades de debug.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/option_dialog.dart';
import 'package:pandive/features/settings/screens/debug_sync_screen.dart';
import 'package:pandive/features/settings/screens/trash_screen.dart';
import 'package:pandive/features/settings/widgets/export_tools.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ToolsScreen extends StatelessWidget {
  final Settings settings;
  final DivemateDb db;
  final VoidCallback onReloadDb;
  const ToolsScreen({
    super.key,
    required this.settings,
    required this.db,
    required this.onReloadDb,
  });

  Future<void> _importHashtags(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final remove = await showOptionDialog(context,
        title: t.importHashtags, checkboxLabel: t.removeHashtags);
    if (remove == null) return;
    final n = db.importHashtagsFromComments(removeFromComments: remove);
    messenger.showSnackBar(
        SnackBar(content: Text(t.importHashtagsResult(n))));
  }

  Future<void> _tagsToHashtags(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final remove = await showOptionDialog(context,
        title: t.tagsToHashtags, checkboxLabel: t.removeTags);
    if (remove == null) return;
    final n = db.exportTagsToComments(removeTags: remove);
    messenger.showSnackBar(
        SnackBar(content: Text(t.tagsToHashtagsResult(n))));
  }

  Future<void> _importSubsurface(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final n = await importSubsurface(context, db);
    if (n == null) return;
    onReloadDb();
    messenger.showSnackBar(
        SnackBar(content: Text(t.importSubsurfaceResult(n))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tools)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.tag),
            title: Text(t.importHashtags),
            onTap: () => _importHashtags(context),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: Text(t.tagsToHashtags),
            onTap: () => _tagsToHashtags(context),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(t.exportLogbook),
            onTap: () => exportDdb(settings),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(t.exportSubsurface),
            onTap: () => exportSubsurface(db),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(t.importSubsurface),
            onTap: () => _importSubsurface(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(t.trash),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TrashScreen(db: db, onReloadDb: onReloadDb))),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(t.debugSyncPoint),
            subtitle: Text(t.debugSyncPointHint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DebugSyncScreen(db: db))),
          ),
        ],
      ),
    );
  }
}

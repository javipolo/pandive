/// Herramientas: importar hashtags, exportar logbook y utilidades de debug.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
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

  void _importHashtags(BuildContext context) {
    final n = db.importHashtagsFromComments();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).importHashtagsResult(n))));
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
            leading: const Icon(Icons.delete_outline),
            title: Text(t.trash),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    TrashScreen(db: db, onReloadDb: onReloadDb))),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug: punto de sync'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DebugSyncScreen(db: db))),
          ),
        ],
      ),
    );
  }
}

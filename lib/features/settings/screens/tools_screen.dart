/// Herramientas: importar hashtags, exportar logbook y utilidades de debug.
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/option_dialog.dart';
import 'package:pandive/features/settings/screens/debug_sync_screen.dart';
import 'package:pandive/features/settings/screens/fill_from_ddb_screen.dart';
import 'package:pandive/features/settings/logic/link_buddies_tool.dart';
import 'package:pandive/features/plan/screens/plan_dive_screen.dart';
import 'package:pandive/features/settings/screens/trash_screen.dart';
import 'package:pandive/features/sites/logic/site_import.dart';
import 'package:pandive/features/sites/screens/import_sites_screen.dart';
import 'package:pandive/features/settings/widgets/export_tools.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ToolsScreen extends StatelessWidget {
  final Settings settings;
  final DivemateDb db;
  const ToolsScreen({super.key, required this.settings, required this.db});
  Future<void> _importHashtags(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final remove = await showOptionDialog(context,
        title: t.importHashtags, checkboxLabel: t.removeHashtags);
    if (remove == null) return;
    final n = db.importHashtagsFromComments(removeFromComments: remove);
    bumpDataRevision();
    messenger.showSnackBar(
        SnackBar(content: Text(t.importHashtagsResult(n))));
  }
  Future<void> _purgeBuddies(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDialog(context, t.purgeBuddiesConfirm,
        confirmLabel: t.delete)) {
      return;
    }
    final n = db.purgeUnusedBuddies();
    bumpDataRevision();
    messenger.showSnackBar(SnackBar(content: Text(t.purgeBuddiesResult(n))));
  }
  Future<void> _purgeOrphanTanks(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDialog(context, t.purgeOrphanTanksConfirm,
        confirmLabel: t.delete)) {
      return;
    }
    final n = db.purgeOrphanData();
    bumpDataRevision();
    messenger.showSnackBar(SnackBar(content: Text(t.purgeOrphanTanksResult(n))));
  }
  Future<void> _tagsToHashtags(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final remove = await showOptionDialog(context,
        title: t.tagsToHashtags, checkboxLabel: t.removeTags);
    if (remove == null) return;
    final n = db.exportTagsToComments(removeTags: remove);
    bumpDataRevision();
    messenger.showSnackBar(
        SnackBar(content: Text(t.tagsToHashtagsResult(n))));
  }
  Future<void> _importSubsurface(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final n = await importSubsurface(context, db);
    if (n == null) return;
    bumpDataRevision();
    messenger.showSnackBar(
        SnackBar(content: Text(t.importSubsurfaceResult(n))));
  }
  Future<void> _importSites(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final t = AppLocalizations.of(context);
    final res = await FilePicker.platform.pickFiles(withData: false);
    final path = res?.files.single.path;
    if (path == null) return;
    if (!context.mounted) return;
    final plan = await withProgress(context, t.working,
        () async => planSiteImport(db, await File(path).readAsString()));
    if (plan.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(t.nothingToImport)));
      return;
    }
    final n = await nav.push<int>(MaterialPageRoute(
        builder: (_) => ImportSitesScreen(db: db, entries: plan)));
    if (n != null && n > 0) {
      messenger.showSnackBar(SnackBar(content: Text(t.importResult(n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tools)),
      body: ListView(
        children: [
          _header(context, t.sectionExportImport),
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
            leading: const Icon(Icons.place_outlined),
            title: Text(t.importSites),
            onTap: () => _importSites(context),
          ),
          _header(context, t.tags),
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
          _header(context, t.sectionOther),
          ListTile(
            leading: const Icon(Icons.calculate_outlined),
            title: Text(t.planTitle),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlanDiveScreen(db: db))),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined),
            title: Text(t.fillFromDdb),
            onTap: () => openFillFromDdb(context, db),
          ),
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(t.linkBuddies),
            onTap: () => runLinkBuddies(context, db),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: Text(t.purgeBuddies),
            onTap: () => _purgeBuddies(context),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(t.purgeOrphanTanks),
            onTap: () => _purgeOrphanTanks(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(t.trash),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TrashScreen(db: db))),
          ),
          _header(context, t.sectionDebug),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(t.debugSyncPoint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DebugSyncScreen(db: db))),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold)),
      );
}

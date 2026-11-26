/// "Cleanup" tools: confirm, delete unused or empty rows, report how many.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// One cleanup action: its menu label, confirmation and result texts, and the
/// DB call that deletes and returns how many rows went.
class CleanupTool {
  final IconData icon;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) confirm;
  final String Function(AppLocalizations, int) result;
  final int Function(DivemateDb) purge;
  const CleanupTool(
      this.icon, this.title, this.confirm, this.result, this.purge);
}

final cleanupTools = <CleanupTool>[
  CleanupTool(Icons.person_remove_outlined, (t) => t.purgeBuddies,
      (t) => t.purgeBuddiesConfirm, (t, n) => t.purgeBuddiesResult(n),
      (db) => db.purgeUnusedBuddies()),
  CleanupTool(Icons.wrong_location_outlined, (t) => t.purgeSites,
      (t) => t.purgeSitesConfirm, (t, n) => t.purgeSitesResult(n),
      (db) => db.purgeUnusedSites()),
  CleanupTool(Icons.cleaning_services_outlined, (t) => t.purgeOrphanTanks,
      (t) => t.purgeOrphanTanksConfirm, (t, n) => t.purgeOrphanTanksResult(n),
      (db) => db.purgeOrphanData()),
  CleanupTool(Icons.scuba_diving_outlined, (t) => t.purgeBlankTanks,
      (t) => t.purgeBlankTanksConfirm, (t, n) => t.purgeBlankTanksResult(n),
      (db) => db.purgeBlankTanks()),
];

Future<void> runCleanupTool(
    BuildContext context, DivemateDb db, CleanupTool tool) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirmDialog(context, tool.confirm(t), confirmLabel: t.delete)) {
    return;
  }
  final n = tool.purge(db);
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(tool.result(t, n))));
}

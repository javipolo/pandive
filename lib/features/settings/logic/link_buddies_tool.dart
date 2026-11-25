/// Tool: links buddies of old dives (`Buddy` text without
/// `BuddyIDs`) so they count in Pandive. Asks for confirmation and reports how many
/// dives were updated.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<void> runLinkBuddies(BuildContext context, DivemateDb db) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!await confirmDialog(context, t.linkBuddiesConfirm,
      confirmLabel: t.linkBuddies)) {
    return;
  }
  final n = db.backfillBuddyIds();
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(t.linkBuddiesResult(n))));
}

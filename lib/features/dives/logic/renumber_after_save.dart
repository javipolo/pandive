/// Tras crear o editar un buceo: con numeración automática renumera; sin
/// ella, si el buceo rompe el orden cronológico, ofrece renumerar.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<void> renumberAfterSave(
    BuildContext context, DivemateDb db, int diveId) async {
  if (db.autoNumber) {
    db.autoRenumber();
    return;
  }
  if (!db.isOutOfOrder(diveId)) return;
  final n = db.renumberPlan().length;
  if (n == 0) return;
  final t = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.renumberOutOfOrderTitle),
      content: Text(t.renumberOutOfOrderBody(n)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.notNow)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.renumberDives)),
      ],
    ),
  );
  if (ok == true) db.renumberDives();
}

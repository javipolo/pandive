/// Merge buddies action: asks which one to keep and merges the rest into it.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Returns true if it merged. [selected] must be 2+ buddies.
Future<bool> runMergeBuddies(
    BuildContext context, DivemateDb db, List<Buddy> selected) async {
  if (selected.length < 2) return false;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final keep = await _chooseKeeper(context, selected, t);
  if (keep == null) return false;
  db.mergeBuddies(keep.id, selected.map((b) => b.id));
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(t.mergeBuddiesDone(keep.name))));
  return true;
}

Future<Buddy?> _chooseKeeper(
    BuildContext context, List<Buddy> selected, AppLocalizations t) {
  var keep = selected.first;
  return showDialog<Buddy>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.mergeKeepTitle),
      content: StatefulBuilder(
        builder: (ctx, setState) => RadioGroup<Buddy>(
          groupValue: keep,
          onChanged: (v) => setState(() => keep = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in selected)
                RadioListTile<Buddy>(
                  value: b,
                  title: Text(b.name),
                  subtitle: Text(t.diveCountLabel(b.diveCount)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(t.cancel)),
        TextButton(
            onPressed: () => Navigator.pop(ctx, keep),
            child: Text(t.mergeBuddies)),
      ],
    ),
  );
}

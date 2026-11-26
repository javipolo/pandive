/// Batch actions over the selected dives: set/clear the dive type and
/// add/remove a tag. Each one asks what to apply, writes in one transaction
/// and reports with a snackbar. They return true if anything changed.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/features/dives/logic/apply_dive_type.dart';
import 'package:pandive/features/dives/widgets/choice_sheet.dart';
import 'package:pandive/l10n/app_localizations.dart';

const _none = -1; // "no dive type" / "new tag" in the pickers

/// Sets a dive type on all [diveIds] (adding its cylinders as the editor
/// does: empty cylinders are replaced, filled ones of the same kind kept) or
/// clears it (cylinders untouched).
Future<bool> runBulkDiveType(
    BuildContext context, DivemateDb db, List<int> diveIds) async {
  if (diveIds.isEmpty) return false;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final types = db.listDiveTypes();
  final pick = await showChoiceSheet<int>(context, t.bulkDiveType, [
    Choice(Icons.block, t.bulkNoDiveType, _none),
    for (final d in types)
      Choice(Icons.scuba_diving, d.name, d.id,
          subtitle: d.tanks.isEmpty
              ? null
              : d.tanks
                  .map((c) => '${c.size?.toStringAsFixed(1) ?? '—'} L')
                  .join(' + ')),
  ]);
  if (pick == null || !context.mounted) return false;
  final type = pick == _none ? null : types.firstWhere((d) => d.id == pick);
  if (type != null &&
      type.tanks.isNotEmpty &&
      !await confirmDialog(
          context, t.bulkDiveTypeTanksConfirm(type.name, diveIds.length),
          confirmLabel: t.apply)) {
    return false;
  }
  if (!context.mounted) return false;
  final changed = await withProgress(context, t.saving, () async {
    return db.inTransaction(() {
      var n = db.setDivesType(diveIds, type?.name);
      if (type != null && type.tanks.isNotEmpty) {
        for (final id in diveIds) {
          if (_applyTanks(db, id, type.tanks)) n++;
        }
      }
      return n;
    });
  });
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(
      content: Text(type == null
          ? t.bulkDiveTypeCleared(diveIds.length)
          : t.bulkDiveTypeSet(type.name, diveIds.length))));
  return changed > 0;
}

/// Applies the type's cylinder template to one dive; true if it changed.
bool _applyTanks(DivemateDb db, int diveId, List<Cylinder> template) {
  final cur = db.cylinders(diveId);
  final kept = cur.where(tankHasPressure).length;
  final next = applyDiveTypeTanks(cur, template);
  if (kept == cur.length && next.length == kept) return false;
  db.setDiveTanks(diveId, next);
  return true;
}

/// Adds a tag (existing or new) to all [diveIds].
Future<bool> runBulkAddTag(
    BuildContext context, DivemateDb db, List<int> diveIds) async {
  if (diveIds.isEmpty) return false;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final tags = db.listTags();
  final pick = await showChoiceSheet<int>(context, t.bulkAddTag, [
    Choice(Icons.add, t.newTag, _none),
    for (final tag in tags) Choice(Icons.label_outline, tag.name, tag.id),
  ]);
  if (pick == null || !context.mounted) return false;
  String name;
  int tagId;
  if (pick == _none) {
    final n = (await nameDialog(context, t.newTag))?.trim();
    if (n == null || n.isEmpty) return false;
    name = n;
    tagId = db.findOrCreateTag(n);
  } else {
    tagId = pick;
    name = tags.firstWhere((x) => x.id == pick).name;
  }
  final n = db.inTransaction(() => db.addTagToDives(tagId, diveIds));
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(t.bulkTagAdded(name, n))));
  return n > 0;
}

/// Removes one of the selection's own tags from all [diveIds]. Tags
/// inherited from the site or dive type can't be removed per dive: the
/// snackbar says how many keep it that way.
Future<bool> runBulkRemoveTag(
    BuildContext context, DivemateDb db, List<int> diveIds) async {
  if (diveIds.isEmpty) return false;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final counts = db.ownTagCounts(diveIds);
  final pick = await showChoiceSheet<int>(
    context,
    t.bulkRemoveTag,
    [
      for (final (tag, count) in counts)
        Choice(Icons.label_off_outlined, tag.name, tag.id,
            subtitle: t.bulkTagOnDives(count)),
    ],
    emptyText: t.bulkNoOwnTags,
  );
  if (pick == null) return false;
  final name = counts.firstWhere((c) => c.$1.id == pick).$1.name;
  final n = db.inTransaction(() => db.removeTagFromDives(pick, diveIds));
  final still = db.diveIdsWithTag(name).intersection(diveIds.toSet()).length;
  bumpDataRevision();
  final msg = t.bulkTagRemoved(name, n);
  messenger.showSnackBar(SnackBar(
      content: Text(still == 0 ? msg : '$msg. ${t.bulkTagStillInherited(still)}')));
  return n > 0;
}

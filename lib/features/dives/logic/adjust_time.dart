/// Batch time adjustment: pick the new time of the first dive and apply the
/// same offset to all selected ones. Returns true if anything changed.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<bool> adjustDivesTime(
    BuildContext context, DivemateDb db, List<Dive> dives) async {
  final withDate = [for (final d in dives) if (d.date != null) d]
    ..sort((a, b) => a.date!.compareTo(b.date!));
  if (withDate.isEmpty) return false;
  final orig = withDate.first.date!;
  final t = AppLocalizations.of(context);
  // Prior notice: explains the batch adjustment before opening the calendar.
  if (!await confirmDialog(context, t.adjustTimeExplain(withDate.length),
      confirmLabel: t.continueLabel)) {
    return false;
  }
  if (!context.mounted) return false;
  final help = '${t.originalTime}: '
      '${MaterialLocalizations.of(context).formatMediumDate(orig)} '
      '${TimeOfDay.fromDateTime(orig).format(context)}';
  final date = await showDatePicker(
      context: context,
      initialDate: orig,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: help);
  if (date == null || !context.mounted) return false;
  final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(orig),
      helpText: help);
  if (time == null) return false;
  final delta =
      DateTime(date.year, date.month, date.day, time.hour, time.minute)
          .difference(orig);
  if (delta == Duration.zero) return false;
  for (final d in dives) {
    if (d.date != null) db.setDiveDateTime(d.id, d.date!.add(delta));
  }
  db.autoRenumber();
  return true;
}

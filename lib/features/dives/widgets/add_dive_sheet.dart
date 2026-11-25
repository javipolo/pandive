/// "Add dive" bottom sheet: manual or transfer from the computer.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/screens/computer_pick_screen.dart';
import 'package:pandive/features/dives/screens/new_dive_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Shows the sheet and navigates to the chosen screen (manual entry or transfer).
/// Returns the id of the newly created dive (manual entry) so it can be highlighted;
/// null if cancelled or it was a transfer.
Future<int?> showAddDiveSheet(
    BuildContext context, DivemateDb db, Settings settings) async {
  final t = AppLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(t.diveTransfer),
          onTap: () => Navigator.pop(context, 'transfer'),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(t.newDiveManual),
          onTap: () => Navigator.pop(context, 'new'),
        ),
      ]),
    ),
  );
  if (!context.mounted || choice == null) return null;
  if (choice == 'new') {
    return Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => NewDiveScreen(db: db)));
  }
  await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ComputerPickScreen(db: db, settings: settings)));
  return null;
}

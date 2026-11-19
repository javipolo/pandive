/// Hoja inferior "añadir inmersión": manual o transferir del ordenador.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/screens/computer_pick_screen.dart';
import 'package:pandive/features/dives/screens/new_dive_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Muestra la hoja y navega a la pantalla elegida (alta manual o transferencia).
Future<void> showAddDiveSheet(
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
  if (!context.mounted || choice == null) return;
  final route = choice == 'new'
      ? MaterialPageRoute(builder: (_) => NewDiveScreen(db: db))
      : MaterialPageRoute(
          builder: (_) => ComputerPickScreen(db: db, settings: settings));
  await Navigator.of(context).push(route);
}

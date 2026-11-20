/// Diálogo "asignar a viaje": elegir un viaje existente o crear uno nuevo y
/// asignarle las inmersiones seleccionadas. Devuelve true si asignó.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<bool> runAssignToTrip(
    BuildContext context, DivemateDb db, List<int> diveIds) async {
  if (diveIds.isEmpty) return false;
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final trips = db.listTrips();

  final choice = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(t.assignToTrip),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, -1),
          child: Row(children: [
            const Icon(Icons.add),
            const SizedBox(width: 12),
            Text(t.newTrip),
          ]),
        ),
        for (final tr in trips)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, tr.id),
            child: Text(tr.name),
          ),
      ],
    ),
  );
  if (choice == null) return false;

  int tripId = choice;
  if (choice == -1) {
    if (!context.mounted) return false;
    final name = await nameDialog(context, t.newTrip);
    if (name == null || name.isEmpty) return false;
    tripId = db.createTrip(name);
  }
  db.assignDivesToTrip(tripId, diveIds);
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(t.tripAssigned)));
  return true;
}

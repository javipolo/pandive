/// Fila de un compañero: avatar, nombre, nº de buceos y menú (renombrar/borrar).
/// Toca para ver sus buceos; en modo selección hace toggle y muestra check.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddyTile extends StatelessWidget {
  final Buddy buddy;
  final bool selected;
  final bool selectMode;
  final DivemateDb db;
  final Settings settings;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const BuddyTile({
    super.key,
    required this.buddy,
    required this.selected,
    required this.selectMode,
    required this.db,
    required this.settings,
    required this.onToggle,
    required this.onLongPress,
    required this.onRename,
    required this.onDelete,
  });

  void _openDives(BuildContext context, AppLocalizations t) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FilteredDivesScreen(
          db: db,
          settings: settings,
          title: t.divesWith(buddy.name),
          loader: () => db.listDivesByBuddy(buddy.id),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListTile(
      selected: selected,
      leading: selected
          ? const CircleAvatar(child: Icon(Icons.check))
          : CircleAvatar(
              child: Text(
                  buddy.name.isNotEmpty ? buddy.name[0].toUpperCase() : '?')),
      title: Text(buddy.name),
      subtitle: Text(t.diveCountLabel(buddy.diveCount)),
      onLongPress: onLongPress,
      onTap: selectMode ? onToggle : () => _openDives(context, t),
      trailing: selectMode
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(t.rename)),
                PopupMenuItem(value: 'delete', child: Text(t.delete)),
              ],
            ),
    );
  }
}

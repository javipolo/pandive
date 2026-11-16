/// Papelera: inmersiones borradas (Status=2) con opción de restaurar (undelete).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TrashScreen extends StatefulWidget {
  final DivemateDb db;
  final VoidCallback onReloadDb;
  const TrashScreen({super.key, required this.db, required this.onReloadDb});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late List<Dive> _dives = widget.db.listDeletedDives();
  bool _changed = false;

  // Restaura sobre la DB abierta (misma conexión) y refresca la lista local.
  // La recarga del resto de la app se hace al salir (evita cerrar la DB aquí).
  void _restore(Dive d) {
    widget.db.restoreDives([d.id]);
    _changed = true;
    setState(() => _dives = widget.db.listDeletedDives());
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).diveRestored)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat(
        'd MMM yyyy, HH:mm', Localizations.localeOf(context).languageCode);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) widget.onReloadDb();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(t.trash)),
        body: _dives.isEmpty
            ? Center(child: Text(t.trashEmpty))
            : ListView.separated(
                itemCount: _dives.length + 1,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.trashIntro,
                          style: Theme.of(context).textTheme.bodySmall),
                    );
                  }
                  final d = _dives[i - 1];
                  final title = [
                    if (d.number != null) '#${d.number}',
                    if (d.place != null && d.place!.isNotEmpty) d.place,
                  ].join(' · ');
                  return ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: Text(title.isEmpty ? '#${d.id}' : title),
                    subtitle:
                        d.date == null ? null : Text(fmt.format(d.date!)),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.restore_from_trash),
                      label: Text(t.restore),
                      onPressed: () => _restore(d),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

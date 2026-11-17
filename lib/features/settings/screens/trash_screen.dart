/// Papelera: inmersiones borradas (Status=2). Selección múltiple para restaurar
/// o borrar definitivamente (con confirmación).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TrashScreen extends StatefulWidget {
  final DivemateDb db;
  const TrashScreen({super.key, required this.db});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late List<Dive> _dives = widget.db.listDeletedDives();
  final _selected = <int>{};

  void _refresh() => setState(() {
        _dives = widget.db.listDeletedDives();
        _selected.clear();
      });

  void _restore() {
    widget.db.restoreDives(_selected.toList());
    bumpDataRevision();
    _refresh();
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deletePermanentConfirm(_selected.length),
        confirmLabel: t.deletePermanently)) {
      return;
    }
    widget.db.purgeDives(_selected.toList());
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat(
        'd MMM yyyy, HH:mm', Localizations.localeOf(context).languageCode);
    final n = _selected.length;
    return Scaffold(
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
                return CheckboxListTile(
                  value: _selected.contains(d.id),
                  onChanged: (v) => setState(() =>
                      v == true ? _selected.add(d.id) : _selected.remove(d.id)),
                  title: Text(title.isEmpty ? '#${d.id}' : title),
                  subtitle: d.date == null ? null : Text(fmt.format(d.date!)),
                );
              },
            ),
      bottomNavigationBar: _dives.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever),
                    label: Text(t.deletePermanently),
                    onPressed: n == 0 ? null : _delete,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.restore_from_trash),
                    label: Text(t.restore),
                    onPressed: n == 0 ? null : _restore,
                  ),
                ),
              ]),
            ),
    );
  }
}

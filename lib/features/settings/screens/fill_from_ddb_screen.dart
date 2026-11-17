/// Rellena datos de buceos propios cruzando con el .ddb de un compañero:
/// empareja por fecha/hora (±1h) y copia sitio, notas y buddies + uno elegido.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/settings/logic/enrich_logbook.dart';
import 'package:pandive/l10n/app_localizations.dart';

class FillFromDdbScreen extends StatefulWidget {
  final DivemateDb db;
  final DivemateDb source;
  const FillFromDdbScreen({super.key, required this.db, required this.source});

  @override
  State<FillFromDdbScreen> createState() => _FillFromDdbScreenState();
}

class _FillFromDdbScreenState extends State<FillFromDdbScreen> {
  final _buddy = TextEditingController();
  final _matches = <int, DiveMatch>{};
  final _selected = <int>{};
  late final List<Dive> _dives;

  @override
  void initState() {
    super.initState();
    _dives = [
      for (final d in widget.db.listDives())
        if (d.date != null) d,
    ].where((d) {
      final m = findSourceMatch(widget.source, d.date!);
      if (m != null) {
        _matches[d.id] = m;
        _selected.add(d.id);
      }
      return m != null;
    }).toList();
  }

  @override
  void dispose() {
    _buddy.dispose();
    widget.source.close();
    super.dispose();
  }

  void _apply() {
    final n = applyEnrich(widget.db, _matches, _selected, _buddy.text);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).fillResult(n))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat('dd/MM/yyyy', Localizations.localeOf(context).languageCode);
    return Scaffold(
      appBar: AppBar(title: Text(t.fillFromDdb), actions: [
        if (_matches.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.check),
              tooltip: t.confirm,
              onPressed: _selected.isEmpty ? null : _apply),
      ]),
      body: _matches.isEmpty
          ? Center(child: Text(t.noMatches))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _buddy,
                  decoration: InputDecoration(
                      labelText: t.buddyToAdd, border: const OutlineInputBorder()),
                ),
              ),
              Expanded(
                child: ListView(children: [
                  for (final d in _dives)
                    CheckboxListTile(
                      value: _selected.contains(d.id),
                      onChanged: (v) => setState(() =>
                          v == true ? _selected.add(d.id) : _selected.remove(d.id)),
                      title: Text(
                          '${d.date != null ? fmt.format(d.date!) : '—'}  ·  ${_matches[d.id]!.place ?? t.site}'),
                      subtitle: Text('#${d.number ?? d.id}'),
                    ),
                ]),
              ),
            ]),
    );
  }
}

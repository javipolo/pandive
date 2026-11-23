/// Lista de viajes de buceo: crear, renombrar, borrar y abrir el detalle.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/core/widgets/selection_bar.dart';
import 'package:pandive/features/trips/logic/export_trip.dart';
import 'package:pandive/features/trips/widgets/export_trips_dialog.dart';
import 'package:pandive/features/trips/screens/trip_detail_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TripsScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  const TripsScreen({super.key, required this.db, required this.settings});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late List<Trip> _trips = widget.db.listTrips();
  bool _desc = true; // listTrips ya viene por fecha descendente
  bool _select = false;
  final Set<int> _sel = {};

  void _reload() => setState(() => _trips = widget.db.listTrips());

  void _exitSel() => setState(() {
        _select = false;
        _sel.clear();
      });

  void _toggle(int id) => setState(() {
        if (!_sel.remove(id)) _sel.add(id);
        if (_sel.isEmpty) _select = false;
      });

  Future<void> _exportSel() async {
    final trips = [for (final tr in _trips) if (_sel.contains(tr.id)) tr];
    if (trips.isEmpty) return;
    final profiles = await showExportTripsDialog(context, trips);
    if (profiles == null || !mounted) return;
    await withProgress(context, AppLocalizations.of(context).working,
        () => exportTripsDdb(widget.db, trips, withProfiles: profiles));
    _exitSel();
  }

  // Orden actual (listTrips es descendente; para ascendente se invierte).
  List<Trip> get _ordered => _desc ? _trips : _trips.reversed.toList();

  Future<void> _add() async {
    final name = await nameDialog(context, AppLocalizations.of(context).newTrip);
    if (name != null && name.isNotEmpty) {
      widget.db.createTrip(name);
      _reload();
    }
  }

  Future<void> _rename(Trip tr) async {
    final name = await nameDialog(context, AppLocalizations.of(context).rename,
        initial: tr.name);
    if (name != null && name.isNotEmpty) {
      widget.db.renameTrip(tr.id, name);
      _reload();
    }
  }

  Future<void> _delete(Trip tr) async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteTripConfirm(tr.name),
        confirmLabel: t.delete)) {
      return;
    }
    widget.db.deleteTrip(tr.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat('dd/MM/yyyy');
    return Scaffold(
      appBar: AppBar(title: Text(t.trips), actions: [
        if (_trips.isNotEmpty)
          IconButton(
            tooltip: t.sortOrder,
            icon: Icon(_desc ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () => setState(() => _desc = !_desc),
          ),
      ]),
      floatingActionButton: _select
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(t.newTrip),
            ),
      body: _trips.isEmpty
          ? Center(child: Text(t.noTrips))
          : Column(children: [
              if (_select)
                SelectionBar(count: _sel.length, onClose: _exitSel, actions: [
                  IconButton(
                      tooltip: t.exportTrip,
                      icon: const Icon(Icons.share),
                      onPressed: _exportSel),
                ]),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: _rows(context, t, fmt),
                ),
              ),
            ]),
    );
  }

  // Filas con cabecera por año (año del viaje = fecha del último buceo).
  List<Widget> _rows(BuildContext context, AppLocalizations t, DateFormat fmt) {
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];
    int? lastYear;
    for (final tr in _ordered) {
      final year = (tr.lastDate ?? tr.firstDate)?.year;
      if (year != lastYear) {
        lastYear = year;
        out.add(Container(
          width: double.infinity,
          color: cs.primaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(year?.toString() ?? '—',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
        ));
      }
      out.add(_tile(tr, t, fmt));
    }
    return out;
  }

  Widget _tile(Trip tr, AppLocalizations t, DateFormat fmt) {
    final range = tr.firstDate == null
        ? null
        : tr.lastDate == null || tr.lastDate == tr.firstDate
            ? fmt.format(tr.firstDate!)
            : '${fmt.format(tr.firstDate!)} – ${fmt.format(tr.lastDate!)}';
    final sub = [
      ?range,
      t.diveCountLabel(tr.diveCount),
      if (tr.buddyCount > 0) t.buddyCountLabel(tr.buddyCount),
    ].join(' · ');
    final selected = _sel.contains(tr.id);
    return ListTile(
      selected: selected,
      leading: CircleAvatar(
          child: Icon(selected ? Icons.check : Icons.luggage)),
      title: Text(tr.name),
      subtitle: Text(sub),
      onLongPress: () => setState(() {
        _select = true;
        _sel.add(tr.id);
      }),
      onTap: _select
          ? () => _toggle(tr.id)
          : () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TripDetailScreen(
                    db: widget.db, settings: widget.settings, trip: tr),
              ));
              _reload();
            },
      trailing: _select
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) => v == 'rename' ? _rename(tr) : _delete(tr),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(t.rename)),
                PopupMenuItem(value: 'delete', child: Text(t.delete)),
              ],
            ),
    );
  }
}

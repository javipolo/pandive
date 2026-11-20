/// Lista de viajes de buceo: crear, renombrar, borrar y abrir el detalle.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/core/widgets/name_dialog.dart';
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

  void _reload() => setState(() => _trips = widget.db.listTrips());

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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(t.newTrip),
      ),
      body: _trips.isEmpty
          ? Center(child: Text(t.noTrips))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: _rows(context, t, fmt),
            ),
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
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.luggage)),
      title: Text(tr.name),
      subtitle: Text(sub),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TripDetailScreen(
              db: widget.db, settings: widget.settings, trip: tr),
        ));
        _reload();
      },
      trailing: PopupMenuButton<String>(
        onSelected: (v) => v == 'rename' ? _rename(tr) : _delete(tr),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'rename', child: Text(t.rename)),
          PopupMenuItem(value: 'delete', child: Text(t.delete)),
        ],
      ),
    );
  }
}

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

  void _reload() => setState(() => _trips = widget.db.listTrips());

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
      appBar: AppBar(title: Text(t.trips)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(t.newTrip),
      ),
      body: _trips.isEmpty
          ? Center(child: Text(t.noTrips))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _trips.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _tile(_trips[i], t, fmt),
            ),
    );
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

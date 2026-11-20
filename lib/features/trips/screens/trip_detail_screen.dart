/// Detalle de un viaje: compañeros (editables) y acceso a sus inmersiones.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/buddies/screens/buddy_picker_screen.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/features/sites/screens/sites_map_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TripDetailScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final Trip trip;
  const TripDetailScreen(
      {super.key,
      required this.db,
      required this.settings,
      required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late List<Buddy> _buddies = widget.db.tripBuddies(widget.trip.id);

  Future<void> _editBuddies() async {
    final picked = await Navigator.of(context).push<List<Buddy>>(
      MaterialPageRoute(
        builder: (_) => BuddyPickerScreen(
            db: widget.db, selectedIds: [for (final b in _buddies) b.id]),
      ),
    );
    if (picked == null) return;
    widget.db.setTripBuddies(widget.trip.id, [for (final b in picked) b.id]);
    setState(() => _buddies = widget.db.tripBuddies(widget.trip.id));
  }

  void _openMap() {
    final t = AppLocalizations.of(context);
    final placeIds = {
      for (final d in widget.db.listDivesByTrip(widget.trip.id)) d.placeId,
    };
    final sites = widget.db
        .listSites()
        .where((s) => placeIds.contains(s.id) && s.hasCoords)
        .toList();
    if (sites.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.noLocatedSites)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SitesMapScreen(
          db: widget.db,
          settings: widget.settings,
          sites: sites,
          title: widget.trip.name),
    ));
  }

  void _fromDives() {
    final ids = <int>{for (final b in _buddies) b.id};
    for (final d in widget.db.listDivesByTrip(widget.trip.id)) {
      for (final b in widget.db.diveBuddies(d.id)) {
        ids.add(b.id);
      }
    }
    widget.db.setTripBuddies(widget.trip.id, ids);
    setState(() => _buddies = widget.db.tripBuddies(widget.trip.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.trip.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.scuba_diving),
            title: Text(t.divesWith(widget.trip.name)),
            subtitle: Text(t.diveCountLabel(widget.trip.diveCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FilteredDivesScreen(
                db: widget.db,
                settings: widget.settings,
                title: widget.trip.name,
                loader: () => widget.db.listDivesByTrip(widget.trip.id),
              ),
            )),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_outlined),
            title: Text(t.viewOnMap),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openMap,
          ),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(t.buddies,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed: _fromDives,
                icon: const Icon(Icons.auto_awesome),
                label: Text(t.tripBuddiesFromDives),
              ),
              IconButton(
                  tooltip: t.edit,
                  icon: const Icon(Icons.edit),
                  onPressed: _editBuddies),
            ],
          ),
          if (_buddies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(t.noBuddies),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final b in _buddies) Chip(label: Text(b.name)),
              ],
            ),
        ],
      ),
    );
  }
}

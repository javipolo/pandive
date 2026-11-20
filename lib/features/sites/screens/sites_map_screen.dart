/// Visor de todos los sitios de buceo con coordenadas sobre un mapa de satélite.
/// Tocar un marcador muestra el nombre y permite ver sus inmersiones.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/site_map.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitesMapScreen extends StatelessWidget {
  final DivemateDb db;
  final Settings settings;
  const SitesMapScreen({super.key, required this.db, required this.settings});

  void _open(BuildContext context, DiveSite s) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.place),
              title: Text(s.name ?? t.site),
              subtitle: Text(t.diveCountLabel(s.diveCount)),
            ),
            ListTile(
              leading: const Icon(Icons.scuba_diving),
              title: Text(t.divesWith(s.name ?? t.site)),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FilteredDivesScreen(
                    db: db,
                    settings: settings,
                    title: s.name ?? t.site,
                    loader: () => db.listDivesBySite(s.id),
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sites = db.listSites().where((s) => s.hasCoords).toList();
    final points = [for (final s in sites) LatLng(s.lat!, s.lon!)];
    return Scaffold(
      appBar: AppBar(title: Text(t.mapTitle)),
      body: sites.isEmpty
          ? Center(child: Text(t.noLocatedSites))
          : SiteMap(
              center: points.first,
              zoom: 8,
              fitBounds: points,
              markers: [
                for (final s in sites)
                  Marker(
                    point: LatLng(s.lat!, s.lon!),
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _open(context, s),
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40),
                    ),
                  ),
              ],
            ),
    );
  }
}

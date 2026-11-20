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
  /// Si se pasa, muestra solo estos sitios (p.ej. los de un viaje); si no, todos.
  final List<DiveSite>? sites;
  final String? title;
  /// Une los sitios con una línea en el orden dado y numera los marcadores
  /// (recorrido del viaje).
  final bool connect;
  const SitesMapScreen(
      {super.key,
      required this.db,
      required this.settings,
      this.sites,
      this.title,
      this.connect = false});

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

  Widget _numbered(BuildContext context, int n) => Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$n',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final located =
        (sites ?? db.listSites()).where((s) => s.hasCoords).toList();
    final points = [for (final s in located) LatLng(s.lat!, s.lon!)];
    return Scaffold(
      appBar: AppBar(title: Text(title ?? t.mapTitle)),
      body: located.isEmpty
          ? Center(child: Text(t.noLocatedSites))
          : SiteMap(
              center: points.first,
              zoom: 8,
              fitBounds: points,
              route: connect ? points : null,
              markers: [
                for (var i = 0; i < located.length; i++)
                  Marker(
                    point: points[i],
                    width: connect ? 30 : 40,
                    height: connect ? 30 : 40,
                    alignment:
                        connect ? Alignment.center : Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _open(context, located[i]),
                      child: connect
                          ? _numbered(context, i + 1)
                          : const Icon(Icons.location_on,
                              color: Colors.red, size: 40),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Viewer of all dive sites with coordinates on a satellite map.
/// Tapping a marker shows the name and lets you see its dives. For a trip,
/// also its ports (boat markers, not numbered): the route starts at the
/// departure port and ends at the arrival port.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/core/widgets/site_map.dart';
import 'package:pandive/features/dives/screens/filtered_dives_screen.dart';
import 'package:pandive/features/ports/widgets/port_marker.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitesMapScreen extends StatelessWidget {
  final DivemateDb db;

  /// Only to open a site's dives from its marker; if null, the
  /// marker only shows the name.
  final Settings? settings;

  /// If given, shows only these sites (e.g. a trip's); otherwise all.
  final List<DiveSite>? sites;
  final String? title;

  /// Joins the sites with a line in the given order and numbers the markers
  /// (trip route).
  final bool connect;

  /// Trip ports (shown with a boat; the route goes from [departure] to
  /// [arrival]) and other ports to show without joining (e.g. the dives').
  final Port? departure;
  final Port? arrival;
  final List<Port> ports;
  const SitesMapScreen({
    super.key,
    required this.db,
    this.settings,
    this.sites,
    this.title,
    this.connect = false,
    this.departure,
    this.arrival,
    this.ports = const [],
  });

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
            if (settings != null)
              ListTile(
                leading: const Icon(Icons.scuba_diving),
                title: Text(t.divesWith(s.name ?? t.site)),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FilteredDivesScreen(
                        db: db,
                        settings: settings!,
                        title: s.name ?? t.site,
                        loader: () => db.listDivesBySite(s.id),
                      ),
                    ),
                  );
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
    child: Text(
      '$n',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final located = (sites ?? db.listSites())
        .where((s) => s.hasCoords)
        .toList();
    final points = [for (final s in located) LatLng(s.lat!, s.lon!)];
    LatLng? at(Port? p) =>
        (p != null && p.hasCoords) ? LatLng(p.lat!, p.lon!) : null;
    final dep = at(departure), arr = at(arrival);
    final route = [?dep, ...points, ?arr];
    // Each port once, with its role (a trip port wins over a dive's).
    final roles = <int, (Port, String)>{
      for (final p in ports) p.id: (p, t.port),
      if (arrival != null) arrival!.id: (arrival!, t.arrivalPort),
      if (departure != null)
        departure!.id: (
          departure!,
          departure!.id == arrival?.id
              ? '${t.departurePort} · ${t.arrivalPort}'
              : t.departurePort,
        ),
    };
    final portMarkers = [
      for (final (p, role) in roles.values)
        if (p.hasCoords) portMarker(context, p, role),
    ];
    final all = [...points, for (final m in portMarkers) m.point];
    return Scaffold(
      appBar: AppBar(title: Text(title ?? t.mapTitle)),
      body: all.isEmpty
          ? Center(child: Text(t.noLocatedSites))
          : Stack(
              children: [
                SiteMap(
                  center: all.first,
                  zoom: 8,
                  fitBounds: all,
                  route: connect ? route : null,
                  markers: [
                    ...portMarkers,
                    for (var i = 0; i < located.length; i++)
                      Marker(
                        point: points[i],
                        width: connect ? 30 : 40,
                        height: connect ? 30 : 40,
                        alignment: connect
                            ? Alignment.center
                            : Alignment.topCenter,
                        child: GestureDetector(
                          onTap: () => _open(context, located[i]),
                          child: connect
                              ? _numbered(context, i + 1)
                              : const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 40,
                                ),
                        ),
                      ),
                  ],
                ),
                if (connect && route.length >= 2)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            t.tripDistance(_km(route)),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // Km travelled, adding up the distances between consecutive points.
  String _km(List<LatLng> pts) {
    const d = Distance();
    var m = 0.0;
    for (var i = 1; i < pts.length; i++) {
      m += d.distance(pts[i - 1], pts[i]);
    }
    final km = m / 1000;
    return km.toStringAsFixed(km >= 100 ? 0 : 1);
  }
}

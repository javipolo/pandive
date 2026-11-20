/// Mapa reutilizable con tiles de satélite de Esri World Imagery (gratis, sin
/// API key, con atribución). Usado por el selector de ubicación y el visor de
/// sitios.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _esriUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

class SiteMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final void Function(LatLng)? onTap;
  final MapController? controller;
  /// Si se pasan 2+ puntos, encuadra el mapa para mostrarlos todos.
  final List<LatLng>? fitBounds;
  const SiteMap({
    super.key,
    required this.center,
    this.zoom = 6,
    this.markers = const [],
    this.onTap,
    this.controller,
    this.fitBounds,
  });

  @override
  Widget build(BuildContext context) {
    final fit = fitBounds;
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        initialCameraFit: (fit != null && fit.length >= 2)
            ? CameraFit.coordinates(
                coordinates: fit, padding: const EdgeInsets.all(48))
            : null,
        minZoom: 2,
        maxZoom: 19,
        onTap: onTap == null ? null : (_, p) => onTap!(p),
      ),
      children: [
        TileLayer(
          urlTemplate: _esriUrl,
          userAgentPackageName: 'org.drslump.pandive',
          maxNativeZoom: 19,
        ),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
                'Esri, Maxar, Earthstar Geographics, GIS User Community'),
          ],
        ),
      ],
    );
  }
}

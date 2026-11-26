/// Map marker for a port: a boat in a blue circle, so it stands apart from
/// the numbered (red) dive sites and doesn't count in the route numbering.
/// Tapping shows its name and role (departure / arrival / port).
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:pandive/core/models/models.dart';

Marker portMarker(BuildContext context, Port p, String role) => Marker(
  point: LatLng(p.lat!, p.lon!),
  width: 32,
  height: 32,
  child: GestureDetector(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.directions_boat),
          title: Text(p.name),
          subtitle: Text(role),
        ),
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.directions_boat, color: Colors.white, size: 18),
    ),
  ),
);

/// Selector de ubicación en un mapa de satélite: tocar para colocar el marcador,
/// botón "mi ubicación" (GPS). Devuelve el LatLng elegido al confirmar.
library;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:pandive/core/widgets/site_map.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<LatLng?> pickLocation(BuildContext context, LatLng? initial) =>
    Navigator.of(context).push<LatLng>(MaterialPageRoute(
      builder: (_) => MapPickerScreen(initial: initial),
    ));

class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _ctrl = MapController();
  late LatLng? _picked = widget.initial;

  Future<void> _myLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'off';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'denied';
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = here);
      _ctrl.move(here, 15);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.locationDenied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final center = _picked ?? const LatLng(20, 0);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pickLocation),
        actions: [
          TextButton.icon(
            onPressed: _picked == null
                ? null
                : () => Navigator.of(context).pop(_picked),
            icon: const Icon(Icons.check),
            label: Text(t.save),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _myLocation,
        child: const Icon(Icons.my_location),
      ),
      body: SiteMap(
        controller: _ctrl,
        center: center,
        zoom: _picked == null ? 2 : 13,
        onTap: (p) => setState(() => _picked = p),
        markers: [
          if (_picked != null)
            Marker(
              point: _picked!,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
        ],
      ),
    );
  }
}

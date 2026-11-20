/// Selector de ubicación: mueve el mapa (mira fija en el centro) y guarda el
/// centro. Botón "mi ubicación" (GPS) y buscador por nombre (geocoding Nominatim).
library;

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
      _ctrl.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.locationDenied)));
    }
  }

  Future<void> _doSearch() async {
    final q = _search.text.trim();
    if (q.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final focus = FocusScope.of(context);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search'
          '?format=json&limit=1&q=${Uri.encodeQueryComponent(q)}');
      final res = await http
          .get(uri, headers: {'User-Agent': 'Pandive/1.0 (dive logbook)'});
      final list = res.statusCode == 200
          ? jsonDecode(res.body) as List
          : const [];
      if (list.isEmpty) throw 'none';
      final m = list.first as Map<String, dynamic>;
      _ctrl.move(
          LatLng(double.parse(m['lat']), double.parse(m['lon'])), 13);
      focus.unfocus();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.searchNoResults)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pickLocation),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_ctrl.camera.center),
            icon: const Icon(Icons.check),
            label: Text(t.save),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _myLocation,
        child: const Icon(Icons.my_location),
      ),
      body: Stack(
        children: [
          SiteMap(
            controller: _ctrl,
            center: widget.initial ?? const LatLng(20, 0),
            zoom: widget.initial == null ? 2 : 13,
          ),
          // Mira fija: el pin apunta siempre al centro del mapa.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.location_on, color: Colors.red, size: 44),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: SearchBar(
              controller: _search,
              hintText: t.searchPlace,
              leading: const Icon(Icons.search),
              onSubmitted: (_) => _doSearch(),
            ),
          ),
        ],
      ),
    );
  }
}

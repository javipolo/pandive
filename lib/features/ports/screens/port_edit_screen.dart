/// Create or edit a port: name + optional GPS position (typed or picked on
/// the map). Pops with the saved port's id (null if cancelled).
library;

import 'package:material_ui/material_ui.dart';
import 'package:latlong2/latlong.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/save_action.dart';
import 'package:pandive/features/sites/screens/map_picker_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PortEditScreen extends StatefulWidget {
  final DivemateDb db;
  final Port? port;
  const PortEditScreen({super.key, required this.db, this.port});

  @override
  State<PortEditScreen> createState() => _PortEditScreenState();
}

class _PortEditScreenState extends State<PortEditScreen> {
  late final _name = TextEditingController(text: widget.port?.name ?? '');
  late final _lat = TextEditingController(
    text: widget.port?.lat?.toString() ?? '',
  );
  late final _lon = TextEditingController(
    text: widget.port?.lon?.toString() ?? '',
  );

  @override
  void dispose() {
    for (final c in [_name, _lat, _lon]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _save() {
    final t = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.portNameRequired)));
      return;
    }
    final lat = _d(_lat), lon = _d(_lon);
    // Only a full pair counts as a position.
    final (la, lo) = (lat != null && lon != null) ? (lat, lon) : (null, null);
    final p = widget.port;
    if (p == null) {
      Navigator.of(context).pop(widget.db.createPort(name, lat: la, lon: lo));
    } else {
      widget.db.updatePort(p.id, name, lat: la, lon: lo);
      Navigator.of(context).pop(p.id);
    }
  }

  Future<void> _pickLocation() async {
    final lat = _d(_lat), lon = _d(_lon);
    final picked = await pickLocation(
      context,
      (lat != null && lon != null) ? LatLng(lat, lon) : null,
    );
    if (picked != null) {
      _lat.text = picked.latitude.toStringAsFixed(6);
      _lon.text = picked.longitude.toStringAsFixed(6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.port == null ? t.newPort : t.editPort),
        actions: [SaveAction(saving: false, onSave: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(controller: _name, label: t.portName),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  controller: _lat,
                  label: t.latitude,
                  number: true,
                  signed: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabeledField(
                  controller: _lon,
                  label: t.longitude,
                  number: true,
                  signed: true,
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map_outlined),
            label: Text(t.pickOnMap),
          ),
        ],
      ),
    );
  }
}

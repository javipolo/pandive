/// Create or edit a dive site. Fields: name, country, body of water, region.
library;

import 'package:material_ui/material_ui.dart';

import 'package:latlong2/latlong.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/features/dives/screens/tag_picker_screen.dart';
import 'package:pandive/features/dives/widgets/tags_picker_field.dart';
import 'package:pandive/features/sites/screens/map_picker_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteEditScreen extends StatefulWidget {
  final DivemateDb db;
  final DiveSite? site;
  const SiteEditScreen({super.key, required this.db, this.site});

  @override
  State<SiteEditScreen> createState() => _SiteEditScreenState();
}

class _SiteEditScreenState extends State<SiteEditScreen> {
  late final _name = TextEditingController(text: widget.site?.name ?? '');
  late final _country = TextEditingController(text: widget.site?.country ?? '');
  late final _water = TextEditingController(text: widget.site?.waterName ?? '');
  late final _region = TextEditingController(text: widget.site?.region ?? '');
  late final _lat =
      TextEditingController(text: widget.site?.lat?.toString() ?? '');
  late final _lon =
      TextEditingController(text: widget.site?.lon?.toString() ?? '');
  late List<Tag> _tags =
      widget.site == null ? [] : widget.db.tagsForSite(widget.site!.id);

  @override
  void dispose() {
    for (final c in [_name, _country, _water, _region, _lat, _lon]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _s(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickTags() async {
    final r = await Navigator.of(context).push<List<Tag>>(MaterialPageRoute(
        builder: (_) => TagPickerScreen(
            db: widget.db, selectedIds: [for (final t in _tags) t.id])));
    if (r != null) setState(() => _tags = r);
  }

  void _save() {
    final map = <String, Object?>{
      'Place': _s(_name),
      'Country': _s(_country),
      'WaterName': _s(_water),
      'Region': _s(_region),
      'Lat': double.tryParse(_lat.text.trim())?.toStringAsFixed(6),
      'Lon': double.tryParse(_lon.text.trim())?.toStringAsFixed(6),
    };
    final int id;
    if (widget.site == null) {
      id = widget.db.createSite(map);
    } else {
      widget.db.updateSite(widget.site!.id, map);
      id = widget.site!.id;
    }
    widget.db.setSiteTags(id, _tags);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final site = widget.site;
    return Scaffold(
      appBar: AppBar(
        title: Text(site == null ? t.newSite : t.editSite),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(t.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LabeledField(controller: _name, label: t.fieldSite),
          LabeledField(controller: _country, label: t.fieldCountry),
          LabeledField(controller: _water, label: t.fieldStretchOfWater),
          LabeledField(controller: _region, label: t.fieldRegion),
          Row(
            children: [
              Expanded(
                  child: LabeledField(
                      controller: _lat,
                      label: t.latitude,
                      number: true,
                      signed: true)),
              const SizedBox(width: 12),
              Expanded(
                  child: LabeledField(
                      controller: _lon,
                      label: t.longitude,
                      number: true,
                      signed: true)),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map_outlined),
            label: Text(t.pickOnMap),
          ),
          const SizedBox(height: 8),
          TagsPickerField(tags: _tags, onTap: _pickTags),
        ],
      ),
    );
  }

  Future<void> _pickLocation() async {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    final initial = (lat != null && lon != null) ? LatLng(lat, lon) : null;
    final picked = await pickLocation(context, initial);
    if (picked != null) {
      _lat.text = picked.latitude.toStringAsFixed(6);
      _lon.text = picked.longitude.toStringAsFixed(6);
    }
  }
}

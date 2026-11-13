/// Crear o editar un sitio de buceo. Campos: nombre, país, masa de agua,
/// región, lat/lon, dificultad, valoración. (Sin agua/altitud/mapa/forecast.)
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/star_rating.dart';
import 'package:pandive/features/sites/widgets/site_dives_screen.dart';
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
  late final _difficulty =
      TextEditingController(text: widget.site?.difficulty ?? '');
  late int _rating = widget.site?.rating ?? 0;

  @override
  void dispose() {
    for (final c in [_name, _country, _water, _region, _lat, _lon, _difficulty]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _s(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _save() {
    final map = <String, Object?>{
      'Place': _s(_name),
      'Country': _s(_country),
      'WaterName': _s(_water),
      'Region': _s(_region),
      'Lat': _s(_lat),
      'Lon': _s(_lon),
      'Difficulty': _s(_difficulty),
      'Rating': _rating,
    };
    if (widget.site == null) {
      widget.db.createSite(map);
    } else {
      widget.db.updateSite(widget.site!.id, map);
    }
    Navigator.of(context).pop(true);
  }

  void _showDives() {
    final dives = widget.db.listDivesBySite(widget.site!.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SiteDivesScreen(
          db: widget.db, title: widget.site!.name ?? '', dives: dives),
    ));
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
          LabeledField(controller: _lat, label: t.fieldLatitude, number: true),
          LabeledField(controller: _lon, label: t.fieldLongitude, number: true),
          LabeledField(controller: _difficulty, label: t.fieldDifficulty),
          const SizedBox(height: 8),
          StarRating(
              value: _rating,
              label: t.ratingLabel,
              onChanged: (v) => setState(() => _rating = v)),
          if (site != null) ...[
            const Divider(height: 32),
            ListTile(
              leading: const Icon(Icons.scuba_diving),
              title: Text(t.diveCountLabel(site.diveCount)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showDives,
            ),
          ],
        ],
      ),
    );
  }
}

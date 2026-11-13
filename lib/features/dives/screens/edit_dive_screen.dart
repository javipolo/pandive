/// Edición completa de una inmersión: campos, sitio, compañeros y botellas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/sac.dart';
import 'package:pandive/features/buddies/screens/buddy_picker_screen.dart';
import 'package:pandive/features/dives/widgets/buddies_picker_field.dart';
import 'package:pandive/features/dives/widgets/dive_form.dart';
import 'package:pandive/features/dives/widgets/site_picker_field.dart';
import 'package:pandive/features/dives/widgets/tanks_editor.dart';
import 'package:pandive/features/sites/screens/site_picker_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class EditDiveScreen extends StatefulWidget {
  final DivemateDb db;
  final Dive dive;
  const EditDiveScreen({super.key, required this.db, required this.dive});

  @override
  State<EditDiveScreen> createState() => _EditDiveScreenState();
}

class _EditDiveScreenState extends State<EditDiveScreen> {
  late final DiveFormControllers _c = DiveFormControllers.fromDive(widget.dive);
  late DateTime _when = widget.dive.date ?? DateTime.now();
  late int _rating = widget.dive.rating ?? 0;
  DiveSite? _site;
  List<Buddy> _buddies = [];
  List<Cylinder> _tanks = [];
  late final List<TankPreset> _presets = widget.db.listTankPresets();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pid = widget.dive.placeId;
    _site = pid != null ? widget.db.getSite(pid) : null;
    _buddies = widget.db.diveBuddies(widget.dive.id);
    _tanks = widget.db.cylinders(widget.dive.id);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));
  String? _s(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickSite() async {
    final s = await Navigator.of(context).push<DiveSite>(MaterialPageRoute(
        builder: (_) => SitePickerScreen(db: widget.db)));
    if (s != null) setState(() => _site = s);
  }

  Future<void> _pickBuddies() async {
    final r = await Navigator.of(context).push<List<Buddy>>(MaterialPageRoute(
        builder: (_) => BuddyPickerScreen(
            db: widget.db, selectedIds: [for (final b in _buddies) b.id])));
    if (r != null) setState(() => _buddies = r);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String p(int v) => v.toString().padLeft(2, '0');
      widget.db.updateDive(widget.dive.id, {
        'Depth': _d(_c.maxDepth),
        'DepthAvg': _d(_c.avgDepth),
        'Divetime': _d(_c.duration),
        'Watertemp': _d(_c.waterTemp),
        'Airtemp': _d(_c.airTemp),
        'Weight': _d(_c.weight),
        'Surfint': _s(_c.surfaceInterval),
        'Comments': _s(_c.comments),
        'Rating': _rating,
        'Divedate': '${_when.year}-${p(_when.month)}-${p(_when.day)}',
        'Entrytime': '${p(_when.hour)}:${p(_when.minute)}:00',
        'Place': _site?.name,
        'Country': _site?.country,
        'PlaceID': _site?.id,
        'Buddy': _buddies.isEmpty ? null : _buddies.map((b) => b.name).join(', '),
        'BuddyIDs': _buddies.isEmpty ? null : _buddies.map((b) => b.id).join(','),
      });
      widget.db.setDiveTanks(widget.dive.id, _tanks);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).errorSave('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sac = computeSac(_tanks,
        divetimeMin: _d(_c.duration), avgDepthM: _d(_c.avgDepth));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dive.number != null
            ? t.editDiveNumber(widget.dive.number!)
            : t.editDive),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(t.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SitePickerField(
            site: _site,
            onTap: _pickSite,
            onClear: () => setState(() => _site = null),
          ),
          BuddiesPickerField(buddies: _buddies, onTap: _pickBuddies),
          DiveForm(
            c: _c,
            when: _when,
            onWhen: (v) => setState(() => _when = v),
            rating: _rating,
            onRating: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 16),
          TanksEditor(
            tanks: _tanks,
            presets: _presets,
            sac: sac,
            onChanged: (list) => setState(() => _tanks = list),
          ),
        ],
      ),
    );
  }
}

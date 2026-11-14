/// Alta manual de inmersión: campos, sitio, compañeros, tipo y botellas.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/sac.dart';
import 'package:pandive/core/widgets/save_action.dart';
import 'package:pandive/features/buddies/screens/buddy_picker_screen.dart';
import 'package:pandive/features/dives/screens/tag_picker_screen.dart';
import 'package:pandive/features/dives/widgets/dive_editor_form.dart';
import 'package:pandive/features/dives/widgets/dive_form.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/sites/screens/site_picker_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class NewDiveScreen extends StatefulWidget {
  final DivemateDb db;
  const NewDiveScreen({super.key, required this.db});

  @override
  State<NewDiveScreen> createState() => _NewDiveScreenState();
}

class _NewDiveScreenState extends State<NewDiveScreen> {
  final DiveFormControllers _c = DiveFormControllers.empty();
  DateTime _when = DateTime.now();
  int _rating = 0;
  DiveSite? _site;
  List<Buddy> _buddies = [];
  List<Tag> _tags = [];
  List<Cylinder> _tanks = [];
  String? _typeName;
  late final List<TankPreset> _presets = widget.db.listTankPresets();
  late final int _number = widget.db.nextDiveNumber();
  bool _saving = false;

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
    final s = await Navigator.of(context).push<DiveSite>(
        MaterialPageRoute(builder: (_) => SitePickerScreen(db: widget.db)));
    if (s != null) setState(() => _site = s);
  }

  Future<void> _pickBuddies() async {
    final r = await Navigator.of(context).push<List<Buddy>>(MaterialPageRoute(
        builder: (_) => BuddyPickerScreen(
            db: widget.db, selectedIds: [for (final b in _buddies) b.id])));
    if (r != null) setState(() => _buddies = r);
  }

  Future<void> _pickTags() async {
    final r = await Navigator.of(context).push<List<Tag>>(MaterialPageRoute(
        builder: (_) => TagPickerScreen(
            db: widget.db, selectedIds: [for (final t in _tags) t.id])));
    if (r != null) setState(() => _tags = r);
  }

  Future<void> _pickType() async {
    final chosen = await showDiveTypePicker(context, widget.db.listDiveTypes());
    if (chosen == null) return;
    setState(() {
      _typeName = chosen.name;
      _tanks = [...chosen.tanks]; // añade las botellas del tipo
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = widget.db.createDive(
        dateTime: _when,
        number: _number,
        place: _site?.name,
        country: _site?.country,
        placeId: _site?.id,
        maxDepth: _d(_c.maxDepth),
        avgDepth: _d(_c.avgDepth),
        durationMin: _d(_c.duration),
        waterTemp: _d(_c.waterTemp),
        airTemp: _d(_c.airTemp),
        weight: _d(_c.weight),
        rating: _rating,
        buddy: _buddies.isEmpty ? null : _buddies.map((b) => b.name).join(', '),
        buddyIds: _buddies.isEmpty ? null : _buddies.map((b) => b.id).join(','),
        comments: _s(_c.comments),
      );
      if (_typeName != null) widget.db.updateDive(id, {'Divetype': _typeName});
      widget.db.setDiveTanks(id, _tanks);
      widget.db.setDiveTags(id, _tags);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).errorCreate('$e'))));
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
        title: Text(t.newDiveNumber(_number)),
        actions: [SaveAction(saving: _saving, onSave: _save)],
      ),
      body: DiveEditorForm(
        c: _c,
        when: _when,
        onWhen: (v) => setState(() => _when = v),
        rating: _rating,
        onRating: (v) => setState(() => _rating = v),
        site: _site,
        onPickSite: _pickSite,
        onClearSite: () => setState(() => _site = null),
        buddies: _buddies,
        onPickBuddies: _pickBuddies,
        tags: _tags,
        onPickTags: _pickTags,
        diveTypeName: _typeName,
        onPickType: _pickType,
        onClearType: () => setState(() => _typeName = null),
        tanks: _tanks,
        presets: _presets,
        onTanksChanged: (list) => setState(() => _tanks = list),
        sac: sac,
      ),
    );
  }
}

/// Formulario de alta manual de una inmersión nueva.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/widgets/date_time_field.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/star_rating.dart';
import 'package:pandive/features/dives/widgets/cylinder_input.dart';
import 'package:pandive/l10n/app_localizations.dart';

class NewDiveScreen extends StatefulWidget {
  final DivemateDb db;
  const NewDiveScreen({super.key, required this.db});

  @override
  State<NewDiveScreen> createState() => _NewDiveScreenState();
}

class _NewDiveScreenState extends State<NewDiveScreen> {
  final _place = TextEditingController();
  final _country = TextEditingController();
  final _maxDepth = TextEditingController();
  final _avgDepth = TextEditingController();
  final _duration = TextEditingController();
  final _waterTemp = TextEditingController();
  final _airTemp = TextEditingController();
  final _weight = TextEditingController();
  final _buddy = TextEditingController();
  final _diveMaster = TextEditingController();
  final _diveType = TextEditingController();
  final _comments = TextEditingController();
  final _cyl = CylinderInputController();

  DateTime _when = DateTime.now();
  int _rating = 0;
  bool _saving = false;
  late final int _number = widget.db.nextDiveNumber();

  @override
  void dispose() {
    for (final c in [
      _place, _country, _maxDepth, _avgDepth, _duration, _waterTemp,
      _airTemp, _weight, _buddy, _diveMaster, _diveType, _comments,
    ]) {
      c.dispose();
    }
    _cyl.dispose();
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? _s(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      widget.db.createDive(
        dateTime: _when,
        number: _number,
        place: _s(_place),
        country: _s(_country),
        maxDepth: _d(_maxDepth),
        avgDepth: _d(_avgDepth),
        durationMin: _d(_duration),
        waterTemp: _d(_waterTemp),
        airTemp: _d(_airTemp),
        weight: _d(_weight),
        rating: _rating,
        buddy: _s(_buddy),
        diveMaster: _s(_diveMaster),
        diveType: _s(_diveType),
        comments: _s(_comments),
        cylinder: _cyl.toCylinder(),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(t.newDiveNumber(_number)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(t.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DateTimeField(
            value: _when,
            onChanged: (v) => setState(() => _when = v),
          ),
          const Divider(),
          LabeledField(controller: _place, label: t.fieldSite),
          LabeledField(controller: _country, label: t.fieldCountry),
          _twoCols(
            LabeledField(controller: _maxDepth, label: t.fieldMaxDepthM, number: true),
            LabeledField(controller: _avgDepth, label: t.fieldAvgDepthM, number: true),
          ),
          _twoCols(
            LabeledField(controller: _duration, label: t.fieldDurationMin, number: true),
            LabeledField(controller: _weight, label: t.fieldWeightKg, number: true),
          ),
          _twoCols(
            LabeledField(controller: _waterTemp, label: t.fieldWaterTempC, number: true),
            LabeledField(controller: _airTemp, label: t.fieldAirTempC, number: true),
          ),
          const SizedBox(height: 8),
          StarRating(value: _rating, label: t.ratingLabel,
              onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 8),
          LabeledField(controller: _buddy, label: t.fieldBuddy),
          LabeledField(controller: _diveMaster, label: t.fieldGuide),
          LabeledField(controller: _diveType, label: t.fieldDiveType),
          LabeledField(controller: _comments, label: t.fieldNotes, maxLines: 4),
          const SizedBox(height: 16),
          CylinderInput(controller: _cyl),
        ],
      ),
    );
  }

  Widget _twoCols(Widget a, Widget b) => Row(children: [
        Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
      ]);
}

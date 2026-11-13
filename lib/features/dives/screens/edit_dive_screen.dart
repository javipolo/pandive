/// Formulario de edición de los campos editables de una inmersión.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/star_rating.dart';
import 'package:pandive/l10n/app_localizations.dart';

class EditDiveScreen extends StatefulWidget {
  final DivemateDb db;
  final Dive dive;

  const EditDiveScreen({super.key, required this.db, required this.dive});

  @override
  State<EditDiveScreen> createState() => _EditDiveScreenState();
}

class _EditDiveScreenState extends State<EditDiveScreen> {
  late final _place = TextEditingController(text: widget.dive.place ?? '');
  late final _country = TextEditingController(text: widget.dive.country ?? '');
  late final _buddy = TextEditingController(text: widget.dive.buddy ?? '');
  late final _diveMaster =
      TextEditingController(text: widget.dive.diveMaster ?? '');
  late final _diveType =
      TextEditingController(text: widget.dive.diveType ?? '');
  late final _weight = TextEditingController(
      text: widget.dive.weight != null ? '${widget.dive.weight}' : '');
  late final _comments =
      TextEditingController(text: widget.dive.comments ?? '');
  late int _rating = widget.dive.rating ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _place, _country, _buddy, _diveMaster, _diveType, _weight, _comments,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _s(TextEditingController c) {
    final s = c.text.trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final w = _weight.text.trim().replaceAll(',', '.');
      widget.db.updateDive(widget.dive.id, {
        'Place': _s(_place),
        'Country': _s(_country),
        'Buddy': _s(_buddy),
        'Divemaster': _s(_diveMaster),
        'Divetype': _s(_diveType),
        'Comments': _s(_comments),
        'Rating': _rating,
        'Weight': w.isEmpty ? null : double.tryParse(w),
      });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dive.number != null
            ? t.editDiveNumber(widget.dive.number!)
            : t.editDive),
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
          LabeledField(controller: _place, label: t.fieldSite),
          LabeledField(controller: _country, label: t.fieldCountry),
          const SizedBox(height: 8),
          StarRating(
              value: _rating,
              label: t.ratingLabel,
              onChanged: (v) => setState(() => _rating = v)),
          const SizedBox(height: 8),
          LabeledField(controller: _buddy, label: t.fieldBuddy),
          LabeledField(controller: _diveMaster, label: t.fieldGuide),
          LabeledField(controller: _diveType, label: t.fieldDiveType),
          LabeledField(controller: _weight, label: t.fieldWeightKg, number: true),
          LabeledField(controller: _comments, label: t.fieldNotes, maxLines: 5),
          const SizedBox(height: 16),
          Text(
            t.editFieldsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

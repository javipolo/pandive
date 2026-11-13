/// Edición de todos los campos escalares de una inmersión (el perfil no).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/dive_form.dart';
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String p(int v) => v.toString().padLeft(2, '0');
      widget.db.updateDive(widget.dive.id, {
        'Place': _s(_c.place),
        'Country': _s(_c.country),
        'Depth': _d(_c.maxDepth),
        'DepthAvg': _d(_c.avgDepth),
        'Divetime': _d(_c.duration),
        'Watertemp': _d(_c.waterTemp),
        'Airtemp': _d(_c.airTemp),
        'Weight': _d(_c.weight),
        'Surfint': _s(_c.surfaceInterval),
        'Buddy': _s(_c.buddy),
        'Divemaster': _s(_c.diveMaster),
        'Divetype': _s(_c.diveType),
        'Comments': _s(_c.comments),
        'Rating': _rating,
        'Divedate': '${_when.year}-${p(_when.month)}-${p(_when.day)}',
        'Entrytime': '${p(_when.hour)}:${p(_when.minute)}:00',
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
      body: DiveForm(
        c: _c,
        when: _when,
        onWhen: (v) => setState(() => _when = v),
        rating: _rating,
        onRating: (v) => setState(() => _rating = v),
      ),
    );
  }
}

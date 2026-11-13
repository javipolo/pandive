/// Formulario de campos escalares de una inmersión (todos editables menos el
/// perfil). Reutilizable; el estado de fecha/valoración vive en el padre.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/date_time_field.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/star_rating.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Controllers de los campos de texto del formulario.
class DiveFormControllers {
  final place = TextEditingController();
  final country = TextEditingController();
  final maxDepth = TextEditingController();
  final avgDepth = TextEditingController();
  final duration = TextEditingController();
  final waterTemp = TextEditingController();
  final airTemp = TextEditingController();
  final weight = TextEditingController();
  final surfaceInterval = TextEditingController();
  final buddy = TextEditingController();
  final diveMaster = TextEditingController();
  final diveType = TextEditingController();
  final comments = TextEditingController();

  DiveFormControllers.fromDive(Dive d) {
    String n(double? v) => v == null ? '' : '$v';
    place.text = d.place ?? '';
    country.text = d.country ?? '';
    maxDepth.text = n(d.maxDepth);
    avgDepth.text = n(d.avgDepth);
    duration.text = d.durationMin == null ? '' : '${d.durationMin!.round()}';
    waterTemp.text = n(d.waterTemp);
    airTemp.text = n(d.airTemp);
    weight.text = n(d.weight);
    surfaceInterval.text = d.surfaceInterval ?? '';
    buddy.text = d.buddy ?? '';
    diveMaster.text = d.diveMaster ?? '';
    diveType.text = d.diveType ?? '';
    comments.text = d.comments ?? '';
  }

  void dispose() {
    for (final c in [
      place, country, maxDepth, avgDepth, duration, waterTemp, airTemp,
      weight, surfaceInterval, buddy, diveMaster, diveType, comments,
    ]) {
      c.dispose();
    }
  }
}

class DiveForm extends StatelessWidget {
  final DiveFormControllers c;
  final DateTime when;
  final ValueChanged<DateTime> onWhen;
  final int rating;
  final ValueChanged<int> onRating;

  const DiveForm({
    super.key,
    required this.c,
    required this.when,
    required this.onWhen,
    required this.rating,
    required this.onRating,
  });

  Widget _two(Widget a, Widget b) => Row(children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ]);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DateTimeField(value: when, onChanged: onWhen),
        const Divider(),
        LabeledField(controller: c.place, label: t.fieldSite),
        LabeledField(controller: c.country, label: t.fieldCountry),
        _two(
          LabeledField(controller: c.maxDepth, label: t.fieldMaxDepthM, number: true),
          LabeledField(controller: c.avgDepth, label: t.fieldAvgDepthM, number: true),
        ),
        _two(
          LabeledField(controller: c.duration, label: t.fieldDurationMin, number: true),
          LabeledField(controller: c.weight, label: t.fieldWeightKg, number: true),
        ),
        _two(
          LabeledField(controller: c.waterTemp, label: t.fieldWaterTempC, number: true),
          LabeledField(controller: c.airTemp, label: t.fieldAirTempC, number: true),
        ),
        LabeledField(controller: c.surfaceInterval, label: t.fieldSurfaceInt),
        const SizedBox(height: 8),
        StarRating(value: rating, label: t.ratingLabel, onChanged: onRating),
        const SizedBox(height: 8),
        LabeledField(controller: c.buddy, label: t.fieldBuddy),
        LabeledField(controller: c.diveMaster, label: t.fieldGuide),
        LabeledField(controller: c.diveType, label: t.fieldDiveType),
        LabeledField(controller: c.comments, label: t.fieldNotes, maxLines: 4),
      ],
    );
  }
}

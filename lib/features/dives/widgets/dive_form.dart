/// Scalar fields of a dive (date, depths, times, etc.).
/// Site, buddies and cylinders are handled separately with pickers.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/date_time_field.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/star_rating.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Controllers of the scalar text fields.
class DiveFormControllers {
  final maxDepth = TextEditingController();
  final avgDepth = TextEditingController();
  final duration = TextEditingController();
  final waterTemp = TextEditingController();
  final airTemp = TextEditingController();
  final weight = TextEditingController();
  final surfaceInterval = TextEditingController();
  final comments = TextEditingController();

  DiveFormControllers.empty();

  DiveFormControllers.fromDive(Dive d) {
    String n(double? v) => v == null ? '' : '$v';
    maxDepth.text = n(d.maxDepth);
    avgDepth.text = n(d.avgDepth);
    duration.text = d.durationMin == null ? '' : '${d.durationMin!.round()}';
    waterTemp.text = n(d.waterTemp);
    airTemp.text = n(d.airTemp);
    weight.text = n(d.weight);
    surfaceInterval.text = d.surfaceInterval ?? '';
    comments.text = d.comments ?? '';
  }

  void dispose() {
    for (final c in [
      maxDepth, avgDepth, duration, waterTemp, airTemp, weight,
      surfaceInterval, comments,
    ]) {
      c.dispose();
    }
  }
}

/// (Embeddable) Column with the scalar fields.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DateTimeField(value: when, onChanged: onWhen),
        StarRating(value: rating, label: t.ratingLabel, onChanged: onRating),
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
        LabeledField(controller: c.comments, label: t.fieldNotes, maxLines: 4),
      ],
    );
  }
}

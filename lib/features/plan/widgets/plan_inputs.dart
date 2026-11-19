/// Campos de entrada del planificador: tipo de buceo (precarga litros), RMV,
/// profundidad y tiempo medios, volumen total, presión inicial y reserva.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/plan/widgets/plan_reserve_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanInputs extends StatelessWidget {
  final TextEditingController rmv, depth, time, litres, start, custom;
  final String? typeName;
  final VoidCallback onPickType;
  final VoidCallback onClearType;
  final ReserveRule rule;
  final ValueChanged<ReserveRule> onRuleChanged;

  const PlanInputs({
    super.key,
    required this.rmv,
    required this.depth,
    required this.time,
    required this.litres,
    required this.start,
    required this.custom,
    required this.typeName,
    required this.onPickType,
    required this.onClearType,
    required this.rule,
    required this.onRuleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DiveTypePickerField(
          typeName: typeName,
          onTap: onPickType,
          onClear: onClearType,
        ),
        LabeledField(controller: rmv, label: t.planRmv, number: true),
        LabeledField(controller: depth, label: t.planDepth, number: true),
        LabeledField(controller: time, label: t.planTime, number: true),
        LabeledField(controller: litres, label: t.planVolume, number: true),
        LabeledField(controller: start, label: t.planStartBar, integer: true),
        PlanReserveField(
          rule: rule,
          onRuleChanged: onRuleChanged,
          custom: custom,
        ),
      ],
    );
  }
}

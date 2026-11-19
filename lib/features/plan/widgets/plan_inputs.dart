/// Campos de entrada del planificador: tipo de buceo (precarga botellas), RMV,
/// profundidad y tiempo medios, lista de botellas, presión inicial y reserva.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/plan/widgets/plan_cylinders_field.dart';
import 'package:pandive/features/plan/widgets/plan_reserve_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanInputs extends StatelessWidget {
  final TextEditingController rmv, depth, time, start, custom;
  final String? typeName;
  final VoidCallback onPickType;
  final VoidCallback onClearType;
  final ReserveRule rule;
  final ValueChanged<ReserveRule> onRuleChanged;
  final List<PlanCyl> cylinders;
  final ValueChanged<PlanCyl> onToggleCyl;
  final ValueChanged<PlanCyl> onRemoveCyl;
  final VoidCallback onAddCyl;

  const PlanInputs({
    super.key,
    required this.rmv,
    required this.depth,
    required this.time,
    required this.start,
    required this.custom,
    required this.typeName,
    required this.onPickType,
    required this.onClearType,
    required this.rule,
    required this.onRuleChanged,
    required this.cylinders,
    required this.onToggleCyl,
    required this.onRemoveCyl,
    required this.onAddCyl,
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
        PlanCylindersField(
          cylinders: cylinders,
          onToggle: onToggleCyl,
          onRemove: onRemoveCyl,
          onAdd: onAddCyl,
        ),
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

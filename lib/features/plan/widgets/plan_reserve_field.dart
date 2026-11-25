/// Reserve mode picker (green end-pressure threshold per cylinder):
/// 35 bar, 50 bar, thirds (1/3), quarters (1/2) or custom.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanReserveField extends StatelessWidget {
  final ReserveRule rule;
  final ValueChanged<ReserveRule> onRuleChanged;
  final TextEditingController custom;

  const PlanReserveField({
    super.key,
    required this.rule,
    required this.onRuleChanged,
    required this.custom,
  });

  String _label(AppLocalizations t, ReserveRule r) {
    switch (r) {
      case ReserveRule.bar35:
        return '35 bar';
      case ReserveRule.bar50:
        return '50 bar';
      case ReserveRule.thirds:
        return t.reserveThirds;
      case ReserveRule.quarters:
        return t.reserveQuarters;
      case ReserveRule.custom:
        return t.reserveCustom;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DropdownButtonFormField<ReserveRule>(
            initialValue: rule,
            decoration: InputDecoration(
              labelText: t.planReserveRule,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final r in ReserveRule.values)
                DropdownMenuItem(value: r, child: Text(_label(t, r))),
            ],
            onChanged: (r) => r == null ? null : onRuleChanged(r),
          ),
        ),
        if (rule == ReserveRule.custom)
          LabeledField(
              controller: custom, label: t.planReserveBar, integer: true),
      ],
    );
  }
}

/// Resultados del planificador: gas necesario, caída de presión, presión final
/// (coloreada según la reserva), margen y tiempo máximo a esa profundidad.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanResults extends StatelessWidget {
  final GasPlan? plan;
  const PlanResults({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = plan;
    if (p == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(t.planIncomplete),
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final endColor = p.ok ? Colors.green.shade700 : cs.error;
    final marginSign = p.marginBar >= 0 ? '+' : '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(context, t.planGasNeeded, '${p.gasNeededL.round()} L'),
            _row(context, '${t.planDrop} ${t.planPerBottle}',
                '${p.deltaBar.round()} bar'),
            _row(context, t.planReserveRule, '${p.reserveBar.round()} bar'),
            const Divider(),
            _row(
              context,
              '${t.planEndPressure} ${t.planPerBottle}',
              '${p.endBar.round()} bar',
              color: endColor,
              bold: true,
            ),
            _row(
              context,
              t.planMargin,
              '$marginSign${p.marginBar.round()} bar',
              color: endColor,
            ),
            const Divider(),
            _row(context, t.planMaxTime, '${p.maxTimeMin.round()} min'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {Color? color, bool bold = false}) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: bold ? FontWeight.bold : null,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

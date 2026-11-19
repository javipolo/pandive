/// Lista editable de botellas: cada fila con sus litros y una marca de si
/// mantiene reserva o se vacía (etapa). Añadir/quitar filas.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Fila de botella del planificador (litros + marca de reserva).
class PlanCyl {
  final TextEditingController litres;
  bool reserve;
  PlanCyl({String text = '', this.reserve = true})
      : litres = TextEditingController(text: text);
  void dispose() => litres.dispose();
}

class PlanCylindersField extends StatelessWidget {
  final List<PlanCyl> cylinders;
  final ValueChanged<PlanCyl> onToggle;
  final ValueChanged<PlanCyl> onRemove;
  final VoidCallback onAdd;

  const PlanCylindersField({
    super.key,
    required this.cylinders,
    required this.onToggle,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(t.planCylinders,
              style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final c in cylinders) _row(context, t, c),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(t.planAddCylinder),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, AppLocalizations t, PlanCyl c) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: LabeledField(
              controller: c.litres, label: t.planCylLitres, number: true),
        ),
        Expanded(
          child: InkWell(
            onTap: () => onToggle(c),
            child: Row(children: [
              Checkbox(
                  value: !c.reserve, onChanged: (_) => onToggle(c)),
              Flexible(child: Text(t.cylEmpties)),
            ]),
          ),
        ),
        IconButton(
          tooltip: t.delete,
          icon: const Icon(Icons.close),
          onPressed: cylinders.length > 1 ? () => onRemove(c) : null,
        ),
      ],
    );
  }
}

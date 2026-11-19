/// Editor de botellas de una inmersión + muestra el SAC calculado.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'tank_edit_sheet.dart';

class TanksEditor extends StatelessWidget {
  final List<Cylinder> tanks;
  final List<TankPreset> presets;
  final ValueChanged<List<Cylinder>> onChanged;
  final double? sac; // l/min

  const TanksEditor({
    super.key,
    required this.tanks,
    required this.presets,
    required this.onChanged,
    this.sac,
  });

  Future<void> _edit(BuildContext context, int? index) async {
    final result = await showTankEditSheet(
      context,
      initial: index != null ? tanks[index] : null,
      presets: presets,
    );
    if (result == null) return;
    final next = [...tanks];
    if (index != null) {
      next[index] = result;
    } else {
      next.add(result);
    }
    onChanged(next);
  }

  void _remove(int index) {
    final next = [...tanks]..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(t.tanks, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (sac != null)
              Chip(label: Text('${t.sacLabel}: ${sac!.toStringAsFixed(1)} l/min')),
          ],
        ),
        for (var i = 0; i < tanks.length; i++) _tile(context, i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: Text(t.addTank),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, int i) {
    final c = tanks[i];
    final t = AppLocalizations.of(context);
    final parts = <String>[
      c.gasLabel,
      if (c.size != null) '${c.size!.toStringAsFixed(0)} L',
      if (c.material != null)
        (c.material == TankMaterial.steel ? t.steel : t.aluminium),
      if (c.pressureStart != null && c.pressureEnd != null)
        '${c.pressureStart!.round()} → ${c.pressureEnd!.round()} bar',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.propane_tank_outlined),
        title: Text(c.name ?? t.tankN(i + 1)),
        subtitle: Text(parts.join('   ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(i),
        ),
        onTap: () => _edit(context, i),
      ),
    );
  }
}

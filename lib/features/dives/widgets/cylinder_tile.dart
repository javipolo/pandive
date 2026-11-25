/// Card of a cylinder in the dive detail.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';

class CylinderTile extends StatelessWidget {
  final Cylinder cylinder;
  const CylinderTile({super.key, required this.cylinder});

  @override
  Widget build(BuildContext context) {
    final c = cylinder;
    final parts = <String>[
      c.gasLabel,
      if (c.size != null) '${c.size!.toStringAsFixed(0)} L',
      if (c.pressureStart != null && c.pressureEnd != null)
        '${c.pressureStart!.round()} → ${c.pressureEnd!.round()} bar',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.propane_tank_outlined),
        title: Text(c.name ?? parts.first),
        subtitle: Text(parts.join('   ')),
      ),
    );
  }
}

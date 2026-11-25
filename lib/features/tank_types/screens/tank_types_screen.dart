/// Cylinder type management (reusable presets): create, edit, delete.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/tank_types/widgets/tank_type_edit_sheet.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TankTypesScreen extends StatefulWidget {
  final DivemateDb db;
  const TankTypesScreen({super.key, required this.db});

  @override
  State<TankTypesScreen> createState() => _TankTypesScreenState();
}

class _TankTypesScreenState extends State<TankTypesScreen> {
  late List<TankPreset> _items = widget.db.listTankPresets();

  void _reload() => setState(() => _items = widget.db.listTankPresets());

  Future<void> _edit({TankPreset? preset}) async {
    final r = await showTankTypeSheet(context, initial: preset);
    if (r == null) return;
    if (preset == null) {
      widget.db.addTankPreset(r.name, r.litres, r.material);
    } else {
      widget.db.updateTankPreset(preset.id, r.name, r.litres, r.material);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tankTypes)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? Center(child: Text(t.noTankTypes))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _items[i];
                return ListTile(
                  leading: const Icon(Icons.propane_tank_outlined),
                  title: Text(p.name),
                  subtitle: Text(
                      '${p.litres.toStringAsFixed(1)} L · '
                      '${p.material == TankMaterial.steel ? t.steel : t.aluminium}'),
                  onTap: () => _edit(preset: p),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      widget.db.deleteTankPreset(p.id);
                      _reload();
                    },
                  ),
                );
              },
            ),
    );
  }
}

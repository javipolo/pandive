/// Gestión de tipos de buceo: lista, crear, editar, borrar.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dive_types/screens/dive_type_edit_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DiveTypesScreen extends StatefulWidget {
  final DivemateDb db;
  const DiveTypesScreen({super.key, required this.db});

  @override
  State<DiveTypesScreen> createState() => _DiveTypesScreenState();
}

class _DiveTypesScreenState extends State<DiveTypesScreen> {
  late List<DiveType> _items = widget.db.listDiveTypes();

  void _reload() => setState(() => _items = widget.db.listDiveTypes());

  Future<void> _edit({DiveType? type}) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => DiveTypeEditScreen(db: widget.db, type: type)));
    if (ok == true) _reload();
  }

  String _summary(DiveType d) =>
      d.tanks.map((c) => '${c.size?.toStringAsFixed(1) ?? '—'} L').join(' + ');

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.diveTypes)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? Center(child: Text(t.noDiveTypes))
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = _items[i];
                return ListTile(
                  leading: const Icon(Icons.scuba_diving),
                  title: Text(d.name),
                  subtitle: d.tanks.isEmpty ? null : Text(_summary(d)),
                  onTap: () => _edit(type: d),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      widget.db.deleteDiveType(d.id);
                      _reload();
                    },
                  ),
                );
              },
            ),
    );
  }
}

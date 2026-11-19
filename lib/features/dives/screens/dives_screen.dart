/// Pestaña de inmersiones: lista por mes con acciones en lote, añadir, búsqueda
/// (externa, desde la barra superior). La lista y sus acciones viven en
/// `DivesActionList`.
library;

import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/widgets/add_dive_sheet.dart';
import 'package:pandive/features/dives/widgets/dives_action_list.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DivesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String query;
  final bool collapseAll;
  const DivesTab({
    super.key,
    required this.db,
    required this.settings,
    this.query = '',
    this.collapseAll = false,
  });
  @override
  State<DivesTab> createState() => _DivesTabState();
}

class _DivesTabState extends State<DivesTab> {
  late List<Dive> _dives = widget.db.listDives(search: widget.query);
  late Set<int> _cave = widget.db.diveIdsWithTag('cave');
  bool _selecting = false;

  @override
  void didUpdateWidget(DivesTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _reload();
  }

  void _reload() => setState(() {
        _dives = widget.db.listDives(search: widget.query);
        _cave = widget.db.diveIdsWithTag('cave');
      });

  Future<void> _add() async {
    await showAddDiveSheet(context, widget.db, widget.settings);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(t.newDive)),
      body: DivesActionList(
        db: widget.db,
        settings: widget.settings,
        dives: _dives,
        caveIds: _cave,
        collapseAll: widget.collapseAll,
        onChanged: _reload,
        onSelectionMode: (v) => setState(() => _selecting = v),
      ),
    );
  }
}

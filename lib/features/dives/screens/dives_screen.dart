/// Dives tab: monthly list with batch actions, add, search
/// (external, from the top bar). The list and its actions live in
/// `DivesActionList`.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/logic/dive_search.dart';
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
  late List<Dive> _dives = filterDives(widget.db.listDives(), widget.query);
  late Set<int> _cave = widget.db.diveIdsWithTag('cave');
  bool _selecting = false;
  int? _highlightId; // newly added dive, to highlight/scroll to
  Timer? _hlTimer;

  @override
  void dispose() {
    _hlTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(DivesTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _reload();
  }

  void _reload() => setState(() {
        _dives = filterDives(widget.db.listDives(), widget.query);
        _cave = widget.db.diveIdsWithTag('cave');
      });

  Future<void> _add() async {
    final id = await showAddDiveSheet(context, widget.db, widget.settings);
    if (!mounted) return;
    _reload();
    if (id != null) _flash(id);
  }

  void _flash(int id) {
    setState(() => _highlightId = id);
    _hlTimer?.cancel();
    _hlTimer = Timer(const Duration(seconds: 3),
        () => mounted ? setState(() => _highlightId = null) : null);
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
        highlightDiveId: _highlightId,
        onChanged: _reload,
        onSelectionMode: (v) => setState(() => _selecting = v),
      ),
    );
  }
}

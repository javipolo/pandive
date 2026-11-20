/// Lista de inmersiones filtradas (por sitio, compañero o etiqueta) con las
/// mismas acciones que la pestaña principal (stats, fusionar, exportar, borrar)
/// y búsqueda interna sobre el subconjunto.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/logic/dive_search.dart';
import 'package:pandive/features/dives/widgets/dives_action_list.dart';
import 'package:pandive/l10n/app_localizations.dart';

class FilteredDivesScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final String title;
  final List<Dive> Function() loader;

  const FilteredDivesScreen({
    super.key,
    required this.db,
    required this.settings,
    required this.title,
    required this.loader,
  });

  @override
  State<FilteredDivesScreen> createState() => _FilteredDivesScreenState();
}

class _FilteredDivesScreenState extends State<FilteredDivesScreen> {
  late List<Dive> _base = widget.loader();
  late Set<int> _cave = widget.db.diveIdsWithTag('cave');
  bool _searching = false;
  bool _selecting = false;
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() {
        _base = widget.loader();
        _cave = widget.db.diveIdsWithTag('cave');
      });

  List<Dive> get _shown => filterDives(_base, _query);

  void _exitSearch() {
    _ctrl.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: _exitSearch)
            : null,
        title: _searching
            ? TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: t.search, border: InputBorder.none),
                onChanged: (q) => setState(() => _query = q),
              )
            : Text(widget.title),
        actions: [
          if (_searching)
            IconButton(icon: const Icon(Icons.clear), onPressed: _exitSearch)
          else if (!_selecting)
            IconButton(
              tooltip: t.search,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
        ],
      ),
      body: DivesActionList(
        db: widget.db,
        settings: widget.settings,
        dives: _shown,
        caveIds: _cave,
        onChanged: _reload,
        onSelectionMode: (v) => setState(() => _selecting = v),
      ),
    );
  }
}

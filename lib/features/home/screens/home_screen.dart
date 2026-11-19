/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/opened_file.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/settings/screens/preview_ddb_screen.dart';
import 'package:pandive/features/home/widgets/home_drawer.dart';
import 'package:pandive/features/home/widgets/home_nav_bar.dart';
import 'package:pandive/features/home/widgets/home_tabs.dart';
import 'package:pandive/features/home/widgets/search_results_bar.dart';
import 'package:pandive/features/settings/screens/settings_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  final VoidCallback onChangeDb;
  final VoidCallback onReloadDb;
  final void Function(String path) onReplaceDb;
  const HomeScreen({
    super.key,
    required this.db,
    required this.settings,
    required this.onChangeDb,
    required this.onReloadDb,
    required this.onReplaceDb,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _dataVersion = 0; // se incrementa para forzar recarga de las pestañas
  bool _searching = false;
  String _query = '';
  bool _collapseAll = false;
  final _searchCtrl = TextEditingController();
  StreamSubscription<String>? _openSub;
  bool get _canSearch => _index <= 3; // todas menos estadísticas
  bool get _canCollapse => _index == 0 || _index == 1; // inmersiones / sitios
  @override
  void initState() {
    super.initState();
    OpenedFile.consume().then((p) {
      if (p != null && mounted) _onOpened(p);
    });
    _openSub = OpenedFile.events().listen((p) {
      if (mounted) _onOpened(p);
    });
  }
  void _onOpened(String path) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreviewDdbScreen(
          path: path,
          settings: widget.settings,
          db: widget.db,
          onReplace: widget.onReplaceDb)));
  @override
  void dispose() {
    _openSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }
  void _exitSearch() {
    _searchCtrl.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
  }
  // Cambia de sección (barra inferior o menú lateral) y recarga datos.
  void _go(int i) {
    _searchCtrl.clear();
    setState(() {
      _index = i;
      _dataVersion++;
      _searching = false;
      _query = '';
    });
  }
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final titles = [
      t.navDives, t.navSites, t.buddies, t.tags, t.equipment, t.navStats];
    return Scaffold(
      drawer: HomeDrawer(
          selectedIndex: _index, onSelected: _go, db: widget.db,
          settings: widget.settings, onReloadDb: widget.onReloadDb),
      appBar: AppBar(
        bottom: (_searching && _query.trim().isNotEmpty)
            ? SearchResultsBar(db: widget.db, index: _index, query: _query)
            : null,
        leading: _searching
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _exitSearch)
            : null,
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                    hintText: t.search, border: InputBorder.none),
                onChanged: (q) => setState(() => _query = q),
              )
            : Text(titles[_index]),
        actions: [
          if (_searching)
            IconButton(icon: const Icon(Icons.clear), onPressed: _exitSearch)
          else ...[
            if (_canSearch)
              IconButton(
                tooltip: t.search,
                icon: const Icon(Icons.search),
                onPressed: () => setState(() => _searching = true),
              ),
            if (_canCollapse)
              IconButton(
                tooltip: '',
                iconSize: 30,
                icon: Icon(_collapseAll ? Icons.unfold_more : Icons.unfold_less),
                onPressed: () => setState(() => _collapseAll = !_collapseAll),
              ),
            IconButton(
              tooltip: t.settings,
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                        settings: widget.settings,
                        onChangeDb: widget.onChangeDb,
                      ))),
            ),
          ],
        ],
      ),
      body: HomeTabs(
        db: widget.db,
        settings: widget.settings,
        index: _index,
        version: _dataVersion,
        searching: _searching,
        query: _query,
        collapseAll: _collapseAll,
      ),
      bottomNavigationBar: HomeNavBar(selectedIndex: _index, onSelected: _go),
    );
  }
}

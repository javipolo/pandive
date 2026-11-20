/// Pantalla principal con navegación por pestañas: inmersiones, sitios, stats.
library;

import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/doc_notifications.dart';
import 'package:pandive/core/services/opened_file.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/settings/screens/preview_ddb_screen.dart';
import 'package:pandive/features/home/widgets/home_drawer.dart';
import 'package:pandive/features/home/widgets/home_app_bar.dart';
import 'package:pandive/features/home/widgets/home_nav_bar.dart';
import 'package:pandive/features/home/widgets/home_tabs.dart';
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
  bool _sortByDives = false;
  final _searchCtrl = TextEditingController();
  StreamSubscription<String>? _openSub;
  bool get _canSearch => _index <= 3; // todas menos estadísticas
  bool get _canCollapse => _index == 0 || _index == 1; // inmersiones / sitios
  bool get _canSort => _index == 1 || _index == 2; // sitios / compañeros
  @override
  void initState() {
    super.initState();
    OpenedFile.consume().then((p) {
      if (p != null && mounted) _onOpened(p);
    });
    _openSub = OpenedFile.events().listen((p) {
      if (mounted) _onOpened(p);
    });
    // Reprograma las notificaciones de caducidad (solo pide permiso si procede).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) syncDocNotifications(widget.db, AppLocalizations.of(context));
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
      appBar: HomeAppBar(
        db: widget.db,
        index: _index,
        title: titles[_index],
        searching: _searching,
        query: _query,
        searchCtrl: _searchCtrl,
        collapseAll: _collapseAll,
        sortByDives: _sortByDives,
        canSearch: _canSearch,
        canCollapse: _canCollapse,
        canSort: _canSort,
        onQueryChanged: (q) => setState(() => _query = q),
        onStartSearch: () => setState(() => _searching = true),
        onExitSearch: _exitSearch,
        onToggleCollapse: () => setState(() => _collapseAll = !_collapseAll),
        onToggleSort: () => setState(() => _sortByDives = !_sortByDives),
        onSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SettingsScreen(
                settings: widget.settings, onChangeDb: widget.onChangeDb))),
      ),
      body: HomeTabs(
        db: widget.db,
        settings: widget.settings,
        index: _index,
        version: _dataVersion,
        searching: _searching,
        query: _query,
        collapseAll: _collapseAll,
        sortByDives: _sortByDives,
      ),
      bottomNavigationBar: HomeNavBar(selectedIndex: _index, onSelected: _go),
    );
  }
}

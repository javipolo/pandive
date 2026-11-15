/// Pestaña de sitios de buceo: lista agrupada por país + crear/editar.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/sites/screens/site_edit_screen.dart';
import 'package:pandive/features/sites/widgets/site_dives_screen.dart';
import 'package:pandive/features/sites/widgets/sites_grouped_list.dart';

class SitesTab extends StatefulWidget {
  final DivemateDb db;
  final String query;
  final bool collapseAll;
  const SitesTab(
      {super.key, required this.db, this.query = '', this.collapseAll = false});

  @override
  State<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends State<SitesTab> {
  late List<DiveSite> _sites = widget.db.listSites();

  void _reload() => setState(() => _sites = widget.db.listSites());

  Future<void> _new() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SiteEditScreen(db: widget.db, site: null),
    ));
    if (changed == true && mounted) _reload();
  }

  Future<void> _view(DiveSite site) async {
    final idx = _sites.indexWhere((s) => s.id == site.id);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          SiteDivesScreen(db: widget.db, sites: _sites, initialIndex: idx < 0 ? 0 : idx),
    ));
    if (mounted) _reload(); // editar/borrar dentro pudo cambiar cosas
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _new,
        child: const Icon(Icons.add),
      ),
      body: SitesGroupedList(
          sites: _sites,
          onTap: _view,
          externalQuery: widget.query,
          collapseAll: widget.collapseAll),
    );
  }
}

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

  Future<void> _edit(DiveSite? site) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SiteEditScreen(db: widget.db, site: site),
    ));
    if (changed == true && mounted) _reload();
  }

  void _showDives(DiveSite site) {
    final dives = widget.db.listDivesBySite(site.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SiteDivesScreen(
          db: widget.db, title: site.name ?? '', dives: dives),
    ));
  }

  void _delete(DiveSite site) {
    widget.db.deleteSite(site.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(null),
        child: const Icon(Icons.add),
      ),
      body: SitesGroupedList(
          sites: _sites,
          onTap: _showDives,
          onEdit: _edit,
          onDelete: _delete,
          externalQuery: widget.query,
          collapseAll: widget.collapseAll),
    );
  }
}

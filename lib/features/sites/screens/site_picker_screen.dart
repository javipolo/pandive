/// Selector de sitio de buceo: elige uno existente (devuelve DiveSite) o crea
/// uno nuevo. Cancelar devuelve null.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/sites/screens/site_edit_screen.dart';
import 'package:pandive/features/sites/widgets/sites_grouped_list.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitePickerScreen extends StatefulWidget {
  final DivemateDb db;
  const SitePickerScreen({super.key, required this.db});

  @override
  State<SitePickerScreen> createState() => _SitePickerScreenState();
}

class _SitePickerScreenState extends State<SitePickerScreen> {
  late List<DiveSite> _sites = widget.db.listSites();

  Future<void> _new() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => SiteEditScreen(db: widget.db),
    ));
    if (created == true && mounted) {
      setState(() => _sites = widget.db.listSites());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.selectSite)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: Text(t.newSite),
      ),
      body: SitesGroupedList(
        sites: _sites,
        onTap: (s) => Navigator.of(context).pop(s),
      ),
    );
  }
}

/// Pestaña de inmersiones: búsqueda + lista agrupada por mes + añadir.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dive_computer/screens/scan_screen.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'dive_detail_screen.dart';
import 'new_dive_screen.dart';

class DivesTab extends StatefulWidget {
  final DivemateDb db;
  final Settings settings;
  const DivesTab({super.key, required this.db, required this.settings});

  @override
  State<DivesTab> createState() => _DivesTabState();
}

class _DivesTabState extends State<DivesTab> {
  final _searchCtrl = TextEditingController();
  late List<Dive> _dives = widget.db.listDives();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _dives = widget.db.listDives(search: _searchCtrl.text));

  Future<void> _openDetail(int index) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiveDetailScreen(
          db: widget.db, dives: _dives, initialIndex: index),
    ));
    _reload();
  }

  Future<void> _add() async {
    final t = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: Text(t.newDiveManual),
            onTap: () => Navigator.pop(context, 'new'),
          ),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(t.diveTransfer),
            onTap: () => Navigator.pop(context, 'transfer'),
          ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    final route = choice == 'new'
        ? MaterialPageRoute(builder: (_) => NewDiveScreen(db: widget.db))
        : MaterialPageRoute(
            builder: (_) =>
                ScanScreen(db: widget.db, settings: widget.settings));
    await Navigator.of(context).push(route);
    _searchCtrl.clear();
    setState(() => _dives = widget.db.listDives());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(t.newDive),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: t.searchDives,
              leading: const Icon(Icons.search),
              onChanged: (q) =>
                  setState(() => _dives = widget.db.listDives(search: q)),
            ),
          ),
          Expanded(
            child: _dives.isEmpty
                ? Center(child: Text(t.noResults))
                : MonthGroupedDives(dives: _dives, onOpen: _openDetail),
          ),
        ],
      ),
    );
  }
}

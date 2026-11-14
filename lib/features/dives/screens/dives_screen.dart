/// Pestaña de inmersiones: lista agrupada por mes + añadir. La búsqueda llega
/// desde la barra superior (query).
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
  final String query;
  const DivesTab({
    super.key,
    required this.db,
    required this.settings,
    this.query = '',
  });

  @override
  State<DivesTab> createState() => _DivesTabState();
}

class _DivesTabState extends State<DivesTab> {
  late List<Dive> _dives = widget.db.listDives(search: widget.query);

  @override
  void didUpdateWidget(DivesTab old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _reload();
  }

  void _reload() =>
      setState(() => _dives = widget.db.listDives(search: widget.query));

  Future<void> _openDetail(int index) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DiveDetailScreen(db: widget.db, dives: _dives, initialIndex: index),
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
    _reload();
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
      body: _dives.isEmpty
          ? Center(child: Text(t.noResults))
          : MonthGroupedDives(dives: _dives, onOpen: _openDetail),
    );
  }
}

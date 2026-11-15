/// Ver un sitio de buceo: sus inmersiones, con editar/borrar arriba y swipe
/// lateral para ir al sitio anterior/siguiente.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/screens/dive_detail_screen.dart';
import 'package:pandive/features/sites/screens/site_edit_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteDivesScreen extends StatefulWidget {
  final DivemateDb db;
  final List<DiveSite> sites;
  final int initialIndex;
  const SiteDivesScreen({
    super.key,
    required this.db,
    required this.sites,
    required this.initialIndex,
  });

  @override
  State<SiteDivesScreen> createState() => _SiteDivesScreenState();
}

class _SiteDivesScreenState extends State<SiteDivesScreen> {
  late final List<DiveSite> _sites = [...widget.sites];
  late int _index = widget.initialIndex;
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  final Map<int, List<Dive>> _cache = {};

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  List<Dive> _divesFor(DiveSite s) =>
      _cache.putIfAbsent(s.id, () => widget.db.listDivesBySite(s.id));

  Future<void> _edit() async {
    final s = _sites[_index];
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SiteEditScreen(db: widget.db, site: s)));
    if (changed == true && mounted) {
      final r = widget.db.getSite(s.id);
      if (r != null) setState(() => _sites[_index] = r);
      _cache.remove(s.id);
    }
  }

  Future<void> _delete() async {
    final s = _sites[_index];
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, '${t.delete}: ${s.name ?? t.site}?',
        confirmLabel: t.delete)) {
      return;
    }
    widget.db.deleteSite(s.id);
    if (_sites.length <= 1) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sites.removeAt(_index);
      if (_index >= _sites.length) _index = _sites.length - 1;
    });
    _pc.jumpToPage(_index);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_sites[_index].name ?? t.site),
        actions: [
          IconButton(
              tooltip: t.edit, icon: const Icon(Icons.edit), onPressed: _edit),
          IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: _sites.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => _list(_sites[i]),
      ),
    );
  }

  Widget _list(DiveSite site) {
    final t = AppLocalizations.of(context);
    final dives = _divesFor(site);
    final fmt =
        DateFormat('d MMM yyyy', Localizations.localeOf(context).languageCode);
    if (dives.isEmpty) return Center(child: Text(t.noResults));
    return ListView.separated(
      itemCount: dives.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = dives[i];
        final stats = [
          if (d.maxDepth != null) '${d.maxDepth!.toStringAsFixed(1)} m',
          if (d.durationMin != null) '${d.durationMin!.round()} min',
        ].join('   ');
        return ListTile(
          leading: CircleAvatar(child: Text(d.number?.toString() ?? '—')),
          title: Text(d.date != null ? fmt.format(d.date!) : '—'),
          subtitle: stats.isEmpty ? null : Text(stats),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                DiveDetailScreen(db: widget.db, dives: dives, initialIndex: i),
          )),
        );
      },
    );
  }
}

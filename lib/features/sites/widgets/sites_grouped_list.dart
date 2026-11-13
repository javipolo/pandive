/// Lista de sitios de buceo agrupada por país, con cabeceras colapsables y
/// buscador. Reutilizada por la pestaña de sitios y por el selector.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitesGroupedList extends StatefulWidget {
  final List<DiveSite> sites;
  final void Function(DiveSite) onTap;
  const SitesGroupedList({super.key, required this.sites, required this.onTap});

  @override
  State<SitesGroupedList> createState() => _SitesGroupedListState();
}

class _SitesGroupedListState extends State<SitesGroupedList> {
  final _searchCtrl = TextEditingController();
  final _collapsed = <String>{};
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, List<DiveSite>> _grouped() {
    final q = _q.trim().toLowerCase();
    final map = <String, List<DiveSite>>{};
    for (final s in widget.sites) {
      if (q.isNotEmpty &&
          !('${s.name ?? ''} ${s.country ?? ''} ${s.region ?? ''}')
              .toLowerCase()
              .contains(q)) {
        continue;
      }
      (map[s.country ?? '—'] ??= []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase()));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final grouped = _grouped();
    final countries = grouped.keys.toList()..sort();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SearchBar(
            controller: _searchCtrl,
            hintText: t.searchSites,
            leading: const Icon(Icons.search),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: countries.isEmpty
              ? Center(child: Text(t.noSitesYet))
              : ListView(
                  children: [
                    for (final c in countries) ...[
                      _header(context, c, grouped[c]!.length),
                      if (!_collapsed.contains(c))
                        for (final s in grouped[c]!) _tile(context, t, s),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String country, int n) {
    final collapsed = _collapsed.contains(country);
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      title: Text(country,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: Icon(collapsed ? Icons.expand_more : Icons.expand_less),
      onTap: () => setState(() =>
          collapsed ? _collapsed.remove(country) : _collapsed.add(country)),
    );
  }

  Widget _tile(BuildContext context, AppLocalizations t, DiveSite s) {
    final sub = [
      if (s.region != null) s.region!,
      t.diveCountLabel(s.diveCount),
    ].join(' · ');
    final nm = (s.name ?? '').trim();
    return ListTile(
      leading: CircleAvatar(
          child: Text(nm.isEmpty ? '?' : nm.substring(0, 1).toUpperCase())),
      title: Text(s.name ?? t.site,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub),
      onTap: () => widget.onTap(s),
    );
  }
}

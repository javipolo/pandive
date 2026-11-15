/// Info detallada de un sitio de buceo: campos, editar/borrar arriba, swipe
/// lateral entre sitios, y acceso a sus inmersiones.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/dives/widgets/dive_detail_fields.dart';
import 'package:pandive/features/sites/screens/site_edit_screen.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SiteInfoScreen extends StatefulWidget {
  final DivemateDb db;
  final List<DiveSite> sites;
  final int initialIndex;
  const SiteInfoScreen(
      {super.key,
      required this.db,
      required this.sites,
      required this.initialIndex});

  @override
  State<SiteInfoScreen> createState() => _SiteInfoScreenState();
}

class _SiteInfoScreenState extends State<SiteInfoScreen> {
  late final List<DiveSite> _sites = [...widget.sites];
  late int _index = widget.initialIndex;
  late final PageController _pc = PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final s = _sites[_index];
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SiteEditScreen(db: widget.db, site: s)));
    if (changed == true && mounted) {
      final r = widget.db.getSite(s.id);
      if (r != null) setState(() => _sites[_index] = r);
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
        itemBuilder: (context, i) => _info(_sites[i], t),
      ),
    );
  }

  Widget _info(DiveSite s, AppLocalizations t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        twoCol(LabeledValue(t.fieldSite, s.name),
            LabeledValue(t.fieldCountry, s.country)),
        sectionLine(),
        twoCol(LabeledValue(t.fieldStretchOfWater, s.waterName),
            LabeledValue(t.fieldRegion, s.region)),
      ],
    );
  }
}

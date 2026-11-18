/// Previsualiza un .ddb en solo lectura (lista de inmersiones) sin tocar la DB
/// activa. Para cuando llega un .ddb por "abrir con" / compartir.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/dives/widgets/month_grouped_dives.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PreviewDdbScreen extends StatefulWidget {
  final String path;
  final Settings settings;
  const PreviewDdbScreen({super.key, required this.path, required this.settings});

  @override
  State<PreviewDdbScreen> createState() => _PreviewDdbScreenState();
}

class _PreviewDdbScreenState extends State<PreviewDdbScreen> {
  DivemateDb? _db;
  List<Dive> _dives = const [];
  Set<int> _cave = const {};

  @override
  void initState() {
    super.initState();
    try {
      final db = DivemateDb.open(widget.path, readOnly: true);
      if (db.looksValid) {
        _db = db;
        _dives = db.listDives();
        _cave = db.diveIdsWithTag('cave');
      } else {
        db.close();
      }
    } catch (_) {/* fichero inválido */}
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.previewDdb)),
      body: _db == null
          ? Center(child: Text(t.invalidDb))
          : _dives.isEmpty
              ? Center(child: Text(t.noResults))
              : MonthGroupedDives(
                  dives: _dives,
                  settings: widget.settings,
                  caveIds: _cave,
                  onOpen: (_) {},
                ),
    );
  }
}

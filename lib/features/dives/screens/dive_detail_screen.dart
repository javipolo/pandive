/// Detalle de inmersión con navegación por deslizamiento (anterior/siguiente).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/dive_detail_body.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'edit_dive_screen.dart';

class DiveDetailScreen extends StatefulWidget {
  final DivemateDb db;
  final List<Dive> dives;
  final int initialIndex;

  const DiveDetailScreen({
    super.key,
    required this.db,
    required this.dives,
    required this.initialIndex,
  });

  @override
  State<DiveDetailScreen> createState() => _DiveDetailScreenState();
}

class _DiveDetailScreenState extends State<DiveDetailScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late final List<Dive> _dives = [...widget.dives];
  late int _index = widget.initialIndex;

  DivemateDb get db => widget.db;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final dive = _dives[_index];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditDiveScreen(db: db, dive: dive)),
    );
    if (changed == true) {
      final reloaded = db.getDive(dive.id);
      if (reloaded != null && mounted) {
        setState(() => _dives[_index] = reloaded);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dive = _dives[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text(dive.number != null ? t.diveNumber(dive.number!) : t.dive),
        actions: [
          IconButton(
            tooltip: t.edit,
            icon: const Icon(Icons.edit),
            onPressed: _edit,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _dives.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => DiveDetailBody(db: db, dive: _dives[i]),
      ),
    );
  }
}

/// Detalle de inmersión con navegación por deslizamiento (anterior/siguiente),
/// manteniendo la posición de scroll vertical al cambiar de buceo.
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
  late final PageController _pageCtrl =
      PageController(initialPage: widget.initialIndex);
  late final List<Dive> _dives = [...widget.dives];
  late int _index = widget.initialIndex;
  final Map<int, ScrollController> _ctrls = {};
  double _offset = 0; // scroll vertical compartido entre buceos

  DivemateDb get db => widget.db;

  ScrollController _bodyController(int i) => _ctrls.putIfAbsent(i, () {
        final c = ScrollController(initialScrollOffset: _offset);
        c.addListener(() {
          if (c.hasClients) _offset = c.offset;
        });
        return c;
      });

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _ctrls[i];
      if (c != null && c.hasClients) {
        c.jumpTo(_offset.clamp(0, c.position.maxScrollExtent));
      }
    });
  }

  Future<void> _edit() async {
    final dive = _dives[_index];
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditDiveScreen(db: db, dive: dive)),
    );
    if (changed == true) {
      final reloaded = db.getDive(dive.id);
      if (reloaded != null && mounted) setState(() => _dives[_index] = reloaded);
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
              tooltip: t.edit, icon: const Icon(Icons.edit), onPressed: _edit),
        ],
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        physics: const _CalmPagePhysics(),
        itemCount: _dives.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, i) => DiveDetailBody(
          db: db,
          dive: _dives[i],
          controller: _bodyController(i),
        ),
      ),
    );
  }
}

/// Exige más desplazamiento horizontal antes de pasar de página, para que el
/// scroll vertical no cambie de buceo sin querer.
class _CalmPagePhysics extends PageScrollPhysics {
  const _CalmPagePhysics({super.parent});

  @override
  _CalmPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _CalmPagePhysics(parent: buildParent(ancestor));

  @override
  double get dragStartDistanceMotionThreshold => 24.0;
}

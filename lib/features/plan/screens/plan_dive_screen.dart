/// Planificador de gas interactivo: precarga las medias (RMV, prof, tiempo) de
/// una selección y deja recalcular al cambiar cualquier valor o la configuración
/// de botellas. Lógica en `core/gas_plan.dart`.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/plan/widgets/plan_inputs.dart';
import 'package:pandive/features/plan/widgets/plan_results.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanDiveScreen extends StatefulWidget {
  final DivemateDb db;
  final double? rmv;
  final double? avgDepth;
  final double? avgTime;

  const PlanDiveScreen({
    super.key,
    required this.db,
    this.rmv,
    this.avgDepth,
    this.avgTime,
  });

  @override
  State<PlanDiveScreen> createState() => _PlanDiveScreenState();
}

class _PlanDiveScreenState extends State<PlanDiveScreen> {
  late final rmv = TextEditingController(text: _fmt(widget.rmv, 1));
  late final depth = TextEditingController(text: _fmt(widget.avgDepth, 1));
  late final time = TextEditingController(text: _fmt(widget.avgTime, 0));
  final litres = TextEditingController();
  final start = TextEditingController(text: '200');
  final reserve = TextEditingController(text: '35');
  String? typeName;

  @override
  void initState() {
    super.initState();
    for (final c in [rmv, depth, time, litres, start, reserve]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [rmv, depth, time, litres, start, reserve]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double? v, int d) =>
      v == null ? '' : v.toStringAsFixed(d);
  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickType() async {
    final chosen = await showDiveTypePicker(context, widget.db.listDiveTypes());
    if (chosen == null) return;
    final total = chosen.tanks
        .fold<double>(0, (sum, c) => sum + (c.size ?? 0));
    setState(() {
      typeName = chosen.name;
      if (total > 0) litres.text = _fmt(total, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final plan = computeGasPlan(
      rmv: _d(rmv),
      avgDepthM: _d(depth),
      timeMin: _d(time),
      totalLitres: _d(litres),
      startBar: _d(start),
      reserveBar: _d(reserve),
    );
    return Scaffold(
      appBar: AppBar(title: Text(t.planTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PlanInputs(
            rmv: rmv,
            depth: depth,
            time: time,
            litres: litres,
            start: start,
            reserve: reserve,
            typeName: typeName,
            onPickType: _pickType,
            onClearType: () => setState(() => typeName = null),
          ),
          const SizedBox(height: 8),
          PlanResults(plan: plan),
        ],
      ),
    );
  }
}

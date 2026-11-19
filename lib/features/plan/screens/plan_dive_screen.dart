/// Planificador de gas interactivo: precarga las medias (RMV, prof, tiempo) de
/// una selección y recalcula al cambiar cualquier valor o la lista de botellas.
/// Lógica en `core/gas_plan.dart`.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/gas_plan.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/plan/widgets/plan_cylinders_field.dart';
import 'package:pandive/features/plan/widgets/plan_inputs.dart';
import 'package:pandive/features/plan/widgets/plan_results.dart';
import 'package:pandive/l10n/app_localizations.dart';

class PlanDiveScreen extends StatefulWidget {
  final DivemateDb db;
  final double? rmv;
  final double? avgDepth;
  final double? avgTime;
  final ReserveRule initialRule;

  const PlanDiveScreen({
    super.key,
    required this.db,
    this.rmv,
    this.avgDepth,
    this.avgTime,
    this.initialRule = ReserveRule.bar35,
  });

  @override
  State<PlanDiveScreen> createState() => _PlanDiveScreenState();
}

class _PlanDiveScreenState extends State<PlanDiveScreen> {
  late final rmv = _ctrl(_fmt(widget.rmv, 1));
  late final depth = _ctrl(_fmt(widget.avgDepth, 1));
  late final time = _ctrl(_fmt(widget.avgTime, 0));
  final start = TextEditingController(text: '200');
  final custom = TextEditingController(text: '35');
  late ReserveRule rule = widget.initialRule;
  final List<PlanCyl> _cyls = [];
  String? typeName;

  TextEditingController _ctrl(String text) =>
      TextEditingController(text: text)..addListener(_rebuild);
  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    for (final c in [start, custom]) {
      c.addListener(_rebuild);
    }
    _cyls.add(_newCyl());
  }

  PlanCyl _newCyl({String text = '', bool reserve = true}) {
    final c = PlanCyl(text: text, reserve: reserve);
    c.litres.addListener(_rebuild);
    return c;
  }

  @override
  void dispose() {
    for (final c in [rmv, depth, time, start, custom]) {
      c.dispose();
    }
    for (final c in _cyls) {
      c.dispose();
    }
    super.dispose();
  }

  static String _fmt(double? v, int d) => v == null ? '' : v.toStringAsFixed(d);
  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _pickType() async {
    final chosen = await showDiveTypePicker(context, widget.db.listDiveTypes());
    if (chosen == null) return;
    final tanks = chosen.tanks.where((t) => (t.size ?? 0) > 0).toList();
    if (tanks.isEmpty) return;
    setState(() {
      for (final c in _cyls) {
        c.dispose();
      }
      _cyls
        ..clear()
        ..addAll(tanks.map((t) => _newCyl(text: _fmt(t.size, 1))));
      typeName = chosen.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final plan = computeGasPlan(
      rmv: _d(rmv),
      avgDepthM: _d(depth),
      timeMin: _d(time),
      cylinders: [
        for (final c in _cyls)
          PlanCylinder(_d(c.litres) ?? 0, keepsReserve: c.reserve),
      ],
      startBar: _d(start),
      rule: rule,
      customBar: _d(custom),
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
            start: start,
            custom: custom,
            typeName: typeName,
            onPickType: _pickType,
            onClearType: () => setState(() => typeName = null),
            rule: rule,
            onRuleChanged: (r) => setState(() => rule = r),
            cylinders: _cyls,
            onToggleCyl: (c) => setState(() => c.reserve = !c.reserve),
            onRemoveCyl: (c) => setState(() {
              _cyls.remove(c);
              c.dispose();
            }),
            onAddCyl: () => setState(() => _cyls.add(_newCyl())),
          ),
          const SizedBox(height: 8),
          PlanResults(plan: plan),
        ],
      ),
    );
  }
}

/// Detalle de una inmersión: datos, perfil y botellas.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/core/widgets/stat_card.dart';
import 'package:pandive/features/dives/widgets/cylinder_tile.dart';
import 'edit_dive_screen.dart';

class DiveDetailScreen extends StatefulWidget {
  final DivemateDb db;
  final Dive dive;

  const DiveDetailScreen({super.key, required this.db, required this.dive});

  @override
  State<DiveDetailScreen> createState() => _DiveDetailScreenState();
}

class _DiveDetailScreenState extends State<DiveDetailScreen> {
  late Dive dive = widget.dive;
  DivemateDb get db => widget.db;

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditDiveScreen(db: db, dive: dive)),
    );
    if (changed == true) {
      final reloaded = db.getDive(dive.id);
      if (reloaded != null && mounted) setState(() => dive = reloaded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = db.diveProfile(dive.id);
    final cylinders = db.cylinders(dive.id);
    final dateFmt = DateFormat('EEEE d MMMM yyyy, HH:mm', 'es');

    return Scaffold(
      appBar: AppBar(
        title: Text(dive.number != null ? 'Inmersión #${dive.number}' : 'Inmersión'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: _edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (dive.place != null)
            Text(dive.place!, style: Theme.of(context).textTheme.headlineSmall),
          if (dive.country != null)
            Text(dive.country!, style: Theme.of(context).textTheme.titleMedium),
          if (dive.date != null) ...[
            const SizedBox(height: 4),
            Text(dateFmt.format(dive.date!),
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: _statCards()),
          if (profile != null && !profile.isEmpty) ...[
            const SizedBox(height: 24),
            Text('Perfil', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SizedBox(height: 260, child: ProfileChart(profile: profile)),
            if (profile.hasTemp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Línea roja: temperatura (relativa)',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
          if (cylinders.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Botellas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...cylinders.map((c) => CylinderTile(cylinder: c)),
          ],
          if (dive.comments != null) ...[
            const SizedBox(height: 24),
            Text('Notas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(dive.comments!, style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<Widget> _statCards() {
    final items = <(String, String)>[
      if (dive.maxDepth != null) ('Prof. máx', '${dive.maxDepth!.toStringAsFixed(1)} m'),
      if (dive.avgDepth != null) ('Prof. media', '${dive.avgDepth!.toStringAsFixed(1)} m'),
      if (dive.durationMin != null) ('Duración', '${dive.durationMin!.round()} min'),
      if (dive.waterTemp != null) ('Temp. agua', '${dive.waterTemp!.toStringAsFixed(0)} °C'),
      if (dive.airTemp != null) ('Temp. aire', '${dive.airTemp!.toStringAsFixed(0)} °C'),
      if (dive.surfaceInterval != null) ('Interv. sup.', dive.surfaceInterval!),
      if (dive.weight != null) ('Lastre', '${dive.weight!.toStringAsFixed(1)} kg'),
      if (dive.rating != null && dive.rating! > 0) ('Valoración', '★' * dive.rating!),
      if (dive.computer != null) ('Ordenador', dive.computer!),
      if (dive.buddy != null) ('Compañero', dive.buddy!),
      if (dive.diveMaster != null) ('Guía', dive.diveMaster!),
      if (dive.diveType != null) ('Tipo', dive.diveType!),
    ];
    return [for (final it in items) StatCard(label: it.$1, value: it.$2)];
  }
}

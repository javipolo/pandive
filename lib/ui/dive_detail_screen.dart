/// Detalle de una inmersión: datos, perfil y botellas.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/divemate_db.dart';
import '../models.dart';
import 'edit_dive_screen.dart';
import 'profile_chart.dart';

class DiveDetailScreen extends StatefulWidget {
  final DivemateDb db;
  final Dive dive;

  const DiveDetailScreen({super.key, required this.db, required this.dive});

  @override
  State<DiveDetailScreen> createState() => _DiveDetailScreenState();
}

class _DiveDetailScreenState extends State<DiveDetailScreen> {
  late Dive dive;
  DivemateDb get db => widget.db;

  @override
  void initState() {
    super.initState();
    dive = widget.dive;
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditDiveScreen(db: db, dive: dive),
      ),
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
        title: Text(dive.number != null
            ? 'Inmersión #${dive.number}'
            : 'Inmersión'),
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
            Text(dive.place!,
                style: Theme.of(context).textTheme.headlineSmall),
          if (dive.country != null)
            Text(dive.country!,
                style: Theme.of(context).textTheme.titleMedium),
          if (dive.date != null) ...[
            const SizedBox(height: 4),
            Text(dateFmt.format(dive.date!),
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),

          _statsGrid(context),

          if (profile != null && !profile.isEmpty) ...[
            const SizedBox(height: 24),
            Text('Perfil', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SizedBox(height: 260, child: ProfileChart(profile: profile)),
            if (profile.hasTemp)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Línea roja: temperatura (relativa)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],

          if (cylinders.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Botellas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...cylinders.map((c) => _cylinderTile(context, c)),
          ],

          if (dive.comments != null) ...[
            const SizedBox(height: 24),
            Text('Notas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(dive.comments!,
                style: Theme.of(context).textTheme.bodyLarge),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    final items = <(String, String)>[
      if (dive.maxDepth != null)
        ('Prof. máx', '${dive.maxDepth!.toStringAsFixed(1)} m'),
      if (dive.avgDepth != null)
        ('Prof. media', '${dive.avgDepth!.toStringAsFixed(1)} m'),
      if (dive.durationMin != null)
        ('Duración', '${dive.durationMin!.round()} min'),
      if (dive.waterTemp != null)
        ('Temp. agua', '${dive.waterTemp!.toStringAsFixed(0)} °C'),
      if (dive.airTemp != null)
        ('Temp. aire', '${dive.airTemp!.toStringAsFixed(0)} °C'),
      if (dive.surfaceInterval != null)
        ('Interv. sup.', dive.surfaceInterval!),
      if (dive.weight != null) ('Lastre', '${dive.weight!.toStringAsFixed(1)} kg'),
      if (dive.rating != null && dive.rating! > 0)
        ('Valoración', '★' * dive.rating!),
      if (dive.computer != null) ('Ordenador', dive.computer!),
      if (dive.buddy != null) ('Compañero', dive.buddy!),
      if (dive.diveMaster != null) ('Guía', dive.diveMaster!),
      if (dive.diveType != null) ('Tipo', dive.diveType!),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map((it) => _StatCard(label: it.$1, value: it.$2))
          .toList(),
    );
  }

  Widget _cylinderTile(BuildContext context, Cylinder c) {
    final parts = <String>[
      c.gasLabel,
      if (c.size != null) '${c.size!.toStringAsFixed(0)} L',
      if (c.pressureStart != null && c.pressureEnd != null)
        '${c.pressureStart!.round()} → ${c.pressureEnd!.round()} bar',
    ];
    return Card(
      child: ListTile(
        leading: const Icon(Icons.propane_tank_outlined),
        title: Text(c.name ?? parts.first),
        subtitle: Text(parts.join('   ')),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

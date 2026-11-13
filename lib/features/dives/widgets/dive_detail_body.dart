/// Cuerpo del detalle de una inmersión (datos, perfil, botellas, notas).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/sac.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/core/widgets/stat_card.dart';
import 'package:pandive/features/dives/screens/profile_fullscreen_screen.dart';
import 'package:pandive/features/dives/widgets/cylinder_tile.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DiveDetailBody extends StatelessWidget {
  final DivemateDb db;
  final Dive dive;
  const DiveDetailBody({super.key, required this.db, required this.dive});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final profile = db.diveProfile(dive.id);
    final cylinders = db.cylinders(dive.id);
    final tags = db.tagsForDive(dive.id);
    final dateFmt = DateFormat(
        'EEEE d MMMM yyyy, HH:mm', Localizations.localeOf(context).languageCode);

    return ListView(
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _statCards(
            context,
            t,
            computeSac(cylinders,
                divetimeMin: dive.durationMin, avgDepthM: dive.avgDepth),
          ),
        ),
        if (profile != null && !profile.isEmpty) ...[
          const SizedBox(height: 24),
          Text(t.profile, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProfileFullscreenScreen(
                profile: profile,
                title: dive.place ?? t.dive,
              ),
            )),
            child: SizedBox(height: 260, child: ProfileChart(profile: profile)),
          ),
        ],
        if (cylinders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.cylinders, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...cylinders.map((c) => CylinderTile(cylinder: c)),
        ],
        if (dive.comments != null) ...[
          const SizedBox(height: 24),
          Text(t.notes, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(dive.comments!, style: Theme.of(context).textTheme.bodyLarge),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.tags, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final tag in tags) Chip(label: Text('#${tag.name}'))],
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  List<Widget> _statCards(BuildContext context, AppLocalizations t, double? sac) {
    final items = <(String, String)>[
      if (dive.maxDepth != null) (t.statMaxDepth, '${dive.maxDepth!.toStringAsFixed(1)} m'),
      if (sac != null) (t.sacLabel, '${sac.toStringAsFixed(1)} l/min'),
      if (dive.avgDepth != null) (t.statAvgDepth, '${dive.avgDepth!.toStringAsFixed(1)} m'),
      if (dive.durationMin != null) (t.statDuration, '${dive.durationMin!.round()} min'),
      if (dive.waterTemp != null) (t.statWaterTemp, '${dive.waterTemp!.toStringAsFixed(0)} °C'),
      if (dive.airTemp != null) (t.statAirTemp, '${dive.airTemp!.toStringAsFixed(0)} °C'),
      if (dive.surfaceInterval != null) (t.statSurfaceInt, dive.surfaceInterval!),
      if (dive.weight != null) (t.statWeight, '${dive.weight!.toStringAsFixed(1)} kg'),
      if (dive.rating != null && dive.rating! > 0) (t.statRating, '★' * dive.rating!),
      if (dive.computer != null) (t.statComputer, dive.computer!),
      if (dive.buddy != null) (t.statBuddy, dive.buddy!),
    ];
    return [for (final it in items) StatCard(label: it.$1, value: it.$2)];
  }
}

/// Cuerpo del detalle de una inmersión: secciones compactas (nº/fecha, sitio,
/// compañero, perfil + métricas, gases, deco, botellas, ordenador).
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/sac.dart';
import 'package:pandive/features/dives/widgets/cylinder_tile.dart';
import 'package:pandive/features/dives/widgets/dive_detail_fields.dart';
import 'package:pandive/features/dives/widgets/profile_section.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DiveDetailBody extends StatelessWidget {
  final DivemateDb db;
  final Dive dive;
  final ScrollController? controller;
  const DiveDetailBody(
      {super.key, required this.db, required this.dive, this.controller});

  String? _m(double? v) => v == null ? null : '${v.toStringAsFixed(1)} m';
  String? _c(double? v) => v == null ? null : '${v.toStringAsFixed(1)} °C';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final site = dive.placeId != null ? db.getSite(dive.placeId!) : null;
    final profile = db.diveProfile(dive.id);
    final cyls = db.cylinders(dive.id);
    final buddies = db.diveBuddies(dive.id).map((b) => b.name).join(', ');
    final tags = db.effectiveTagsForDive(dive.id);

    final avg = dive.avgDepth ?? _avg(profile?.depths.where((d) => d > 0));
    final temps = profile?.temps.whereType<double>().toList() ?? const <double>[];
    final minTemp = dive.waterTemp ??
        (temps.isEmpty ? null : temps.reduce((a, b) => a < b ? a : b));
    final avgTemp = db.diveAvgTemp(dive.id) ?? _avg(temps);

    final fO2 = (cyls.isNotEmpty && cyls.first.o2 != null
            ? cyls.first.o2!
            : (dive.o2 ?? 21)) /
        100;
    final fHe = (cyls.isNotEmpty ? (cyls.first.he ?? 0) : 0) / 100;
    final ata = dive.maxDepth != null ? dive.maxDepth! / 10 + 1 : null;
    final rmv = computeSac(cyls, divetimeMin: dive.durationMin, avgDepthM: avg);
    final sac =
        computeSacBar(cyls, divetimeMin: dive.durationMin, avgDepthM: avg);

    String? f1(double? v, String u) => v == null ? null : '${v.toStringAsFixed(1)} $u';

    final isDeco = dive.deco == 1 || (profile?.hasDeco ?? false);
    int maxTts = 0;
    double maxCeiling = 0;
    int ceilSamples = 0;
    if (isDeco && profile != null) {
      for (final c in profile.ceiling) {
        if (c > 0) {
          ceilSamples++;
          if (c > maxCeiling) maxCeiling = c;
        }
      }
      for (final x in profile.tts) {
        if (x != null && x > maxTts) maxTts = x;
      }
    }
    final maxCeilMin =
        ceilSamples > 0 ? ceilSamples * (profile!.intervalSeconds) / 60.0 : null;

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        twoCol(
          LabeledValue(t.fieldNumber, dive.number?.toString()),
          LabeledValue(t.fieldDate,
              dive.date == null ? null : DateFormat('dd/MM/yyyy HH:mm', locale).format(dive.date!)),
          leftFlex: 1,
          rightFlex: 2,
        ),
        sectionLine(),
        LabeledValue(t.fieldSite, dive.place ?? site?.name),
        twoCol(LabeledValue(t.fieldCountry, dive.country ?? site?.country),
            LabeledValue(t.fieldRegion, site?.region)),
        sectionLine(),
        LabeledValue(t.fieldBuddy, buddies),
        sectionLine(),
        if (profile != null && !profile.isEmpty)
          ProfileSection(db: db, dive: dive, profile: profile),
        twoCol(
            LabeledValue(t.diveType, dive.diveType),
            LabeledValue(t.statDuration,
                dive.durationMin == null ? null : '${dive.durationMin!.round()} min')),
        twoCol(LabeledValue(t.statAvgDepth, _m(avg)),
            LabeledValue(t.statMaxDepth, _m(dive.maxDepth))),
        twoCol(LabeledValue(t.statTempAvg, _c(avgTemp)),
            LabeledValue(t.statTempMin, _c(minTemp))),
        sectionLine(),
        twoCol(LabeledValue(t.sacBarLabel, f1(sac, 'bar/min')),
            LabeledValue(t.rmvLabel, f1(rmv, 'l/min'))),
        twoCol(
            LabeledValue(t.ppo2Max, ata == null ? null : ff(fO2 * ata)),
            LabeledValue(
                t.ppheMax, (ata == null || fHe <= 0) ? null : ff(fHe * ata))),
        if (dive.weight != null && dive.weight! > 0) ...[
          sectionLine(),
          LabeledValue(
              t.statWeight, '${dive.weight!.toStringAsFixed(1)} kg'),
        ],
        if (isDeco) ...[
          sectionLine(),
          twoCol(
              LabeledValue(t.decoLabel, t.decoYes),
              LabeledValue(
                  t.statsMaxTts, maxTts > 0 ? '$maxTts min' : null)),
          twoCol(
              LabeledValue(t.statsMaxCeiling,
                  maxCeiling > 0 ? '${maxCeiling.toStringAsFixed(1)} m' : null),
              LabeledValue(t.statsMaxCeilingTime, f1(maxCeilMin, 'min'))),
        ],
        sectionLine(),
        Text(t.tanks, style: Theme.of(context).textTheme.titleMedium),
        ...cyls.map((c) => CylinderTile(cylinder: c)),
        sectionLine(),
        LabeledValue(t.statComputer, dive.computer),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final tag in tags) Chip(label: Text(tag.name)),
          ]),
        ],
        if (dive.comments != null) ...[
          sectionLine(),
          LabeledValue(t.notes, dive.comments),
        ],
      ],
    );
  }

  String ff(double v) => v.toStringAsFixed(2);
  double? _avg(Iterable<double>? xs) {
    final l = xs?.toList() ?? const [];
    return l.isEmpty ? null : l.reduce((a, b) => a + b) / l.length;
  }
}

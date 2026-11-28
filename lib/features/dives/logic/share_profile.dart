/// Generates a PNG image of the dive profile (title, chart and a footer with
/// duration, minimum temperature, depths and, if there was deco, max TTS and
/// ceiling; the same image on all platforms) and
/// shares it with another app or, on desktop (Linux), copies it to the clipboard.
/// Renders the card off-screen and captures it.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/image_clipboard.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/core/platform.dart';
import 'package:pandive/features/dives/logic/dive_facts.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Whether the share/copy button is shown (web: not yet, no files).
bool get canShareProfile => !isWeb;

/// Button icon and text: copy on desktop, share on mobile.
IconData get shareProfileIcon => canCopyImages ? Icons.copy : Icons.share;
String shareProfileTooltip(AppLocalizations t) =>
    canCopyImages ? t.copyChart : t.share;

/// Shares the chart (mobile) or copies it to the clipboard (desktop).
Future<void> shareProfileImage(
  BuildContext context, {
  required DiveProfile profile,
  required String title,
  required DiveFacts facts,
  List<GasChange> gasChanges = const [],
}) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final png = await _renderProfilePng(context,
      profile: profile, title: title, facts: facts, gasChanges: gasChanges);
  if (png == null) return;
  if (canCopyImages) {
    final ok = await copyPngToClipboard(png);
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? t.chartCopied : t.chartCopyFailed)));
    return;
  }
  final dir = await getTemporaryDirectory();
  final safe = title.replaceAll(RegExp(r'[^\w-]+'), '_');
  final file = File('${dir.path}/pandive_$safe.png');
  await file.writeAsBytes(png);
  await shareOrSaveFile(file, text: title);
}

// Paints the card (title + chart) off-screen and captures it as PNG.
Future<Uint8List?> _renderProfilePng(
  BuildContext context, {
  required DiveProfile profile,
  required String title,
  required DiveFacts facts,
  required List<GasChange> gasChanges,
}) async {
  final overlay = Overlay.of(context);
  final theme = Theme.of(context);
  final key = GlobalKey();
  // Place the card just below the viewport (invisible) with a small
  // offset: a huge offset corrupts the layer on capture ("tiled" image).
  final below = MediaQuery.sizeOf(context).height + 20;
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 0,
      top: below,
      child: Material(
        child: RepaintBoundary(
          key: key,
          child: Theme(
            data: theme,
            child: ProfileShareCard(
                profile: profile,
                title: title,
                facts: facts,
                gasChanges: gasChanges),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Wait for real frames so layout + the chart's entry animation finish
    // (debugNeedsPaint won't do: in release it's always false).
    for (var i = 0; i < 10; i++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return null;
    final image = await ro.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// Card exported as an image (title, chart and data footer).
class ProfileShareCard extends StatelessWidget {
  final DiveProfile profile;
  final String title;
  final DiveFacts facts;
  final List<GasChange> gasChanges;
  const ProfileShareCard(
      {super.key,
      required this.profile,
      required this.title,
      required this.facts,
      required this.gasChanges});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    String? one(double? v, String unit) =>
        v == null ? null : '${v.toStringAsFixed(1)} $unit';
    final rows = <_FactRow>[
      (
        (t.statDuration, facts.durationMin == null
            ? null
            : '${facts.durationMin!.round()} min'),
        (t.statTempMin, one(facts.minTemp, '°C')),
      ),
      (
        (t.statMaxDepth, one(facts.maxDepth, 'm')),
        (t.statAvgDepth, one(facts.avgDepth, 'm')),
      ),
      if (facts.isDeco)
        (
          (t.statsMaxTts, facts.maxTts == null ? null : '${facts.maxTts} min'),
          (t.statsMaxCeiling, one(facts.maxCeiling, 'm')),
        ),
    ];
    return Container(
      width: 1100,
      height: 680 + 24 + rows.length * 40,
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Text('PanDive',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: cs.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ProfileChart(profile: profile, gasChanges: gasChanges),
          ),
          Divider(height: 24, color: cs.outlineVariant),
          _FactsTable(rows),
        ],
      ),
    );
  }
}

typedef _FactRow = ((String, String?), (String, String?));

// Tabulated image footer: label | value | label | value. The label
// columns take the width of the longest one, so values stay aligned
// whatever the language.
class _FactsTable extends StatelessWidget {
  final List<_FactRow> rows;
  const _FactsTable(this.rows);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final labelStyle = tt.titleMedium?.copyWith(color: cs.onSurfaceVariant);
    final valueStyle = tt.titleLarge?.copyWith(fontWeight: FontWeight.w600);
    Widget cell(String text, TextStyle? style, {double left = 0}) => Container(
          height: 40,
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(left: left),
          child: Text(text, style: style, maxLines: 1),
        );
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
      },
      children: [
        for (final ((l1, v1), (l2, v2)) in rows)
          TableRow(children: [
            cell(l1, labelStyle),
            cell(v1 ?? '—', valueStyle, left: 16),
            cell(l2, labelStyle),
            cell(v2 ?? '—', valueStyle, left: 16),
          ]),
      ],
    );
  }
}

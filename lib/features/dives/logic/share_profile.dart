/// Genera una imagen PNG del perfil de inmersión (con el nombre del sitio) y la
/// comparte con otra app. Renderiza la tarjeta fuera de pantalla y la captura.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';

Future<void> shareProfileImage(
  BuildContext context, {
  required DiveProfile profile,
  required String title,
  List<GasChange> gasChanges = const [],
}) async {
  final overlay = Overlay.of(context);
  final theme = Theme.of(context);
  final key = GlobalKey();
  // Colocar la tarjeta justo debajo del viewport (invisible) con un offset
  // pequeño: un offset enorme corrompe el layer al capturar (imagen "tileada").
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
            child: _ProfileCard(
                profile: profile, title: title, gasChanges: gasChanges),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Esperar frames reales para que termine el layout + la animación de entrada
    // de la gráfica (no vale debugNeedsPaint: en release siempre es false).
    for (var i = 0; i < 10; i++) {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return;
    final image = await ro.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final dir = await getTemporaryDirectory();
    final safe = title.replaceAll(RegExp(r'[^\w-]+'), '_');
    final file = File('${dir.path}/pandive_$safe.png');
    await file.writeAsBytes(data.buffer.asUint8List());
    await SharePlus.instance
        .share(ShareParams(files: [XFile(file.path)], text: title));
  } finally {
    entry.remove();
  }
}

class _ProfileCard extends StatelessWidget {
  final DiveProfile profile;
  final String title;
  final List<GasChange> gasChanges;
  const _ProfileCard(
      {required this.profile, required this.title, required this.gasChanges});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1100,
      height: 680,
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
              Text('Pandive',
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
        ],
      ),
    );
  }
}

/// Exporta un .ddb mínimo con solo los buceos seleccionados (fecha/hora + sitio).
/// Pensado para que otro buceador use "Rellenar desde el logbook de un compañero".
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/text_prompt_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Pide un nombre y crea un .ddb temporal con [dives] (solo fecha/hora y lugar)
/// y lo comparte. El fichero se llama `name - PanDive.ddb`.
Future<void> exportSelectionDdb(
    BuildContext context, DivemateDb source, List<Dive> dives) async {
  final name =
      await showTextPrompt(context, title: AppLocalizations.of(context).exportName);
  if (name == null) return;
  final dir = await getTemporaryDirectory();
  final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  final base = safe.isEmpty ? 'PanDive' : '$safe - PanDive';
  final f = File('${dir.path}/$base.ddb');
  if (f.existsSync()) f.deleteSync();
  final out = DivemateDb.createEmpty(f.path);
  try {
    for (final d in dives) {
      final dt = d.date;
      if (dt == null) continue;
      final site = d.placeId != null ? source.getSite(d.placeId!) : null;
      final name = site?.name ?? d.place;
      int? placeId;
      if (name != null && name.trim().isNotEmpty) {
        placeId = out.findOrCreateSite(name,
            country: site?.country ?? d.country,
            lat: site?.lat,
            lon: site?.lon);
      }
      out.createDive(
        dateTime: dt,
        number: d.number,
        place: name,
        country: site?.country ?? d.country,
        placeId: placeId,
      );
    }
  } finally {
    out.close();
  }
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}

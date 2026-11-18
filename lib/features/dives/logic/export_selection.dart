/// Exporta un .ddb mínimo con solo los buceos seleccionados (fecha/hora + sitio).
/// Pensado para que otro buceador use "Rellenar desde el logbook de un compañero".
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';

/// Crea un .ddb temporal con [dives] (solo fecha/hora y lugar) y lo comparte.
Future<void> exportSelectionDdb(DivemateDb source, List<Dive> dives) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/pandive-shared.ddb');
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

/// Export selected documents to a PDF and share it. Several per
/// page (flowing with MultiPage), without enlarging the image: its size is capped at
/// a maximum resolution so they look alike but sharp.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:pandive/core/services/share_file.dart';
import 'package:pandive/core/widgets/progress_dialog.dart';
import 'package:pandive/l10n/app_localizations.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/storage/documents_storage.dart';

/// Generates the PDF of [docs] with an "Exporting…" notice and shares it (or
/// saves it, on Linux).
Future<void> exportDocumentsPdf(BuildContext context, List<DiveDoc> docs) async {
  if (docs.isEmpty) return;
  final out = await withProgress(
      context, AppLocalizations.of(context).exporting, () => _buildPdf(docs));
  if (out != null) await shareOrSaveFile(out);
}

// null if no document has an image.
Future<File?> _buildPdf(List<DiveDoc> docs) async {
  const margin = 24.0;
  // Physical cap ~ ID card size (8.5 cm ≈ 240 pt) per side; never enlarged.
  const cardMax = 240.0;

  final items = <pw.Widget>[];
  for (final d in docs) {
    final file = await docFile(d.fileName);
    if (!await file.exists()) continue;
    final image = pw.MemoryImage(await file.readAsBytes());
    final size = _fit((image.width ?? 1).toDouble(),
        (image.height ?? 1).toDouble(), cardMax, cardMax);
    items.add(pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(d.title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        if (d.notes != null && d.notes!.isNotEmpty)
          pw.Text(d.notes!, style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Image(image, width: size.x, height: size.y),
        pw.SizedBox(height: 20),
      ],
    ));
  }
  if (items.isEmpty) return null;

  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(margin),
    build: (_) => items,
  ));

  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/pandive_docs_'
      '${DateTime.now().millisecondsSinceEpoch}.pdf');
  return out.writeAsBytes(bytes, flush: true);
}

/// Size in points without enlarging: ~150 dpi, capped to the available width/height.
PdfPoint _fit(double pxW, double pxH, double maxW, double maxH) {
  const dpi = 150.0;
  var w = pxW * 72 / dpi;
  var h = pxH * 72 / dpi;
  final k = [1.0, maxW / w, maxH / h].reduce((a, b) => a < b ? a : b);
  return PdfPoint(w * k, h * k);
}

/// Exportar documentos seleccionados a un único PDF (una página por documento,
/// con su título) y compartirlo.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/documents/logic/document_store.dart';

Future<void> exportDocumentsPdf(List<DiveDoc> docs) async {
  if (docs.isEmpty) return;
  final pdf = pw.Document();
  for (final d in docs) {
    final file = await docFile(d.fileName);
    if (!await file.exists()) continue;
    final image = pw.MemoryImage(await file.readAsBytes());
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(d.title,
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            if (d.notes != null && d.notes!.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(d.notes!),
              ),
            pw.SizedBox(height: 12),
            pw.Expanded(
                child: pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain))),
          ],
        ),
      ),
    );
  }
  final bytes = await pdf.save();
  final dir = await getTemporaryDirectory();
  final out = File('${dir.path}/pandive_docs_'
      '${DateTime.now().millisecondsSinceEpoch}.pdf');
  await out.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(out.path)]));
}

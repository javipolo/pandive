/// Detalle de un documento: imagen a tamaño grande, notas y estado; editar,
/// borrar y compartir (como PDF).
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/documents/logic/document_export.dart';
import 'package:pandive/core/storage/documents_storage.dart';
import 'package:pandive/features/documents/screens/document_edit_screen.dart';
import 'package:pandive/features/documents/widgets/document_status.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DocumentDetailScreen extends StatefulWidget {
  final DivemateDb db;
  final DiveDoc doc;
  final String imagePath;
  const DocumentDetailScreen(
      {super.key, required this.db, required this.doc, required this.imagePath});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  late DiveDoc _doc = widget.doc;

  Future<void> _edit() async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => DocumentEditScreen(db: widget.db, doc: _doc)));
    if (ok == true) {
      final fresh = widget.db.getDocument(_doc.id);
      if (fresh != null && mounted) setState(() => _doc = fresh);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.docDeleteConfirm,
        confirmLabel: t.delete)) {
      return;
    }
    widget.db.deleteDocument(_doc.id);
    await deleteDocFile(_doc.fileName);
    if (mounted) Navigator.of(context).pop(true);
  }

  void _openZoom() => Navigator.of(context).push(MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                child: Image.file(File(widget.imagePath), fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ]),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final status = _doc.status(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: Text(_doc.title),
        actions: [
          IconButton(
              tooltip: t.exportSelection,
              icon: const Icon(Icons.share),
              onPressed: () => exportDocumentsPdf([_doc])),
          IconButton(
              tooltip: t.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit),
          IconButton(
              tooltip: t.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (status != DocStatus.none)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(docStatusLabel(t, status, _doc.expiryDate),
                  style: TextStyle(
                      color: docStatusColor(context, status),
                      fontWeight: FontWeight.bold)),
            ),
          GestureDetector(
            onTap: _openZoom,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: Image.file(File(widget.imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, size: 80)),
            ),
          ),
          if (_doc.notes != null && _doc.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(_doc.notes!),
          ],
        ],
      ),
    );
  }
}

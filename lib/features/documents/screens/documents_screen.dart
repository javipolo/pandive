/// Sección "Documentación": lista de documentos con estado de caducidad, alta
/// (imagen/PDF + recorte), y exportación múltiple a PDF.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/documents/logic/document_export.dart';
import 'package:pandive/features/documents/logic/document_import.dart';
import 'package:pandive/features/documents/logic/document_store.dart';
import 'package:pandive/features/documents/screens/document_detail_screen.dart';
import 'package:pandive/features/documents/screens/document_edit_screen.dart';
import 'package:pandive/features/documents/widgets/document_tile.dart';
import 'package:pandive/features/documents/widgets/documents_banner.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DocumentsScreen extends StatefulWidget {
  final DivemateDb db;
  const DocumentsScreen({super.key, required this.db});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late List<DiveDoc> _docs = widget.db.listDocuments();
  String? _dir;
  final Set<int> _sel = {};
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    documentsDir().then((d) {
      if (mounted) setState(() => _dir = d.path);
    });
  }

  void _reload() => setState(() => _docs = widget.db.listDocuments());

  Future<void> _add() async {
    final fileName = await importDocumentImage(context);
    if (fileName == null || !mounted) return;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) =>
            DocumentEditScreen(db: widget.db, fileName: fileName)));
    if (ok == true) {
      _reload();
    } else {
      await deleteDocFile(fileName); // alta cancelada: no dejar huérfano
    }
  }

  Future<void> _open(DiveDoc d) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(
            db: widget.db, doc: d, imagePath: '$_dir/${d.fileName}')));
    if (ok == true) _reload();
  }

  void _toggle(int id) => setState(() {
        if (!_sel.remove(id)) _sel.add(id);
        if (_sel.isEmpty) _selecting = false;
      });

  void _exitSel() => setState(() {
        _selecting = false;
        _sel.clear();
      });

  Future<void> _export() async {
    await exportDocumentsPdf(
        _docs.where((d) => _sel.contains(d.id)).toList());
    _exitSel();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_selecting ? t.selectedCount(_sel.length) : t.documents),
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSel)
            : null,
        actions: [
          if (_selecting)
            IconButton(
                tooltip: t.exportSelection,
                icon: const Icon(Icons.share),
                onPressed: _sel.isEmpty ? null : _export),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(t.docAdd)),
      body: _dir == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              DocumentsBanner(docs: _docs),
              Expanded(
                child: _docs.isEmpty
                    ? Center(child: Text(t.docEmpty))
                    : ListView.separated(
                        itemCount: _docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = _docs[i];
                          return DocumentTile(
                            doc: d,
                            imagePath: '$_dir/${d.fileName}',
                            selected: _sel.contains(d.id),
                            selectionMode: _selecting,
                            onTap: () =>
                                _selecting ? _toggle(d.id) : _open(d),
                            onLongPress: () => setState(() {
                              _selecting = true;
                              _sel.add(d.id);
                            }),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}

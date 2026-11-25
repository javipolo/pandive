/// "Documents" section: list of documents with expiry status, create
/// (image/PDF + crop), and multiple export to PDF.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/doc_notifications.dart';
import 'package:pandive/core/widgets/confirm_dialog.dart';
import 'package:pandive/features/documents/logic/document_export.dart';
import 'package:pandive/features/documents/logic/document_import.dart';
import 'package:pandive/core/storage/documents_storage.dart';
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
      await deleteDocFile(fileName); // create cancelled: don't leave an orphan
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
        context, _docs.where((d) => _sel.contains(d.id)).toList());
    _exitSel();
  }

  void _reorder(int oldI, int newI) {
    // onReorderItem already adjusts newI for the item removed at oldI.
    setState(() {
      final d = _docs.removeAt(oldI);
      _docs.insert(newI, d);
    });
    widget.db.setDocumentOrder([for (final d in _docs) d.id]);
  }

  Future<void> _deleteSel() async {
    final t = AppLocalizations.of(context);
    if (!await confirmDialog(context, t.deleteConfirm(_sel.length),
        confirmLabel: t.delete)) {
      return;
    }
    for (final d in _docs.where((d) => _sel.contains(d.id))) {
      widget.db.deleteDocument(d.id);
      await deleteDocFile(d.fileName);
    }
    _exitSel();
    _reload();
    if (mounted) syncDocNotifications(widget.db, AppLocalizations.of(context));
  }

  Widget _tile(DiveDoc d, {int? index}) {
    return DocumentTile(
      key: ValueKey(d.id),
      doc: d,
      imagePath: '$_dir/${d.fileName}',
      selected: _sel.contains(d.id),
      selectionMode: _selecting,
      onTap: () => _selecting ? _toggle(d.id) : _open(d),
      onLongPress: () => setState(() {
        _selecting = true;
        _sel.add(d.id);
      }),
      dragHandle: index == null
          ? null
          : ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle)),
    );
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
          if (_selecting) ...[
            IconButton(
                tooltip: t.exportSelection,
                icon: const Icon(Icons.share),
                onPressed: _sel.isEmpty ? null : _export),
            IconButton(
                tooltip: t.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: _sel.isEmpty ? null : _deleteSel),
          ],
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
                    : _selecting
                        ? ListView.separated(
                            itemCount: _docs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) => _tile(_docs[i]),
                          )
                        : ReorderableListView.builder(
                            itemCount: _docs.length,
                            onReorderItem: _reorder,
                            buildDefaultDragHandles: false,
                            itemBuilder: (context, i) => _tile(_docs[i], index: i),
                          ),
              ),
            ]),
    );
  }
}

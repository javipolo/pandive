/// Alta/edición de los metadatos de un documento: título, notas y caducidad.
/// La imagen ya está elegida (alta) o no cambia (edición).
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/services/doc_notifications.dart';
import 'package:pandive/core/widgets/labeled_field.dart';
import 'package:pandive/core/widgets/save_action.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DocumentEditScreen extends StatefulWidget {
  final DivemateDb db;
  final DiveDoc? doc; // null = alta
  final String? fileName; // requerido en alta
  const DocumentEditScreen(
      {super.key, required this.db, this.doc, this.fileName});

  @override
  State<DocumentEditScreen> createState() => _DocumentEditScreenState();
}

class _DocumentEditScreenState extends State<DocumentEditScreen> {
  late final _title = TextEditingController(text: widget.doc?.title ?? '');
  late final _notes = TextEditingController(text: widget.doc?.notes ?? '');
  late bool _expires = widget.doc?.expires ?? false;
  late DateTime? _expiry = widget.doc?.expiryDate;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 30),
    );
    if (d != null) setState(() => _expiry = d);
  }

  void _save() {
    final t = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.docTitleRequired)));
      return;
    }
    final expiry = _expires ? _expiry : null;
    if (widget.doc == null) {
      widget.db.insertDocument(
          title: _title.text,
          notes: _notes.text,
          expires: _expires,
          expiryDate: expiry,
          fileName: widget.fileName!);
    } else {
      widget.db.updateDocument(widget.doc!.id,
          title: _title.text,
          notes: _notes.text,
          expires: _expires,
          expiryDate: expiry);
    }
    syncDocNotifications(widget.db, t); // reprograma avisos de caducidad
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc == null ? t.docNew : t.docEdit),
        actions: [SaveAction(saving: false, onSave: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          LabeledField(controller: _title, label: t.docTitle),
          LabeledField(controller: _notes, label: t.docNotes, maxLines: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.docExpiresQuestion),
            value: _expires,
            onChanged: (v) => setState(() => _expires = v),
          ),
          if (_expires)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(_expiry == null
                  ? t.docPickExpiry
                  : DateFormat('dd/MM/yyyy', locale).format(_expiry!)),
              onTap: _pickDate,
            ),
        ],
      ),
    );
  }
}

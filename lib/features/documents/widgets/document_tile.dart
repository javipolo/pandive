/// Fila de documento: miniatura + título + estado de caducidad.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/documents/widgets/document_status.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DocumentTile extends StatelessWidget {
  final DiveDoc doc;
  final String imagePath;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DocumentTile({
    super.key,
    required this.doc,
    required this.imagePath,
    required this.onTap,
    required this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final status = doc.status(DateTime.now());
    final color = docStatusColor(context, status);
    final sub = <String>[
      if (doc.expires && doc.expiryDate != null)
        DateFormat('dd/MM/yyyy', locale).format(doc.expiryDate!),
      if (status != DocStatus.none) docStatusLabel(t, status, doc.expiryDate),
    ].join('  ·  ');
    return ListTile(
      selected: selected,
      leading: selectionMode
          ? Icon(selected ? Icons.check_circle : Icons.circle_outlined)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(File(imagePath),
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.insert_drive_file_outlined, size: 40)),
            ),
      title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, style: TextStyle(color: color, fontSize: 12)),
      trailing: !selectionMode && status != DocStatus.none
          ? Icon(Icons.circle, size: 12, color: color)
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

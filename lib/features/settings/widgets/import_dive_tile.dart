/// Fila de las listas "elige qué buceos importar": checkbox, sitio y
/// fecha/duración/profundidad. Verde = nuevo; ámbar = ya existe (con
/// [duplicateText]; solo se puede marcar si [duplicateSelectable]).
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class ImportDiveTile extends StatelessWidget {
  final String? place;
  final DateTime date;
  final double? minutes;
  final double? depth;
  final bool duplicate;
  final String duplicateText;
  final bool duplicateSelectable;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const ImportDiveTile({
    super.key,
    required this.place,
    required this.date,
    required this.minutes,
    required this.depth,
    required this.duplicate,
    required this.duplicateText,
    this.duplicateSelectable = false,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final enabled = !duplicate || duplicateSelectable;
    final info = [
      DateFormat('dd/MM/yyyy HH:mm', locale).format(date),
      if (minutes != null) '${minutes!.round()} min',
      if (depth != null) '${NumberFormat('0.0', locale).format(depth)} m',
    ].join('   ');
    return CheckboxListTile(
      value: enabled && selected,
      onChanged: enabled ? (v) => onChanged(v == true) : null,
      tileColor:
          (duplicate ? Colors.amber : Colors.green).withValues(alpha: 0.12),
      title: Text(place == null || place!.isEmpty ? t.dive : place!,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(duplicate ? '$info\n$duplicateText' : info),
      isThreeLine: duplicate,
      secondary: Icon(duplicate
          ? (duplicateSelectable ? Icons.content_copy : Icons.block)
          : Icons.add_circle_outline),
    );
  }
}

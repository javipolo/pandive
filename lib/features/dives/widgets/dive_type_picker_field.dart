/// "Dive type" picker field. When one is picked, the form adds its
/// template cylinders. Shows a sheet with the configured types.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<DiveType?> showDiveTypePicker(
    BuildContext context, List<DiveType> types) {
  final t = AppLocalizations.of(context);
  return showModalBottomSheet<DiveType>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: types.isEmpty
          ? Padding(padding: const EdgeInsets.all(24), child: Text(t.noDiveTypes))
          : ListView(
              shrinkWrap: true,
              children: [
                for (final d in types)
                  ListTile(
                    leading: const Icon(Icons.scuba_diving),
                    title: Text(d.name),
                    subtitle: d.tanks.isEmpty
                        ? null
                        : Text(d.tanks
                            .map((c) => '${c.size?.toStringAsFixed(1) ?? '—'} L')
                            .join(' + ')),
                    onTap: () => Navigator.pop(context, d),
                  ),
              ],
            ),
    ),
  );
}

class DiveTypePickerField extends StatelessWidget {
  final String? typeName;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const DiveTypePickerField({
    super.key,
    required this.typeName,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.scuba_diving),
        title: Text(typeName ?? t.diveType),
        trailing: typeName == null
            ? const Icon(Icons.chevron_right)
            : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        onTap: onTap,
      ),
    );
  }
}

/// Before exporting the selected dives: asks for the logbook name and offers
/// to include the dive profiles (off by default, like the trip export).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

/// Returns null if cancelled; otherwise the (trimmed) name and whether to
/// also export profiles.
Future<({String name, bool profiles})?> showExportSelectionDialog(
        BuildContext context) =>
    showDialog<({String name, bool profiles})>(
        context: context, builder: (_) => const _ExportSelectionDialog());

class _ExportSelectionDialog extends StatefulWidget {
  const _ExportSelectionDialog();

  @override
  State<_ExportSelectionDialog> createState() => _ExportSelectionDialogState();
}

class _ExportSelectionDialogState extends State<_ExportSelectionDialog> {
  final _name = TextEditingController();
  bool _profiles = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.exportName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, autofocus: true),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _profiles,
            onChanged: (v) => setState(() => _profiles = v ?? false),
            title: Text(t.exportWithProfiles),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.of(context)
                .pop((name: _name.text.trim(), profiles: _profiles)),
            child: Text(t.exportAction)),
      ],
    );
  }
}

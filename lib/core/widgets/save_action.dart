/// AppBar "Save" button with a spinner while saving.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class SaveAction extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const SaveAction({super.key, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: saving ? null : onSave,
      icon: saving
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check),
      label: Text(AppLocalizations.of(context).save),
    );
  }
}

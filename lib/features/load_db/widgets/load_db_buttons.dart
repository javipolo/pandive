/// Load screen buttons: open .ddb, create new, import .ssrf.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class LoadDbButtons extends StatelessWidget {
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  const LoadDbButtons({
    super.key,
    required this.busy,
    required this.onPick,
    required this.onCreate,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onPick,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.folder_open),
          label: Text(t.pickFile),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: busy ? null : onCreate,
          icon: const Icon(Icons.add),
          label: Text(t.createNewDb),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: busy ? null : onImport,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(t.importSubsurface),
        ),
      ],
    );
  }
}

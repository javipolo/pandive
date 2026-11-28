/// Strip shown at the bottom of the web version: the logbook lives in the
/// browser's memory and changes are lost on reload.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class WebPreviewBanner extends StatelessWidget {
  const WebPreviewBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.tertiaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            AppLocalizations.of(context).webPreviewBanner,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onTertiaryContainer),
          ),
        ),
      ),
    );
  }
}

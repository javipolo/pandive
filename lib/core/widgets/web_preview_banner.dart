/// Strip shown at the bottom of the web version: the logbook lives in the
/// browser's memory and changes are lost on reload, unless Drive sync is on
/// (then: wait for it to sync before closing).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/services/sync_controller.dart';
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
          child: ListenableBuilder(
            listenable: syncController,
            builder: (context, _) => Text(
              syncController.enabled
                  ? AppLocalizations.of(context).webBannerSynced
                  : AppLocalizations.of(context).webPreviewBanner,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onTertiaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Mark as already imported" confirmation.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class BaselineDone extends StatelessWidget {
  final VoidCallback onDone;
  const BaselineDone({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline, size: 64),
          const SizedBox(height: 12),
          Text(
            t.baselineDone,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: Text(t.done)),
        ]),
      ),
    );
  }
}

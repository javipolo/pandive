/// Top action bar in selection mode (batch operations).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class SelectionBar extends StatelessWidget {
  final int count;
  final VoidCallback onClose;
  final List<Widget> actions;

  const SelectionBar({
    super.key,
    required this.count,
    required this.onClose,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            color: cs.onSecondaryContainer,
          ),
          Expanded(
            child: Text(
              t.selectedCount(count),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: cs.onSecondaryContainer),
            ),
          ),
          ...actions,
        ]),
      ),
    );
  }
}

/// Generic bottom sheet with a titled list of options; returns the value of
/// the tapped one (null if dismissed). Used by the batch actions (dive type,
/// add/remove tag).
library;

import 'package:material_ui/material_ui.dart';

class Choice<T> {
  final IconData icon;
  final String label;
  final String? subtitle;
  final T value;

  const Choice(this.icon, this.label, this.value, {this.subtitle});
}

Future<T?> showChoiceSheet<T>(
    BuildContext context, String title, List<Choice<T>> choices,
    {String? emptyText}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          if (choices.isEmpty && emptyText != null)
            Padding(
                padding: const EdgeInsets.all(24), child: Text(emptyText)),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final c in choices)
                ListTile(
                  leading: Icon(c.icon),
                  title: Text(c.label),
                  subtitle: c.subtitle == null ? null : Text(c.subtitle!),
                  onTap: () => Navigator.pop(ctx, c.value),
                ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

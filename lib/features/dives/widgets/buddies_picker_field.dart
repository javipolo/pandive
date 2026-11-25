/// Field showing the chosen buddies (chips) and allowing editing them.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class BuddiesPickerField extends StatelessWidget {
  final List<Buddy> buddies;
  final VoidCallback onTap;

  const BuddiesPickerField({
    super.key,
    required this.buddies,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.people_outline),
        title: Text(t.buddies),
        subtitle: buddies.isEmpty
            ? Text(t.selectBuddies)
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final b in buddies)
                      Chip(
                        label: Text(b.name),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onTap,
      ),
    );
  }
}

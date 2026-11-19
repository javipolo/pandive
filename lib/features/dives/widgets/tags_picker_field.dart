/// Campo que muestra las etiquetas (tags) elegidas y permite editarlas.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TagsPickerField extends StatelessWidget {
  final List<Tag> tags;
  final VoidCallback onTap;
  const TagsPickerField({super.key, required this.tags, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.label_outline),
        title: Text(t.tags),
        subtitle: tags.isEmpty
            ? Text(t.selectTags)
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in tags)
                      Chip(
                        label: Text(tag.name),
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

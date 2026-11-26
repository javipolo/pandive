/// Field showing the chosen tags and allowing editing them. Inherited tags
/// (site / dive type) are shown tinted and aren't edited here.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/tag_chips.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TagsPickerField extends StatelessWidget {
  final List<Tag> tags;
  final List<InheritedTag> inherited;
  final VoidCallback onTap;
  const TagsPickerField({
    super.key,
    required this.tags,
    required this.onTap,
    this.inherited = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.label_outline),
        title: Text(t.tags),
        subtitle: tags.isEmpty && inherited.isEmpty
            ? Text(t.selectTags)
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TagChips(own: tags, inherited: inherited, compact: true),
              ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onTap,
      ),
    );
  }
}

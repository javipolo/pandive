/// Tag chips of a dive: the manual ones (plain) and the inherited ones from
/// the site or the dive type (tinted, with an icon of their source), so it's
/// clear which are automatic.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class TagChips extends StatelessWidget {
  final List<Tag> own;
  final List<InheritedTag> inherited;
  final bool compact;
  const TagChips({
    super.key,
    required this.own,
    this.inherited = const [],
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final density = compact ? VisualDensity.compact : null;
    final ownIds = {for (final tag in own) tag.id};
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final tag in own) Chip(label: Text(tag.name), visualDensity: density),
      for (final i in inherited)
        if (!ownIds.contains(i.tag.id))
          Tooltip(
            message: i.source == TagSource.site
                ? t.tagFromSite
                : t.tagFromDiveType,
            child: Chip(
              avatar: Icon(
                i.source == TagSource.site
                    ? Icons.place_outlined
                    : Icons.scuba_diving,
                size: 16,
                color: scheme.onTertiaryContainer,
              ),
              label: Text(i.tag.name),
              labelStyle: TextStyle(color: scheme.onTertiaryContainer),
              backgroundColor: scheme.tertiaryContainer,
              side: BorderSide(color: scheme.tertiaryContainer),
              visualDensity: density,
            ),
          ),
    ]);
  }
}

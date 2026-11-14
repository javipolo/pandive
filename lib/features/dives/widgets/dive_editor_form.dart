/// Cuerpo común de alta/edición de inmersión: sitio, compañeros, etiquetas,
/// tipo de buceo, campos escalares y botellas. Reutilizado por new/edit.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/features/dives/widgets/buddies_picker_field.dart';
import 'package:pandive/features/dives/widgets/dive_form.dart';
import 'package:pandive/features/dives/widgets/dive_type_picker_field.dart';
import 'package:pandive/features/dives/widgets/site_picker_field.dart';
import 'package:pandive/features/dives/widgets/tags_picker_field.dart';
import 'package:pandive/features/dives/widgets/tanks_editor.dart';

class DiveEditorForm extends StatelessWidget {
  final DiveFormControllers c;
  final DateTime when;
  final ValueChanged<DateTime> onWhen;
  final int rating;
  final ValueChanged<int> onRating;
  final DiveSite? site;
  final VoidCallback onPickSite;
  final VoidCallback onClearSite;
  final List<Buddy> buddies;
  final VoidCallback onPickBuddies;
  final List<Tag> tags;
  final VoidCallback onPickTags;
  final String? diveTypeName;
  final VoidCallback onPickType;
  final VoidCallback onClearType;
  final List<Cylinder> tanks;
  final List<TankPreset> presets;
  final ValueChanged<List<Cylinder>> onTanksChanged;
  final double? sac;

  const DiveEditorForm({
    super.key,
    required this.c,
    required this.when,
    required this.onWhen,
    required this.rating,
    required this.onRating,
    required this.site,
    required this.onPickSite,
    required this.onClearSite,
    required this.buddies,
    required this.onPickBuddies,
    required this.tags,
    required this.onPickTags,
    required this.diveTypeName,
    required this.onPickType,
    required this.onClearType,
    required this.tanks,
    required this.presets,
    required this.onTanksChanged,
    this.sac,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SitePickerField(site: site, onTap: onPickSite, onClear: onClearSite),
        BuddiesPickerField(buddies: buddies, onTap: onPickBuddies),
        TagsPickerField(tags: tags, onTap: onPickTags),
        DiveTypePickerField(
            typeName: diveTypeName, onTap: onPickType, onClear: onClearType),
        DiveForm(
          c: c,
          when: when,
          onWhen: onWhen,
          rating: rating,
          onRating: onRating,
        ),
        const SizedBox(height: 16),
        TanksEditor(
            tanks: tanks, presets: presets, sac: sac, onChanged: onTanksChanged),
      ],
    );
  }
}

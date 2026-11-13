/// Campo que muestra el sitio de buceo elegido y permite seleccionar/quitar.
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SitePickerField extends StatelessWidget {
  final DiveSite? site;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const SitePickerField({
    super.key,
    required this.site,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sub = site == null
        ? null
        : [site!.country, site!.region]
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' · ');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.place_outlined),
        title: Text(site?.name ?? t.selectSite),
        subtitle: (sub != null && sub.isNotEmpty) ? Text(sub) : null,
        trailing: site != null
            ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

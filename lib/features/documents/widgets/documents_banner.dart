/// Aviso resumen en la lista de documentos: cuántos caducados / por caducar.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

class DocumentsBanner extends StatelessWidget {
  final List<DiveDoc> docs;
  const DocumentsBanner({super.key, required this.docs});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final now = DateTime.now();
    final expired = docs.where((d) => d.status(now) == DocStatus.expired).length;
    final soon = docs.where((d) => d.status(now) == DocStatus.soon).length;
    if (expired == 0 && soon == 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final bad = expired > 0;
    final msg = [
      if (expired > 0) t.docBannerExpired(expired),
      if (soon > 0) t.docBannerSoon(soon),
    ].join('  ·  ');
    return Container(
      width: double.infinity,
      color: bad ? cs.errorContainer : Colors.orange.shade100,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(bad ? Icons.error_outline : Icons.warning_amber_outlined,
            color: bad ? cs.onErrorContainer : Colors.orange.shade900),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    color:
                        bad ? cs.onErrorContainer : Colors.orange.shade900))),
      ]),
    );
  }
}

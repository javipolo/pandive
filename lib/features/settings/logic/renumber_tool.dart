/// Herramienta "Renumerar buceos": vista previa de los cambios y confirmación.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/services/data_revision.dart';
import 'package:pandive/l10n/app_localizations.dart';

Future<void> runRenumberTool(BuildContext context, DivemateDb db) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final plan = db.renumberPlan();
  if (plan.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(t.renumberNothing)));
    return;
  }
  const shown = 8;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.renumberDives),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.renumberPreview(plan.length, db.firstNumber)),
            const SizedBox(height: 12),
            for (final c in plan.take(shown))
              Text('#${c.from ?? '–'}  →  #${c.to}',
                  style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()])),
            if (plan.length > shown) Text('…'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.renumberDives)),
      ],
    ),
  );
  if (ok != true) return;
  final n = db.renumberDives();
  bumpDataRevision();
  messenger.showSnackBar(SnackBar(content: Text(t.renumberResult(n))));
}

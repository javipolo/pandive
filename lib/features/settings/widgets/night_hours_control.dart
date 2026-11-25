/// Night dive time window: two time pickers (from/to)
/// with the value always visible.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/l10n/app_localizations.dart';

class NightHoursControl extends StatelessWidget {
  final Settings settings;
  const NightHoursControl({super.key, required this.settings});

  String _fmt(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      _row(context, t.nightFrom, settings.nightStartHour,
          settings.setNightStartHour),
      _row(context, t.nightUntil, settings.nightEndHour,
          settings.setNightEndHour),
    ]);
  }

  Widget _row(
      BuildContext context, String label, int value, ValueChanged<int> onSet) {
    return ListTile(
      title: Text(label),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            icon: const Icon(Icons.remove), onPressed: () => onSet(value - 1)),
        SizedBox(
          width: 64,
          child: Text(_fmt(value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
            icon: const Icon(Icons.add), onPressed: () => onSet(value + 1)),
      ]),
    );
  }
}

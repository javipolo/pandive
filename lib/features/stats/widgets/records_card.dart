/// Tarjeta de récords personales: buceo más profundo, más largo y más frío
/// (tocar abre ese buceo) + próximo hito por nº de inmersiones.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

const _marks = [10, 25, 50, 100, 150, 200, 250, 300, 400, 500, 750, 1000];

class RecordsCard extends StatelessWidget {
  final PersonalRecords records;
  final int totalDives;
  final void Function(int diveId) onOpen;
  const RecordsCard(
      {super.key,
      required this.records,
      required this.totalDives,
      required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fmt = DateFormat('dd/MM/yyyy');
    final next = _marks.firstWhere((m) => m > totalDives,
        orElse: () => ((totalDives ~/ 500) + 1) * 500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(context, t, fmt, Icons.vertical_align_bottom, t.recordDeepest,
            records.deepest, (v) => '${v.toStringAsFixed(1)} m'),
        _row(context, t, fmt, Icons.timer_outlined, t.recordLongest,
            records.longest, (v) => '${v.round()} min'),
        _row(context, t, fmt, Icons.ac_unit, t.recordColdest, records.coldest,
            (v) => '${v.toStringAsFixed(1)} °C'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(t.recordsMilestone(next, next - totalDives),
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _row(BuildContext c, AppLocalizations t, DateFormat fmt, IconData icon,
      String label, DiveRecord? r, String Function(double) val) {
    if (r == null) return const SizedBox.shrink();
    final sub = [
      if (r.date != null) fmt.format(r.date!),
      if ((r.site ?? '').isNotEmpty) r.site!,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(label),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: Text(val(r.value),
          style: Theme.of(c)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
      onTap: () => onOpen(r.diveId),
    );
  }
}

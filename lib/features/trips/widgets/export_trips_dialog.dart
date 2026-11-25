/// Confirmation before exporting trips: lists the trips and offers to include
/// the dive profiles (off by default).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

/// Returns null if cancelled; otherwise, whether to also export profiles.
Future<bool?> showExportTripsDialog(BuildContext context, List<Trip> trips) =>
    showDialog<bool>(
        context: context, builder: (_) => _ExportTripsDialog(trips: trips));

class _ExportTripsDialog extends StatefulWidget {
  final List<Trip> trips;
  const _ExportTripsDialog({required this.trips});

  @override
  State<_ExportTripsDialog> createState() => _ExportTripsDialogState();
}

class _ExportTripsDialogState extends State<_ExportTripsDialog> {
  bool _profiles = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.exportTrip),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.exportTripsIntro),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final tr in widget.trips)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${tr.name}'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _profiles,
            onChanged: (v) => setState(() => _profiles = v ?? false),
            title: Text(t.exportWithProfiles),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.cancel)),
        FilledButton(
            onPressed: () => Navigator.of(context).pop(_profiles),
            child: Text(t.exportAction)),
      ],
    );
  }
}

/// Download progress indicator: large wheel + % below (readable).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';

class DownloadProgress extends StatelessWidget {
  final double progress; // 0.0–1.0 (0 = indeterminate at first)
  /// If true, no % is shown: the memory total doesn't reflect what's left
  /// when only N dives are downloaded (sync / mark imported).
  final bool indeterminate;
  const DownloadProgress(
      {super.key, required this.progress, this.indeterminate = false});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final determinate = !indeterminate && progress > 0;
    final pct = (progress * 100).round();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CircularProgressIndicator(
              value: determinate ? progress : null,
              strokeWidth: 14,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            determinate ? '$pct %' : t.connecting,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            t.downloadingHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

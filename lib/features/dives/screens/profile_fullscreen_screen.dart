/// Maximised dive profile. Shown in the phone's current orientation:
/// in portrait it fills the screen, and if you rotate the phone, landscape (better).
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/features/dives/logic/dive_facts.dart';
import 'package:pandive/features/dives/logic/share_profile.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ProfileFullscreenScreen extends StatelessWidget {
  final DiveProfile profile;
  final String title;
  final String? shareTitle; // title of the shared image (with date)
  final DiveFacts facts; // footer of the shared image
  final List<GasChange> gasChanges;
  const ProfileFullscreenScreen({
    super.key,
    required this.profile,
    required this.title,
    this.shareTitle,
    required this.facts,
    this.gasChanges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
          icon: Icon(shareProfileIcon),
          tooltip: shareProfileTooltip(t),
          onPressed: () => shareProfileImage(context,
              profile: profile,
              title: shareTitle ?? title,
              facts: facts,
              gasChanges: gasChanges),
        ),
        // Aligns the icon with the plot's right edge (before the temp axis).
        const SizedBox(width: 56),
      ]),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: ProfileChart(profile: profile, gasChanges: gasChanges),
      ),
    );
  }
}

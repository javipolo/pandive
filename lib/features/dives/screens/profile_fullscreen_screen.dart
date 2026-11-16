/// Perfil de inmersión maximizado. Se ve en la orientación actual del móvil:
/// en vertical ocupa toda la pantalla, y si giras el móvil, apaisado (mejor).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/features/dives/logic/share_profile.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ProfileFullscreenScreen extends StatelessWidget {
  final DiveProfile profile;
  final String title;
  final List<GasChange> gasChanges;
  const ProfileFullscreenScreen({
    super.key,
    required this.profile,
    required this.title,
    this.gasChanges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Stack(children: [
          ProfileChart(profile: profile, gasChanges: gasChanges),
          // Justo a la izquierda del eje de temperatura (margen derecho ~62).
          Positioned(
            top: 0,
            right: 64,
            child: IconButton.filledTonal(
              icon: const Icon(Icons.share),
              tooltip: t.share,
              onPressed: () => shareProfileImage(context,
                  profile: profile, title: title, gasChanges: gasChanges),
            ),
          ),
        ]),
      ),
    );
  }
}

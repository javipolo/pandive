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
  final String? shareTitle; // título de la imagen compartida (con fecha)
  final List<GasChange> gasChanges;
  const ProfileFullscreenScreen({
    super.key,
    required this.profile,
    required this.title,
    this.shareTitle,
    this.gasChanges = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: t.share,
          onPressed: () => shareProfileImage(context,
              profile: profile,
              title: shareTitle ?? title,
              gasChanges: gasChanges),
        ),
        // Alinea el icono con el borde derecho del plot (antes del eje de temp.).
        const SizedBox(width: 56),
      ]),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: ProfileChart(profile: profile, gasChanges: gasChanges),
      ),
    );
  }
}

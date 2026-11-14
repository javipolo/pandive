/// Perfil de inmersión maximizado. Se ve en la orientación actual del móvil:
/// en vertical ocupa toda la pantalla, y si giras el móvil, apaisado (mejor).
library;

import 'package:flutter/material.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';

class ProfileFullscreenScreen extends StatelessWidget {
  final DiveProfile profile;
  final String title;
  const ProfileFullscreenScreen({
    super.key,
    required this.profile,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: ProfileChart(profile: profile),
      ),
    );
  }
}

/// Perfil de inmersión a pantalla completa, forzando orientación apaisada.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';

class ProfileFullscreenScreen extends StatefulWidget {
  final DiveProfile profile;
  final String title;
  const ProfileFullscreenScreen({
    super.key,
    required this.profile,
    required this.title,
  });

  @override
  State<ProfileFullscreenScreen> createState() =>
      _ProfileFullscreenScreenState();
}

class _ProfileFullscreenScreenState extends State<ProfileFullscreenScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: ProfileChart(profile: widget.profile),
      ),
    );
  }
}

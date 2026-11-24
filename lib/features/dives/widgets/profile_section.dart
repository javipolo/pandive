/// Sección del perfil en el detalle: gráfica compacta con botones de compartir
/// y pantalla completa superpuestos.
library;

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/models/models.dart';
import 'package:pandive/core/widgets/profile_chart.dart';
import 'package:pandive/features/dives/logic/share_profile.dart';
import 'package:pandive/features/dives/screens/profile_fullscreen_screen.dart';
import 'package:pandive/features/dives/widgets/gas_segments.dart';
import 'package:pandive/l10n/app_localizations.dart';

class ProfileSection extends StatelessWidget {
  final DivemateDb db;
  final Dive dive;
  final DiveProfile profile;
  const ProfileSection(
      {super.key, required this.db, required this.dive, required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = dive.place ?? t.dive;
    // Título para compartir: "DD/MM/YYYY - Sitio".
    final locale = Localizations.localeOf(context).languageCode;
    final shareTitle = dive.date != null
        ? '${DateFormat('dd/MM/yyyy', locale).format(dive.date!)} - $title'
        : title;
    final gasChanges = buildGasChanges(
        db.gasPerSample(dive.id), profile.timesMinutes, db.cylinders(dive.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(children: [
          SizedBox(
              height: 240,
              child: ProfileChart(profile: profile, compact: true)),
          Positioned(
            right: 0,
            top: 0,
            child: Row(children: [
              IconButton.filledTonal(
                icon: Icon(shareProfileIcon),
                tooltip: shareProfileTooltip(t),
                onPressed: () => shareProfileImage(context,
                    profile: profile, title: shareTitle, gasChanges: gasChanges),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.fullscreen),
                tooltip: t.fullscreen,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ProfileFullscreenScreen(
                      profile: profile,
                      title: title,
                      shareTitle: shareTitle,
                      gasChanges: gasChanges),
                )),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
      ],
    );
  }
}

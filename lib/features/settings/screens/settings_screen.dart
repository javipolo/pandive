/// App settings: language and font size.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/settings/settings.dart';
import 'package:pandive/features/settings/widgets/language_theme_selectors.dart';
import 'package:pandive/features/settings/widgets/merge_gap_control.dart';
import 'package:pandive/features/settings/widgets/night_hours_control.dart';
import 'package:pandive/features/settings/widgets/numbering_control.dart';
import 'package:pandive/features/settings/widgets/text_scale_control.dart';
import 'package:pandive/l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final DivemateDb db;
  final VoidCallback onChangeDb;
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.db,
    required this.onChangeDb,
  });

  Future<void> _confirmChangeDb(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(t.menuChangeDb),
        content: Text(t.changeDbWarning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.menuChangeDb)),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      Navigator.pop(context); // close settings
      onChangeDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(t.settingsTitle)),
          body: ListView(
            children: [
              LanguageThemeSelectors(settings: settings),
              const Divider(),
              _header(context, t.textSize),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(t.textSizeHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              TextScaleControl(settings: settings),
              Center(
                child: TextButton(
                  onPressed: () =>
                      settings.setTextScale(Settings.defaultTextScale),
                  child: Text(t.reset),
                ),
              ),
              const Divider(),
              _header(context, t.diveNumbering),
              NumberingControl(db: db),
              const Divider(),
              _header(context, t.mergeGapSetting),
              MergeGapControl(settings: settings),
              const Divider(),
              _header(context, t.nightDiveHours),
              NightHoursControl(settings: settings),
              const Divider(),
              _header(context, t.database),
              ListTile(
                leading: Icon(Icons.swap_horiz,
                    color: Theme.of(context).colorScheme.error),
                title: Text(t.menuChangeDb),
                subtitle: Text(t.changeDbWarning),
                onTap: () => _confirmChangeDb(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}

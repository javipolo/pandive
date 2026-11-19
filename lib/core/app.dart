/// App raíz: MaterialApp con escala de texto global, y AppRoot que decide la
/// pantalla inicial según haya o no una base de datos cargada.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/l10n/app_localizations.dart';
import 'app_root.dart';
import 'settings/settings.dart';
import 'theme/app_theme.dart';

class PandiveApp extends StatelessWidget {
  final Settings settings;
  const PandiveApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'PanDive',
          debugShowCheckedModeBanner: false,
          theme: appTheme(Brightness.light),
          darkTheme: appTheme(Brightness.dark),
          themeMode: settings.themeMode,
          locale: settings.locale, // null = idioma del sistema
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            // Escala de texto global (accesibilidad / presbicia).
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child!,
            );
          },
          home: AppRoot(settings: settings),
        );
      },
    );
  }
}

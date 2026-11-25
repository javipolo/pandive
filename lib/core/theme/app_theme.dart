/// App theme (Material 3, diving blue).
library;

import 'package:material_ui/material_ui.dart';

ThemeData appTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00677E), // diving blue
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

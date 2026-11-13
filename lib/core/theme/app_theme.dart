/// Tema de la app (Material 3, azul buceo).
library;

import 'package:flutter/material.dart';

ThemeData appTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00677E), // azul buceo
      brightness: brightness,
    ),
    useMaterial3: true,
  );
}

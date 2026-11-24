/// Peticiones de navegación a la pantalla principal desde pantallas apiladas
/// encima (p.ej. tras importar: volver a la lista de buceos).
library;

import 'package:flutter/foundation.dart';

/// Sección pedida (índice de la barra inferior); la consume HomeScreen.
final ValueNotifier<int?> homeSectionRequest = ValueNotifier<int?>(null);

/// Pide mostrar la lista de buceos (sección 0).
void requestDivesList() => homeSectionRequest.value = 0;

/// Señal global de "los datos han cambiado" para refrescar las pestañas sin
/// cerrar/reabrir la base de datos (reload blando). Lo usan las herramientas
/// que escriben en la DB ya abierta (enriquecer, tags, papelera…).
library;

import 'package:flutter/foundation.dart';

final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

void bumpDataRevision() => dataRevision.value++;

# PROJECT_MAP — índice de `lib/`

Lee esto ANTES de buscar con Grep/Glob: te lleva directo al `.dart` exacto.
Mantenlo actualizado al crear/mover/borrar ficheros en `lib/`.

Estructura feature-first: `core/` (transversal) + `features/<nombre>/` (cada una
con `screens/` y, si hace falta, `widgets/`).

## Core / Config

- `lib/main.dart` -> arranque: init locale, carga settings, lanza la app
- `lib/core/app.dart` -> MaterialApp, escala de texto global, AppRoot (elige pantalla)
- `lib/core/theme/app_theme.dart` -> tema Material 3 (azul buceo)
- `lib/core/settings/settings.dart` -> preferencias: escala de texto, ruta DB, idioma, tema, horario nocturno, hueco fusión
- `lib/l10n/app_en.arb` / `app_es.arb` -> traducciones (plantilla EN + ES); `AppLocalizations` se genera con `flutter gen-l10n`
- `lib/core/services/dive_computer.dart` -> puente libdivecomputer: modelos, escaneo BLE, permisos

### Core · base de datos (una librería con `part`s)
- `lib/core/db/divemate_db.dart` -> abre .ddb, owner, helpers; declara los parts
- `lib/core/db/db_queries.dart` -> lecturas: listar/obtener inmersiones, botellas, nº siguiente
- `lib/core/db/db_profile.dart` -> decode del perfil (profundidad/temperatura)
- `lib/core/db/db_stats.dart` -> sitios de buceo y estadísticas agregadas
- `lib/core/db/db_writes.dart` -> escritura: editar y crear inmersiones
- `lib/core/db/db_import.dart` -> importar inmersiones descargadas (encode perfil + dedupe)
- `lib/core/db/db_create.dart` -> crear una .ddb vacía nueva (esquema DiveMate + buceador)
- `lib/core/db/db_helpers.dart` -> helpers de la librería (parse, uuid, timestamp, mapeo de fila)
- `lib/core/db/db_buddies.dart` -> compañeros (Buddy): listar, crear/renombrar/borrar, buceos por buddy
- `lib/core/db/db_sites.dart` -> sitios (Place): obtener/crear/actualizar, find-or-create
- `lib/core/db/db_tanks.dart` -> botellas por buceo, presets "mis botellas", buceos por sitio/buddy
- `lib/core/db/db_merge.dart` -> fusionar inmersiones (perfil concatenado, unión de datos)
- `lib/core/db/db_pending.dart` -> caché de descargados no guardados (reaparecen una vez)
- `lib/core/db/db_dive_types.dart` -> tipos de buceo + plantilla de botellas
- `lib/core/db/db_computers.dart` -> ordenadores de buceo guardados (por MAC)
- `lib/core/sac.dart` -> cálculo de SAC/RMV (l/min)
- `lib/core/text/collate.dart` -> comparación alfabética ignorando acentos

### Core · modelos (`models.dart` es el barrel)
- `lib/core/models/models.dart` -> barrel: reexporta todos los modelos
- `lib/core/models/dive.dart` -> inmersión (fila de Logbook)
- `lib/core/models/dive_profile.dart` -> perfil muestreado (tiempos/profundidades/temps)
- `lib/core/models/cylinder.dart` -> botella/mezcla (+ etiqueta de gas)
- `lib/core/models/dive_site.dart` -> punto de buceo con nº de inmersiones
- `lib/core/models/dive_computer_ref.dart` -> ordenador de buceo guardado (MAC+nombre+modelo)
- `lib/core/models/dive_type.dart` -> tipo de buceo (nombre + plantilla de botellas)
- `lib/core/models/downloaded_dive.dart` -> inmersión descargada del ordenador (+ muestras/gases, parse JSON)
- `lib/core/models/logbook_stats.dart` -> estadísticas agregadas

### Core · widgets compartidos
- `lib/core/widgets/profile_chart.dart` -> gráfico de perfil (prof + temp eje dcho, línea táctil)
- `lib/core/widgets/profile_chart_axes.dart` -> ejes y tooltip del gráfico de perfil
- `lib/core/widgets/save_action.dart` -> botón Guardar de AppBar
- `lib/core/widgets/stat_card.dart` -> tarjeta etiqueta/valor
- `lib/core/widgets/labeled_field.dart` -> campo de texto con etiqueta/borde
- `lib/core/widgets/star_rating.dart` -> selector de valoración por estrellas
- `lib/core/widgets/date_time_field.dart` -> selector de fecha+hora (ListTile)
- `lib/core/widgets/selection_bar.dart` -> barra de acciones en modo selección (lote)
- `lib/core/widgets/confirm_dialog.dart` -> diálogo de confirmación reutilizable
- `lib/core/widgets/name_dialog.dart` -> diálogo de un campo (nombre) reutilizable

## Features

### home
- `lib/features/home/screens/home_screen.dart` -> shell con pestañas y menú
- `lib/features/home/widgets/home_nav_bar.dart` -> barra inferior (Inmersiones/Sitios/Compañeros)
- `lib/features/home/widgets/home_drawer.dart` -> menú lateral (Tags/Equipo/Stats)

### load_db
- `lib/features/load_db/screens/load_db_screen.dart` -> elegir/crear un .ddb (con enum DbLoadError)

### tags (etiquetas)
- `lib/features/tags/screens/tags_tab.dart` -> lista de tags (crear/renombrar/borrar, ver buceos)
- `lib/features/dives/screens/dives_list_screen.dart` -> lista simple de buceos (tag/buddy/sitio)

### settings
- `lib/features/settings/screens/settings_screen.dart` -> ajustes: idioma, tamaño letra, hueco fusión, herramientas, DB
- `lib/features/settings/widgets/text_scale_control.dart` -> control de tamaño de letra (slider + −/+)
- `lib/features/settings/widgets/language_theme_selectors.dart` -> radios de idioma y tema
- `lib/features/settings/widgets/merge_gap_control.dart` -> control del hueco de fusión (slider + valor visible)
- `lib/features/settings/widgets/night_hours_control.dart` -> franja horaria de inmersión nocturna (desde/hasta)

### buddies (compañeros)
- `lib/features/buddies/screens/buddies_tab.dart` -> lista de compañeros (añadir/renombrar/borrar)
- `lib/features/buddies/screens/buddy_dives_screen.dart` -> buceos de un compañero
- `lib/features/buddies/screens/buddy_picker_screen.dart` -> multi-selección de compañeros (para editar buceo)

### dives (inmersiones)
- `lib/features/dives/screens/dives_screen.dart` -> lista + búsqueda + "Nueva" + selección en lote (borrar/fusionar)
- `lib/features/dives/screens/dive_detail_screen.dart` -> detalle: datos, perfil, botellas, editar
- `lib/features/dives/screens/edit_dive_screen.dart` -> editar campos editables
- `lib/features/dives/screens/new_dive_screen.dart` -> formulario de alta manual
- `lib/features/dives/widgets/cylinder_tile.dart` -> tarjeta de botella en el detalle
- `lib/features/dives/widgets/month_grouped_dives.dart` -> lista de buceos agrupada por mes (colapsable, selección)
- `lib/features/dives/widgets/dive_row.dart` -> fila de buceo estilo DiveMate (nº grande + 2 líneas)
- `lib/features/dives/widgets/add_dive_sheet.dart` -> hoja "añadir": alta manual o transferencia
- `lib/features/dives/widgets/dives_selection_bar.dart` -> barra de selección (stats/fusionar/borrar)
- `lib/features/dives/widgets/dive_editor_form.dart` -> cuerpo común alta/edición (sitio/buddies/tags/tipo/campos/botellas)
- `lib/features/dives/widgets/dive_type_picker_field.dart` -> campo + hoja selectora de tipo de buceo
- `lib/features/dives/widgets/tags_picker_field.dart` -> campo de etiquetas elegidas (chips)
- `lib/features/dives/screens/profile_fullscreen_screen.dart` -> perfil a pantalla completa (apaisado)
- `lib/features/dives/screens/tag_picker_screen.dart` -> multi-selección de etiquetas
- `lib/core/widgets/save_action.dart` -> botón Guardar de AppBar
- `lib/core/db/db_tags.dart` -> etiquetas (tags) y enlace por inmersión
- `lib/features/dives/widgets/dive_detail_body.dart` -> cuerpo del detalle (datos, perfil, botellas, SAC)
- `lib/features/dives/widgets/dive_form.dart` -> campos escalares editables (+ controllers)
- `lib/features/dives/widgets/site_picker_field.dart` -> campo de sitio elegido
- `lib/features/dives/widgets/buddies_picker_field.dart` -> campo de compañeros elegidos (chips)
- `lib/features/dives/widgets/tanks_editor.dart` -> editor de botellas + SAC
- `lib/features/dives/widgets/tank_edit_sheet.dart` -> hoja para añadir/editar una botella

### sites (sitios)
- `lib/features/sites/screens/sites_screen.dart` -> lista de sitios: tocar = ver buceos; menú editar/borrar

### stats (estadísticas)
- `lib/features/stats/screens/stats_screen.dart` -> pestaña de stats globales del logbook
- `lib/features/stats/screens/selection_stats_screen.dart` -> stats solo de una selección de buceos
- `lib/features/stats/widgets/stats_view.dart` -> vista reutilizable (tarjetas + barras por año)
- `lib/features/stats/widgets/year_bars.dart` -> barras de inmersiones por año

### dive_computer (ordenador de buceo)
- `lib/features/dive_computer/screens/dive_computer_screen.dart` -> modelos soportados + lanzar escaneo
- `lib/features/dive_computer/screens/computer_pick_screen.dart` -> "Dive transfer": tocar=descargar; menú (descargar todo/marcar/borrar); Buscar
- `lib/features/dive_computer/screens/scan_screen.dart` -> escaneo BLE; al elegir, ofrece guardar (checkbox)
- `lib/features/dive_computer/screens/download_screen.dart` -> descarga inmersiones de un dispositivo y las muestra
- `lib/features/dive_computer/widgets/scan_widgets.dart` -> fila de dispositivo, vista de error, hoja de acciones (descargar/marcar)
- `lib/features/dive_computer/widgets/download_progress.dart` -> indicador circular de progreso con %
- `lib/features/dive_computer/widgets/downloaded_dive_tile.dart` -> fila de inmersión descargada
- `lib/features/dive_computer/widgets/baseline_done.dart` -> confirmación de "marcar como ya importado"
- `lib/features/dive_computer/widgets/download_result_list.dart` -> lista seleccionable (elige qué guardar) + marcar todos
- `lib/features/dive_computer/widgets/download_items.dart` -> construye items (nuevos+pendientes) y aplica la selección

### equipment (tipos de buceo / botella)
- `lib/features/equipment/screens/equipment_tab.dart` -> hub: tipos de buceo + tipos de botella
- `lib/features/dive_types/screens/dive_types_screen.dart` -> lista de tipos de buceo
- `lib/features/dive_types/screens/dive_type_edit_screen.dart` -> crear/editar tipo (nombre + botellas)
- `lib/features/tank_types/screens/tank_types_screen.dart` -> gestión de tipos de botella (presets)
- `lib/features/tank_types/widgets/tank_type_edit_sheet.dart` -> hoja crear/editar tipo de botella

Nativo (fuera de lib/): `android/app/src/main/kotlin/org/drslump/pandive/`
(DiveComputer, BleScanner, BleConnection, MainActivity) y
`android/app/src/main/cpp/pandive_dc.c` (wrapper JNI de libdivecomputer).

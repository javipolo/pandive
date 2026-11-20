# PROJECT_MAP — índice de `lib/`

Lee esto ANTES de buscar con Grep/Glob: te lleva directo al `.dart` exacto.
Mantenlo actualizado al crear/mover/borrar ficheros en `lib/`.

Estructura feature-first: `core/` (transversal) + `features/<nombre>/` (cada una
con `screens/` y, si hace falta, `widgets/`).

## Core / Config

- `lib/main.dart` -> arranque: init locale, carga settings, lanza la app
- `lib/core/app.dart` -> MaterialApp, escala de texto global
- `lib/core/app_root.dart` -> AppRoot: elige pantalla; crea DB vacía en el primer arranque, o pantalla de carga (Cambiar DB / error)
- `lib/core/services/opened_file.dart` -> fichero .ddb entrante (abrir con / compartir): consume + stream
- `lib/core/services/data_revision.dart` -> señal global para refresco blando de pestañas (sin reabrir DB)
- `lib/core/theme/app_theme.dart` -> tema Material 3 (azul buceo)
- `lib/core/settings/settings.dart` -> preferencias: escala de texto, ruta DB, idioma, tema, horario nocturno, hueco fusión
- `lib/l10n/app_en.arb` / `app_es.arb` -> traducciones (plantilla EN + ES); `AppLocalizations` se genera con `flutter gen-l10n`
- `lib/core/services/dive_computer.dart` -> puente libdivecomputer: modelos, escaneo BLE, permisos
- `lib/core/services/drive_backup.dart` -> backup/restore Google Drive: auth, carpeta, hash (parts)
- `lib/core/services/drive_backup_ops.dart` -> operaciones: backupNow/backupIfNeeded/list/restore/poda
- `lib/core/services/backup_util.dart` -> helpers puros: nombre con timestamp y poda a 10 (+ nombre del zip de documentos)
- `lib/core/storage/documents_storage.dart` -> carpeta documents/ en disco (guardar/borrar/ruta); usado por UI y backup
- `lib/core/services/doc_notifications.dart` -> notis locales de caducidad (30/7/1/0 días); permiso solo si hay docs con caducidad

### Core · base de datos (una librería con `part`s)
- `lib/core/db/divemate_db.dart` -> abre .ddb, owner, helpers; declara los parts
- `lib/core/db/db_queries.dart` -> lecturas: listar/obtener inmersiones, botellas, nº siguiente
- `lib/core/db/db_profile.dart` -> decode del perfil (profundidad/temperatura)
- `lib/core/db/db_stats.dart` -> sitios de buceo y estadísticas agregadas
- `lib/core/db/db_writes.dart` -> escritura: editar y crear inmersiones
- `lib/core/db/db_import.dart` -> importar inmersiones descargadas (dedupe, Profile4 deco, gas)
- `lib/core/db/db_encode.dart` -> encode de perfiles al formato DiveMate (Profile/Profile2/Profile4)
- `lib/core/db/db_sync.dart` -> fingerprint por buceo + punto de sync (debug) +
  `sampleExtra`/`storeSampleExtra` (PandiveSampleExtra: ppo2/cns/presión/rbt por muestra)
- `lib/core/db/db_create.dart` -> crear una .ddb vacía nueva (esquema DiveMate + buceador)
- `lib/core/db/db_helpers.dart` -> helpers de la librería (parse, uuid, timestamp, mapeo de fila)
- `lib/core/db/db_buddies.dart` -> compañeros (Buddy): listar, crear/renombrar/borrar, buceos por buddy, backfillBuddyIds (enlaza texto Buddy antiguo)
- `lib/core/db/db_buddies_merge.dart` -> mergeBuddies: fusiona varios buddies en uno (reasigna BuddyIDs, borra el resto)
- `lib/core/db/db_sites.dart` -> sitios (Place): obtener/crear/actualizar, find-or-create
- `lib/core/db/db_tanks.dart` -> botellas por buceo, presets "mis botellas", buceos por sitio/buddy
- `lib/core/db/db_merge.dart` -> fusionar inmersiones (perfil concatenado, unión de datos)
- `lib/core/db/db_pending.dart` -> caché de descargados no guardados (reaparecen una vez)
- `lib/core/db/db_dive_types.dart` -> tipos de buceo + plantilla de botellas
- `lib/core/db/db_computers.dart` -> ordenadores de buceo guardados (por MAC)
- `lib/core/db/db_documents.dart` -> documentación (PandiveDocument): CRUD de metadatos (imagen en disco)
- `lib/core/sac.dart` -> cálculo de SAC/RMV (l/min)
- `lib/core/gas_plan.dart` -> planificación de gas: gas necesario, presión final, tiempo máx. (lógica pura)
- `lib/core/export/subsurface_export.dart` -> genera el XML Subsurface (.ssrf)
- `lib/core/import/subsurface_import.dart` -> importa el XML Subsurface (.ssrf) al logbook
- `lib/core/widgets/import_progress.dart` -> diálogo de progreso reutilizable para importar .ssrf
- `lib/core/db/db_import_ext.dart` -> inserta inmersión externa (perfil, botellas, sitio, buddies, tags)
- `lib/core/text/collate.dart` -> comparación alfabética ignorando acentos

### Core · modelos (`models.dart` es el barrel)
- `lib/core/models/models.dart` -> barrel: reexporta todos los modelos
- `lib/core/models/dive.dart` -> inmersión (fila de Logbook)
- `lib/core/models/dive_profile.dart` -> perfil muestreado (tiempos/profundidades/temps)
- `lib/core/models/cylinder.dart` -> botella/mezcla (+ etiqueta de gas)
- `lib/core/models/dive_site.dart` -> punto de buceo con nº de inmersiones
- `lib/core/models/dive_computer_ref.dart` -> ordenador de buceo guardado (MAC+nombre+modelo)
- `lib/core/models/dive_type.dart` -> tipo de buceo (nombre + plantilla de botellas)
- `lib/core/models/document.dart` -> documento del buzo (imagen + caducidad); DiveDoc + DocStatus
- `lib/core/models/downloaded_dive.dart` -> inmersión descargada del ordenador (+ muestras/gases, parse JSON)
- `lib/core/models/logbook_stats.dart` -> estadísticas agregadas

### Core · widgets compartidos
- `lib/core/widgets/profile_chart.dart` -> gráfico de perfil (prof + temp eje dcho, línea táctil)
- `lib/core/widgets/profile_chart_axes.dart` -> ejes y tooltip del gráfico de perfil
- `lib/core/widgets/save_action.dart` -> botón Guardar de AppBar
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
- `lib/features/home/widgets/home_tabs.dart` -> pestañas (IndexedStack); escucha data_revision para refresco blando
- `lib/features/home/widgets/home_drawer.dart` -> menú lateral (Tags/Equipo/Stats + Herramientas/Backup)

### load_db
- `lib/features/load_db/screens/load_db_screen.dart` -> elegir/crear un .ddb o importar .ssrf (con enum DbLoadError)
- `lib/features/load_db/widgets/load_db_buttons.dart` -> botones: abrir .ddb / crear nuevo / importar Subsurface

### tags (etiquetas)
- `lib/features/tags/screens/tags_tab.dart` -> lista de tags (crear/renombrar/borrar, ver buceos)

### backup (copia de seguridad en Drive)
- `lib/features/backup/screens/backup_screen.dart` -> conectar cuenta, backup manual, auto diario, restaurar
- `lib/features/backup/widgets/restore_list.dart` -> lista de backups de Drive para restaurar

### settings
- `lib/features/settings/screens/settings_screen.dart` -> ajustes: idioma, tema, letra, hueco fusión, nocturno, DB
- `lib/features/settings/screens/tools_screen.dart` -> herramientas: importar hashtags, export DDB/Subsurface, papelera, debug sync (desde drawer)
- `lib/features/settings/screens/about_screen.dart` -> acerca de / contacto: descripción + email de reporte (mailto, desde drawer)
- `lib/features/settings/screens/fill_from_ddb_screen.dart` -> rellena buceos propios cruzando con el .ddb de un compañero (sitio/notas/buddies)
- `lib/features/settings/logic/enrich_logbook.dart` -> empareja por fecha/hora y copia datos entre logbooks
- `lib/features/settings/logic/link_buddies_tool.dart` -> herramienta: rellena BuddyIDs de buceos antiguos (texto Buddy sin IDs) para que cuenten
- `lib/features/settings/screens/preview_ddb_screen.dart` -> previsualiza un .ddb en solo lectura
- `lib/features/settings/screens/trash_screen.dart` -> papelera: lista inmersiones borradas (Status=2) y restaura (undelete)
- `lib/features/settings/screens/debug_sync_screen.dart` -> debug: fijar punto de sync y borrar posteriores
- `lib/features/settings/widgets/text_scale_control.dart` -> control de tamaño de letra (slider + −/+)
- `lib/features/settings/widgets/export_tools.dart` -> exportar a DiveMate (.ddb)/Subsurface (.ssrf) e importar de Subsurface
- `lib/features/settings/widgets/language_theme_selectors.dart` -> radios de idioma y tema
- `lib/features/settings/widgets/merge_gap_control.dart` -> control del hueco de fusión (slider + valor visible)
- `lib/features/settings/widgets/night_hours_control.dart` -> franja horaria de inmersión nocturna (desde/hasta)

### buddies (compañeros)
- `lib/features/buddies/screens/buddies_tab.dart` -> lista de compañeros (añadir/renombrar/borrar/fusionar en lote)
- `lib/features/buddies/widgets/buddy_tile.dart` -> fila de compañero (avatar, nº buceos, menú, abre sus buceos)
- `lib/features/buddies/logic/merge_buddies_action.dart` -> diálogo elegir cuál conservar + fusión
- `lib/features/buddies/screens/buddy_picker_screen.dart` -> multi-selección de compañeros (para editar buceo)

### dives (inmersiones)
- `lib/features/dives/screens/dives_screen.dart` -> lista + búsqueda + "Nueva" + selección en lote (borrar/fusionar)
- `lib/features/dives/screens/dive_detail_screen.dart` -> detalle: datos, perfil, botellas, editar
- `lib/features/dives/screens/filtered_dives_screen.dart` -> lista filtrada (sitio/buddy/tag) con acciones en lote + búsqueda interna
- `lib/features/dives/screens/edit_dive_screen.dart` -> editar campos editables
- `lib/features/dives/screens/new_dive_screen.dart` -> formulario de alta manual
- `lib/features/dives/widgets/cylinder_tile.dart` -> tarjeta de botella en el detalle
- `lib/features/dives/widgets/month_grouped_dives.dart` -> lista de buceos por año y mes (colapsable, selección)
- `lib/features/dives/widgets/dive_group_header.dart` -> cabecera de grupo (año/mes) colapsable/seleccionable
- `lib/features/dives/widgets/dive_row.dart` -> fila de buceo estilo DiveMate (nº grande + 2 líneas)
- `lib/features/dives/widgets/add_dive_sheet.dart` -> hoja "añadir": alta manual o transferencia
- `lib/features/dives/widgets/dives_selection_bar.dart` -> barra de selección (stats/fusionar/borrar)
- `lib/features/dives/widgets/dive_editor_form.dart` -> cuerpo común alta/edición (sitio/buddies/tags/tipo/campos/botellas)
- `lib/features/dives/widgets/dive_type_picker_field.dart` -> campo + hoja selectora de tipo de buceo
- `lib/features/dives/widgets/gas_segments.dart` -> cambios de gas (color/etiqueta) para la gráfica ampliada
- `lib/features/dives/widgets/tags_picker_field.dart` -> campo de etiquetas elegidas (chips)
- `lib/features/dives/screens/profile_fullscreen_screen.dart` -> perfil a pantalla completa (apaisado)
- `lib/features/dives/screens/tag_picker_screen.dart` -> multi-selección de etiquetas
- `lib/core/widgets/save_action.dart` -> botón Guardar de AppBar
- `lib/core/db/db_tags.dart` -> etiquetas (tags) y enlace por inmersión
- `lib/features/dives/widgets/dives_action_list.dart` -> lista de buceos con selección en lote + acciones (stats/fusionar/exportar/borrar); usada por el tab y las listas filtradas
- `lib/features/dives/widgets/dive_detail_body.dart` -> cuerpo del detalle por secciones (nº/fecha, sitio, perfil+métricas, gases, deco, botellas)
- `lib/features/dives/widgets/profile_section.dart` -> sección perfil: gráfica compacta + botones compartir / pantalla completa
- `lib/features/dives/logic/share_profile.dart` -> genera PNG del perfil (con sitio) y lo comparte (share_plus)
- `lib/features/dives/widgets/dive_detail_fields.dart` -> celda etiqueta/valor, filas 2/3 columnas, separador de sección
- `lib/features/dives/widgets/dive_form.dart` -> campos escalares editables (+ controllers)
- `lib/features/dives/widgets/site_picker_field.dart` -> campo de sitio elegido
- `lib/features/dives/widgets/buddies_picker_field.dart` -> campo de compañeros elegidos (chips)
- `lib/features/dives/widgets/tanks_editor.dart` -> editor de botellas + SAC
- `lib/features/dives/widgets/tank_edit_sheet.dart` -> hoja para añadir/editar una botella

### plan (planificador de gas)
- `lib/features/plan/screens/plan_dive_screen.dart` -> planificador interactivo: precarga medias, recalcula al vuelo
- `lib/features/plan/widgets/plan_inputs.dart` -> campos (tipo de buceo, RMV, prof, tiempo, volumen, presión inicial, reserva)
- `lib/features/plan/widgets/plan_results.dart` -> resultados (gas, presión final por botella coloreada, margen, tiempo máx.)
- `lib/features/plan/widgets/plan_reserve_field.dart` -> selector de reserva (35/50 bar, tercios 1/3, cuartos 1/2, personalizada)
- `lib/features/plan/widgets/plan_cylinders_field.dart` -> lista editable de botellas (litros + marca reserva/se vacía); PlanCyl

### documents (documentación)
- `lib/features/documents/screens/documents_screen.dart` -> lista con estado de caducidad + alta + export múltiple a PDF
- `lib/features/documents/screens/document_detail_screen.dart` -> ver imagen grande, editar, borrar, compartir (PDF)
- `lib/features/documents/screens/document_edit_screen.dart` -> alta/edición de metadatos (título/notas/caducidad)
- `lib/features/documents/screens/crop_screen.dart` -> recorte propio (crop_your_image): rotar 90°, rectángulo libre, confirmar
- `lib/features/documents/logic/document_import.dart` -> elegir origen (cámara/galería/PDF), render PDF, recorte, guardar
- `lib/features/documents/logic/document_export.dart` -> genera un PDF con los seleccionados y lo comparte
- `lib/features/documents/widgets/document_tile.dart` -> fila (miniatura + título + estado)
- `lib/features/documents/widgets/document_status.dart` -> color/etiqueta por estado de caducidad
- `lib/features/documents/widgets/documents_banner.dart` -> aviso resumen (caducados/por caducar)

### sites (sitios)
- `lib/features/sites/screens/sites_screen.dart` -> lista de sitios: tocar nombre = buceos; ojo = info
- `lib/features/sites/screens/site_info_screen.dart` -> info del sitio (campos, editar/borrar, swipe entre sitios)

### stats (estadísticas)
- `lib/features/stats/screens/stats_screen.dart` -> pestaña de stats globales del logbook
- `lib/features/stats/screens/selection_stats_screen.dart` -> stats solo de una selección de buceos
- `lib/features/stats/widgets/stats_view.dart` -> vista reutilizable (tarjetas + barras, selector año/mes/semana)
- `lib/features/stats/widgets/year_bars.dart` -> PeriodBars: barras etiqueta/valor
- `lib/features/stats/widgets/stats_buckets.dart` -> agrupar fechas por año/mes/semana (ISO)

### dive_computer (ordenador de buceo)
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

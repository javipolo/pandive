# PROJECT_MAP — índice de `lib/`

Lee esto ANTES de buscar con Grep/Glob: te lleva directo al `.dart` exacto.
Mantenlo actualizado al crear/mover/borrar ficheros en `lib/`.

> Nota: la estructura todavía es plana (`lib/ui/`). El objetivo es feature-first
> (`core/` + `features/<nombre>/`); ver reglas en `CLAUDE.md`/`AGENTS.md`.

## Core / Config

- `lib/main.dart` -> arranque, tema, abre la DB, pantalla raíz según estado
- `lib/settings.dart` -> preferencias: escala de texto y ruta de DB activa
- `lib/models.dart` -> modelos: Dive, DiveProfile, Cylinder, DiveSite, LogbookStats
- `lib/db/divemate_db.dart` -> capa SQLite: queries, decode de perfil, escritura
- `lib/services/dive_computer.dart` -> puente libdivecomputer: modelos, escaneo BLE, permisos
- `lib/ui/load_db_screen.dart` -> elegir un fichero .ddb para cargar
- `lib/ui/home_screen.dart` -> shell con pestañas (inmersiones/sitios/stats) y menú
- `lib/ui/profile_chart.dart` -> gráfico de perfil profundidad/temperatura (fl_chart)
- `lib/ui/text_scale_sheet.dart` -> hoja inferior para ajustar tamaño de letra

## Features

### Inmersiones
- `lib/ui/dives_tab.dart` -> lista de inmersiones, búsqueda y botón "Nueva"
- `lib/ui/dive_detail_screen.dart` -> detalle: datos, perfil, botellas, editar
- `lib/ui/edit_dive_screen.dart` -> editar campos editables de una inmersión
- `lib/ui/new_dive_screen.dart` -> formulario de alta manual de inmersión

### Sitios
- `lib/ui/sites_tab.dart` -> lista de puntos de buceo con conteo y enlace a mapa

### Estadísticas
- `lib/ui/stats_tab.dart` -> estadísticas agregadas y barras por año

### Ordenador de buceo
- `lib/ui/dive_computer_screen.dart` -> modelos soportados + lanzar escaneo
- `lib/ui/scan_screen.dart` -> escaneo BLE y lista de ordenadores cercanos

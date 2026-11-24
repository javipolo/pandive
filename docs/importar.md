# Importar inmersiones en Pandive

Desde dónde se puede importar, qué se trae cada fuente y cómo hacerlo.
En todos los casos:

- **No se duplican inmersiones.** Las que ya están en el logbook se saltan, así
  que reimportar el mismo fichero no añade nada. Las que están en la papelera
  no cuentan como "ya están".
- **La numeración se recoloca sola** si la numeración automática está activa
  (Ajustes → Numeración de buceos): las importadas quedan en su sitio
  cronológico.

## Resumen

| Fuente | Dónde | Perfil | Hora | Sitio | Compañeros | Duplicados por |
|---|---|---|---|---|---|---|
| Ordenador de buceo (Bluetooth) | Buceos → **+** → Transferir del ordenador | ✅ | ✅ | — | — | fecha + hora |
| Subsurface (`.ssrf`) | Herramientas → Importar de Subsurface | ✅ | ✅ | ✅ (con GPS) | ✅ | fecha + hora |
| SSI / MySSI (CSV) | Herramientas → Importar de SSI (CSV) | ❌ | solo si se rellenó | ✅ (sin GPS) | ✅ | día + profundidad + duración (+ hora) |
| Otro logbook Pandive/DiveMate (`.ddb`) | Abrir el `.ddb` → Opciones de importación | ✅ | ✅ | ✅ | ✅ | fecha + hora |
| Sitios (JSON) | Herramientas → Importar sitios (JSON) | — | — | ✅ | — | nombre (+ país) |

## Ordenador de buceo (Bluetooth)

**Buceos → botón +** → *Transferir del ordenador*. Elige el ordenador
(Shearwater Peregrine/Perdix, Mares Puck 4 y el resto que soporte
libdivecomputer), descarga y marca qué inmersiones añadir. Trae el perfil
completo, las temperaturas, los gases y los datos de descompresión. Es la fuente más completa.

## Subsurface (`.ssrf`)

- **Herramientas → Importar de Subsurface (.ssrf)** añade las inmersiones al
  logbook actual.
- En la pantalla inicial (sin logbook abierto), *Importar de Subsurface* crea
  un logbook nuevo con ellas.

Trae la fecha y la hora, el sitio (con coordenadas GPS), las notas, los
compañeros, las etiquetas, las botellas (volumen, mezcla y presiones), la
profundidad máxima y media, la temperatura, el modelo de ordenador y el perfil.

## SSI / MySSI (CSV)

SSI deja exportar el logbook digital desde su web en un fichero CSV.

### Cómo hacerlo

1. En la web de MySSI, abre el logbook y expórtalo a **CSV**. Guarda el
   fichero en el móvil o en el PC.
2. En Pandive: **menú lateral → Herramientas → Importar de SSI (CSV)** y
   elige el fichero.
3. Un aviso dice cuántas inmersiones se han importado y cuántas ya estaban
   en el logbook.

Funciona con el CSV en cualquier idioma. La cabecera viene en el idioma de
tu cuenta de SSI, pero Pandive lee las columnas por su posición, no por su
nombre.

### Qué se importa

| Columna del CSV (en español) | En Pandive |
|---|---|
| Inmersión # | Solo para ordenar las del mismo día. El nº final lo pone la numeración de Pandive. |
| Lugar de buceo + País | Sitio de buceo (se reutiliza si ya existe uno con ese nombre; si no, se crea) |
| Fecha / Tiempo | Fecha y, si se rellenó en MySSI, hora de entrada |
| Inmersión de especialidad | Etiqueta (p.ej. "Inmersión desde embarcación") |
| Duración | Duración |
| Profundidad | Profundidad máxima, en metros. Si viene en pies, se convierte. |
| Compañero de buceo / Instructor / Center | Compañeros (uno por cada nombre separado por comas) |
| Tipo de actividad de buceo, Tipo de inmersión | No se importan ("Buceo", "Inmersión de ocio": no aportan nada) |

Formatos aceptados: fechas como `15. Apr 2026`, `3 dic. 2025`, `15.04.2026` o
`2026-04-15`, con o sin hora, y con meses en inglés, castellano, catalán,
euskera, francés, alemán, italiano, portugués y holandés. Duración en
`56 min`, `1 h 5 min` o `1:05`. Profundidad en `21 m (69 ft)` o
`69 ft (21 m)`. Separador `,` o `;`.

### Qué NO se importa (no viene en el CSV)

El CSV de SSI es un resumen. Aunque en MySSI se rellenen más datos, la
exportación **no incluye**:

- perfil de profundidad ni temperatura (no habrá gráfica),
- temperatura del agua o del aire, visibilidad, corriente,
- botella, gas, presiones ni lastre,
- notas o comentarios,
- coordenadas GPS del sitio,
- firmas del instructor o del centro.

Si quieres esos datos, añádelos a mano editando la inmersión. Si tienes el
perfil en otro sitio (el ordenador o Subsurface), impórtalo de ahí: la
inmersión de SSI se detectará como duplicada.

### Cómo se detectan los duplicados

Como el CSV casi nunca trae la hora, no se puede comparar por fecha y hora
como en el resto. Una fila del CSV se da por **ya existente** si ese día hay
una inmersión con:

- profundidad máxima parecida (±2 m), y
- duración parecida (±5 min), y
- si el CSV trae hora, una hora parecida (±60 min).

Así no se duplican las que ya bajaste del ordenador, y reimportar el mismo
CSV no añade nada.

### Hora de las inmersiones sin hora

A las que llegan sin hora se les pone las **12:00**, y +1 minuto a cada una
más del mismo día, en el orden del nº de SSI. Si ese día ya tenías otra
inmersión con hora real, el orden entre ellas puede no ser el verdadero:
corrige la hora editando la inmersión y la numeración se recoloca.

### Limitaciones conocidas

- Si SSI cambiara el orden de las columnas, o las cambiara en algún idioma, la
  importación leería mal los campos. Hasta ahora solo se ha probado con
  exportaciones en castellano.
- Dos inmersiones del mismo día con perfil casi idéntico y sin hora en el CSV
  pueden emparejarse con la que ya tenías y no importarse. Si te falta alguna,
  créala a mano.

## Otro logbook (`.ddb` de Pandive o DiveMate)

Abre un fichero `.ddb` desde otra app (por ejemplo, desde el gestor de archivos
o un adjunto, con *Abrir con… Pandive*). Se previsualiza en solo lectura, y el
botón **Opciones de importación** ofrece:

- **Rellenar mis buceos con este logbook**: completa tus inmersiones con el perfil, el
  ordenador, las botellas y las etiquetas de las mismas inmersiones del
  logbook de un compañero (útil si buceaste sin ordenador). También está en
  Herramientas → *Rellenar buceos desde el logbook de un compañero*.
- **Seleccionar buceos para importar**: copia las inmersiones que elijas,
  con el perfil, el sitio, los compañeros, las etiquetas y las botellas.
  Las que ya tienes salen marcadas y se ignoran.
- **Sustituir mi base de datos por esta**: pasa a usar ese fichero como
  logbook.

## Sitios (JSON)

**Herramientas → Importar sitios (JSON)** importa un fichero exportado desde la lista
de sitios de Pandive. Se puede elegir entre solo actualizar los sitios
existentes o actualizar y además añadir los nuevos.

# Plan: sincronización móvil ↔ PC vía Google Drive

Estado: **borrador para revisar**. Nada implementado salvo el sello de última
escritura (`PandiveMeta.lastWriteUtc`, triggers SQLite), que es la pieza base
de la detección de cambios. Ver "Propuesta recomendada" al final.

## Objetivo

Usar Pandive en el móvil y en el PC con los mismos datos. Los cambios deben
copiarse de un sitio a otro y, si se edita en ambos a la vez (incluso sin
conexión), no corromper ni perder datos. Sin servidor propio: el intercambio va
por el Google Drive que ya usamos para backup.

## Lo que ya tenemos

- Tablas DiveMate (Logbook, Place, Buddy, Tank, Divetype…) con `UUID` y
  `Updated` por fila → identidad estable entre dispositivos y marca temporal.
- Borrado de buceos lógico (`Status=2`): sincroniza bien.
- Integración Drive con auth headless, backups rotativos (10) y worker
  periódico.

## Lo que falta

- Tablas `Pandive*` (tags, viajes, documentos, tipos de buceo, presets, …) sin
  UUID.
- Borrados físicos (`DELETE FROM Buddy/Place/PandiveTag/…`).
- `ID` enteros autoincrementales asignados localmente → dos altas simultáneas
  pueden chocar.
- No todas las escrituras actualizan `Updated` (revisar).

## Por qué un número de versión no basta

Una versión (o el `headRevisionId` de Drive) responde "¿ha cambiado alguien el
fichero desde mi última sync?". Eso resuelve gratis el caso habitual (solo
cambió un lado → subir o bajar el fichero entero). Si cambiaron **los dos**,
solo detecta el conflicto; para resolverlo hace falta fusionar.

## Diseño: fusión de tres vías por fila, Drive como fuente de verdad

1. **Fichero compartido** `pandive-sync.ddb` en la carpeta de Drive (distinto
   de los backups).
2. **Base local**: cada dispositivo guarda una copia de la última versión que
   sincronizó + su `headRevisionId`.
3. **Sincronizar**:
   - Drive sigue en mi revisión base → subo la mía (si cambié algo).
   - Yo no cambié nada desde la base → bajo la de Drive y la adopto.
   - Cambiaron ambos → fusión de tres vías (base, local, remota), tabla a
     tabla, fila a fila por UUID:
     - Fila cambiada en un solo lado → gana ese lado (incluye borrados
       físicos: estaba en la base y ya no está).
     - Cambiada en ambos → fusión por columna; si chocan en la misma columna,
       gana el `Updated` más reciente.
     - Borrada en un lado y editada en el otro → gana la edición (prudente).
     - Fila nueva en ambos con `ID` repetido → renumerar la entrante y
       reescribir sus referencias (`PlaceID`, `BuddyIDs`, tags, botellas…).
       Números de buceo recalculados por fecha.
   - Antes de subir, comprobar otra vez que Drive sigue en la misma revisión;
     si alguien subió entretanto, repetir la fusión. Subir a temporal y
     sustituir (nunca un fichero a medias).
4. **Seguridad**: backup automático antes de aplicar cualquier fusión (ya
   existe la rotación de 10).
5. **Cuándo**: al abrir/volver a la app, unos segundos tras editar
   (debounce), botón manual y worker periódico. Sin red no pasa nada: se
   fusiona después.
6. **Resumen** tras sync: "3 cambios bajados, 1 subido, 1 conflicto resuelto
   (ver)".

Imágenes de documentos: aparte, un fichero por documento en una carpeta de
Drive, comparando por nombre + hash.

## Trabajo previo

- Columna `UUID` en las tablas `Pandive*` (son nuestras; no rompe DiveMate).
  Tablas de unión (`PandiveDiveTag`, `PandiveSiteTag`, `PandiveTripBuddy`…)
  se fusionan como conjuntos de pares de UUID.
- Toda escritura actualiza `Updated`.
- Mapa explícito de claves foráneas (lo usan fusión y renumeración).
- Motor de fusión como lógica pura sobre SQLite, testeado en host con copias
  temporales (como los tests actuales).

## Fases propuestas

1. Prerrequisitos de esquema (UUID en `Pandive*`, `Updated` siempre, mapa FK).
2. Motor de fusión de tres vías + tests exhaustivos (sin Drive).
3. Sync móvil ↔ Drive (fast-forward + fusión + resumen), botón manual.
4. Disparadores automáticos (inicio, debounce, worker).
5. App Linux contra el mismo Drive.

## Descartado

- **Lock file en Drive**: si el móvil se queda offline con el candado, el PC
  queda bloqueado; no resuelve el trabajo sin conexión (barco, isla).
- **Journal de operaciones**: más fino pero mucho más complejo (triggers,
  orden de replay) y sin ventaja real para un buceador con dos dispositivos.

## Decisiones pendientes

1. Choque en el mismo campo: ¿gana el más reciente o preguntar?
2. ¿Sync automática desde el principio o solo manual al inicio?
3. ¿Empezar móvil ↔ Drive y dejar el PC para cuando la app Linux esté lista?

## Propuesta recomendada (2026-11-24)

Dos capas: primero una sync que **nunca pierde datos** (sin fusión), después la
fusión automática para que el caso raro tampoco moleste.

### Capa 1: sync con avance rápido + detección de divergencia

Estado por dispositivo (local, no en la DB): `baseRevision` (revisión de Drive
de la última sync) y `baseStamp` (`lastWriteUtc` local en ese momento).

- **¿Cambié yo?** `lastWriteUtc local > baseStamp` (exacto gracias a los
  triggers: cuenta cualquier escritura).
- **¿Cambió el otro?** `headRevisionId` de `sync/pandive.ddb` en Drive ≠
  `baseRevision`.

| yo | otro | acción |
|----|------|--------|
| no | no | nada |
| sí | no | subir (y volver a comprobar la revisión justo antes de subir) |
| no | sí | bajar y sustituir la local (con backup previo) |
| sí | sí | **divergencia**: no se toca nada automáticamente |

En divergencia: aviso "Hay cambios en el móvil y en este equipo" con *quedarme
con esta* / *quedarme con la otra*. La versión descartada no se borra: va a
los backups con timestamp (recuperable). En la capa 2 se añade *fusionar*.

Cuándo: al abrir y al volver a la app, unos segundos tras editar (debounce),
al pasar a segundo plano y con un botón. Indicador en la barra superior:
✓ sincronizado · ↑ subiendo · ↓ bajando · ⚠ divergencia · ⌀ sin conexión.

**Aviso de uso simultáneo** (no es un candado): cada dispositivo escribe en
Drive un pequeño `presence.json` (dispositivo + hora) mientras está abierto.
Si el otro lo ve reciente: "Pandive está abierto en el móvil (hace 2 min)".
Evita la mayoría de divergencias sin bloquear a nadie sin conexión.

Coste: pequeño (reutiliza auth/subida de backups). Garantía: ninguna edición se
pierde sin que el usuario lo decida.

### Capa 2: fusión de tres vías

La de "Diseño" arriba (por fila/UUID, por columna, edición gana a borrado,
renumerar IDs). Necesita los prerrequisitos de esquema. La base para fusionar
es la copia local guardada en la última sync (añadirla en la capa 1 desde el
principio para tenerla disponible).

### Respuesta propuesta a las decisiones pendientes

1. Choque en el mismo campo: gana el más reciente, y se lista en el resumen.
2. Capa 1 automática desde el principio (es segura por diseño); fusión manual
   ("Fusionar") hasta que la capa 2 tenga muchas horas de tests.
3. Móvil y Linux a la vez: el login de Google ya funciona en ambos.

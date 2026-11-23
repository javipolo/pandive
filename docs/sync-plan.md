# Plan: sincronización móvil ↔ PC vía Google Drive

Estado: **borrador para revisar**. Nada implementado.

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

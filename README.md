# Pandive 🐼🤿

Logbook de buceo para Android. Reemplazo propio y mantenible de DiveMate.

Nombre visible: **Pandive**. Identificador de aplicación: **`org.drslump.pandive`** (dominio `drslump.org`). Logo: oso panda buceando.

**Accesibilidad**: la app usa **tipografía grande por defecto** (pensada para presbicia, uso sin gafas). El tamaño de letra es configurable a más pequeño para quien lo prefiera.

---

## Qué es

App móvil de registro de inmersiones (un solo buceador, una base de datos por buceador):

- Importa inmersiones directamente del ordenador de buceo por Bluetooth (Shearwater Peregrine/Perdix, Mares Puck 4, y el resto que soporte `libdivecomputer`).
- Almacena todo en un único archivo SQLite (fácil de respaldar y mover).
- Exporta a formato Subsurface.
- Copia de seguridad / restauración en Google Drive (sube y baja el archivo SQLite completo).
- Sin gestión de fotos (decisión de diseño).

### Arquitectura (resumen)

- **UI + lógica**: Flutter (Dart). Desarrollo rápido, SQLite (`drift`) y Google Drive (`googleapis`) bien soportados.
- **Descarga de inmersiones**: `libdivecomputer` (C), compilada con el NDK de Android, envuelta en un **plugin nativo Android** (Kotlin + JNI). El plugin maneja el BLE por la API de Android y le pasa a libdivecomputer su I/O; Flutter solo recibe las inmersiones ya parseadas.
- **Por qué Flutter y no nativo puro**: la parte dura (C + BLE + threading) cuesta lo mismo en cualquier framework —hay que compilar C con el NDK y puentear BLE igualmente— pero Flutter ahorra mucho en UI, base de datos y Drive.

---

## Requisitos del entorno de desarrollo

Probado en **Fedora 44** (Linux). Para otras distros, cambia el gestor de paquetes.

| Componente | Para qué |
|---|---|
| JDK 17 | Gradle / build de Android |
| Flutter SDK (canal stable) | Framework de la app |
| Android SDK (platform-tools, platform 35, build-tools 35) | Compilar/instalar APK, `adb` |
| Android NDK | Compilar `libdivecomputer` (C) a `.so` |
| clang, cmake, ninja, autotools, pkg-config | Build nativo de libdivecomputer |
| Device Android físico | **Imprescindible**: el emulador no tiene Bluetooth LE |

> **Android Studio NO es necesario.** Es un IDE gráfico; todo el flujo funciona desde línea de comandos con las *command-line tools*. El único extra que aporta (emulador gráfico) no sirve aquí porque el BLE requiere un dispositivo real.

---

## Instalación paso a paso

### 1. Dependencias del sistema

```bash
sudo dnf install -y java-17-openjdk-devel git unzip clang cmake ninja-build \
  autoconf automake libtool pkgconf-pkg-config
```

### 2. Flutter SDK

```bash
git clone https://github.com/flutter/flutter.git -b stable ~/flutter
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```

### 3. Android SDK (command-line tools)

Descarga "Command line tools only" (Linux) desde <https://developer.android.com/studio#command-line-tools-only>.

```bash
mkdir -p ~/Android/cmdline-tools
# descomprime el zip de modo que quede en: ~/Android/cmdline-tools/latest/
unzip ~/Downloads/commandlinetools-linux-*.zip -d /tmp/cmdline
mv /tmp/cmdline/cmdline-tools ~/Android/cmdline-tools/latest

echo 'export ANDROID_HOME=$HOME/Android' >> ~/.bashrc
echo 'export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Instala componentes. Google deprecó `sdkmanager` en favor del nuevo **`android` CLI** (aunque `sdkmanager` todavía funciona).

Con el nuevo `android` CLI (recomendado). Es una descarga aparte; instalador oficial en Linux:

```bash
# revisa el script antes de ejecutarlo si quieres:
#   curl -fsSL https://dl.google.com/android/cli/latest/linux_x86_64/install.sh -o /tmp/android-cli.sh && less /tmp/android-cli.sh && bash /tmp/android-cli.sh
curl -fsSL https://dl.google.com/android/cli/latest/linux_x86_64/install.sh | bash

android sdk install platform-tools platforms/android-35 build-tools/35.0.0 ndk/27.2.12479018
# sin paso --licenses: las acepta automaticamente
```

Alternativa con el antiguo `sdkmanager` (muestra un warning de deprecacion, pero funciona):

```bash
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;27.2.12479018"
sdkmanager --licenses
```

### 4. Enlazar Flutter con el SDK y verificar

```bash
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor          # resuelve lo que aparezca en rojo
```

> **JDK para Gradle**: el build de Android (Gradle) **no soporta Java 25**. Necesita **JDK 17**. Si tu Java por defecto es más nuevo, instala el 17 y apunta Flutter a él:
> ```bash
> sudo dnf install -y java-17-openjdk-devel    # o temurin-17-jdk
> flutter config --jdk-dir /usr/lib/jvm/java-17-temurin-jdk   # ajusta a tu ruta
> ```
> Comprueba la ruta real con: `dirname $(dirname $(readlink -f $(which javac)))` tras seleccionar el 17, o busca en `/usr/lib/jvm/`.

### 5. Dispositivo físico

El emulador **no vale** (sin Bluetooth LE). Usa un móvil Android real:

1. Ajustes → Acerca del teléfono → pulsa 7 veces en "Número de compilación" para activar Opciones de desarrollador.
2. Opciones de desarrollador → activa **Depuración USB**.
3. Conecta por USB y comprueba:

```bash
adb devices   # debe listar tu dispositivo
```

---

## Compilar e instalar la app

> Disponible una vez exista el proyecto Flutter en este repositorio.

```bash
flutter pub get                 # instalar dependencias Dart
flutter run                     # compilar + instalar + ejecutar en el device conectado
flutter build apk --debug       # APK de depuración (sideload directo)
flutter build apk --release     # APK de release (requiere keystore propio)
flutter install                 # instalar el último APK en el device
```

### APK de release (firmado)

El `--release` necesita una clave de firma propia. Generación de keystore y configuración de `key.properties` se documentará cuando lleguemos a esa fase.

---

## Compilar libdivecomputer

El código fuente vive en `vendor/libdivecomputer/` (clon de git).

**Build nativo** (Linux, para probar/depurar en el ordenador):

```bash
cd vendor/libdivecomputer
autoreconf --install            # solo la primera vez (clon de git)
./configure --prefix=/tmp/ldc-install
make -j$(nproc)
# CLI de prueba: lista computers soportados
LD_LIBRARY_PATH=src/.libs ./examples/.libs/dctool list
```

**Cross-compile para Android** (requiere NDK):

```bash
export ANDROID_NDK=$HOME/Android/ndk/27.2.12479018
./scripts/build-libdivecomputer-android.sh
# salida: build/android/<abi>/install/lib/libdivecomputer.so
```

Se compila **sin** libusb/hidapi: en Android el transporte es BLE, implementado desde Kotlin y conectado al I/O personalizado de libdivecomputer.

## Estado del proyecto

Por fases (ver plan de desarrollo):

- [~] **Fase 0** — De-riesgo `libdivecomputer`:
  - [x] Soporte de los 3 computers confirmado (código + runtime `dctool`): Peregrine, Perdix, **Mares Puck 4** (modelo `0x35`). Los tres por **BLE** (único transporte a implementar).
  - [x] Build nativo en Linux OK (valida fuente + build system).
  - [x] Script de cross-compile Android listo: `scripts/build-libdivecomputer-android.sh`.
  - [x] Cross-compile con NDK OK: `.so` para arm64-v8a, armeabi-v7a, x86_64 (Android 24).
  - [x] API de I/O personalizado (`dc_custom_open` + `DC_TRANSPORT_BLE`) confirmada: el puente BLE Kotlin↔libdivecomputer es viable (patrón de Subsurface).
  - [ ] Prototipo de descarga BLE en device real (= inicio del plugin nativo, Fase 2).
- [x] **Fase 1** — App base (sin migración: abre el `.ddb` directamente):
  - [x] Capa DB (`lib/db/divemate_db.dart`): abre `.ddb`, owner, lista dives, botellas, decode de perfil (validado contra `divemate-cli`).
  - [x] Pantalla de carga de `.ddb` (file picker), lista de inmersiones, detalle con perfil (`fl_chart`) y botellas.
  - [x] Tema de fuente grande por defecto + ajuste de tamaño (accesibilidad).
  - [x] Compila a APK; tests unitarios + contra la DB real pasan.
  - [x] Navegación por pestañas: Inmersiones / Sitios / Estadísticas.
  - [x] Búsqueda y filtros en listas.
  - [x] Estadísticas agregadas (validadas contra `divemate-cli`).
  - [x] Edición de campos de una inmersión (escritura en el `.ddb`, respeta UUID/Status y marca `Updated`).
  - [x] Alta manual de inmersiones nuevas (genera Number/UUID, botella opcional).
- [ ] **Fase 2** — Importar del ordenador de buceo (plugin nativo + UI de escaneo/descarga).
- [ ] **Fase 3** — Export Subsurface + backup/restore Google Drive.
- [ ] **Fase 4** — Pulido: estadísticas, sitios, buddies, equipo, certificaciones.

---

## Notas técnicas

- **Base de datos**: Pandive usa el **mismo formato SQLite `.ddb` que DiveMate** (decisión de diseño: sin migración, abre la DB existente tal cual). Tablas relevantes: `Logbook` (inmersiones), `Place` (sitios), `Tank` (botellas), `Buddy`, `Divetype`, `Equipment`, `Brevets`. "Simplificar" = ocultar en la UI los campos no usados, no cambiar el esquema.
- **Compatibilidad con `divemate-cli`**: existe una CLI Python (`../divemate-cli`) que consulta/estadística la misma `.ddb`. Mantener el formato la deja funcionando sobre la DB de Pandive.
- **Un solo buceador**: la `.ddb` puede tener varios `DiverID` (demo/imports); el owner es el de más inmersiones. Pandive opera solo sobre el owner.
- **Perfiles**: en `Logbook.Profile` (profundidad, 12 chars/muestra, 4 primeros = decímetros) y `Profile2` (temperatura, 11 chars/muestra, 4 primeros = centi-°C); `ProfileInt` = intervalo en segundos. Decode portado de `divemate-cli`.
- **Mares Puck 4**: soporte confirmado en `libdivecomputer` (modelo `0x35`, BLE).

---

## Backup en Google Drive (configuración OAuth, una vez)

El backup/restore usa `google_sign_in` con el scope **`drive.file`** (no sensible,
sin verificación de Google): la app solo ve los ficheros que ella crea, en una
carpeta visible "Pandive Backups". Para que funcione en el móvil hay que crear un
cliente OAuth de Android en Google Cloud (no se embebe ninguna clave en el APK;
Android lo resuelve por paquete + SHA-1):

1. [Google Cloud Console](https://console.cloud.google.com/) → crea un proyecto.
2. **APIs y servicios → Biblioteca** → habilita **Google Drive API**.
3. **Pantalla de consentimiento OAuth** → tipo *External* → añade tu cuenta de
   Google como **usuario de prueba** (así no hace falta verificación).
4. **Credenciales → Crear → ID de cliente OAuth → Android**:
   - Paquete: `org.drslump.pandive`
   - SHA-1 de la **clave de firma release** (la que usa el APK release, ver
     `android/key.properties`). Recupéralo con:
     ```
     keytool -list -v -keystore android/app/pandive-release.jks -alias pandive
     ```
     (El build release se firma con esta clave; es el SHA-1 que hay que
     registrar. Puedes añadir varios SHA-1 al mismo cliente: p.ej. el debug
     `~/.android/debug.keystore` alias `androiddebugkey`, pass `android`, si
     alguna vez quieres probar un build debug.)
5. **Credenciales → Crear → ID de cliente OAuth → Aplicación web**: crea uno
   (nombre libre, sin orígenes). Copia su **Client ID** (`…apps.googleusercontent.com`).
   `google_sign_in` lo exige en Android como `serverClientId`. Guárdalo en:
   ```
   echo 'TU_WEB_CLIENT_ID.apps.googleusercontent.com' > android/gdrive_client_id.txt
   ```
   (fichero no versionado; `make apk`/`apk-release` lo inyecta como
   `--dart-define=GDRIVE_SERVER_CLIENT_ID`). Sin él, Conectar falla con
   "ServerClientID must be provided".
6. Instala el APK, Ajustes → Copia de seguridad (Google Drive) → Conectar.

> La firma release vive en `android/app/pandive-release.jks` + `android/key.properties`
> (ambos **gitignored**, no se versionan). Si cambias de clave, añade el nuevo
> SHA-1 al cliente OAuth y reinstala la app (firma distinta → hay que desinstalar
> la anterior).

El backup automático diario se dispara al abrir la app si han pasado >24 h y la
DB cambió. Se guarda `latest.ddb` + copias con timestamp (se conservan las 10
más recientes). Al restaurar, por defecto se ofrece `latest`.

# Pandive 🐼🤿

Logbook de buceo para Android. Reemplazo propio y mantenible de DiveMate.

Nombre interno/paquete: `pandive`. Nombre visible: *Panda Dive*. Logo: oso panda buceando.

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

Instala componentes:

```bash
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"
sdkmanager "ndk;27.2.12479018"
sdkmanager --licenses   # acepta todas
```

### 4. Enlazar Flutter con el SDK y verificar

```bash
flutter config --android-sdk "$ANDROID_HOME"
flutter doctor          # resuelve lo que aparezca en rojo
```

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

## Estado del proyecto

Por fases (ver plan de desarrollo):

- [ ] **Fase 0** — De-riesgo: compilar `libdivecomputer` con NDK y prototipo de descarga BLE (Peregrine) en device real.
- [ ] **Fase 1** — App base: esquema `drift`, migración del `DiveMate.ddb` actual (~860 inmersiones + perfiles), lista/detalle/gráfico/edición.
- [ ] **Fase 2** — Importar del ordenador de buceo (plugin nativo + UI de escaneo/descarga).
- [ ] **Fase 3** — Export Subsurface + backup/restore Google Drive.
- [ ] **Fase 4** — Pulido: estadísticas, sitios, buddies, equipo, certificaciones.

---

## Notas técnicas

- **Base de datos origen**: `DiveMate.ddb` (SQLite). Tablas relevantes: `Logbook` (inmersiones), `Place` (sitios), `Tank` (botellas), `Buddy`, `Divetype`, `Equipment`, `Brevets`. Los perfiles de inmersión viven en campos `Profile*` como hex empaquetado.
- **Modelo de datos nuevo**: un único buceador; se descartan tablas/campos multi-buceador y `Pictures`.
- **Mares Puck 4**: modelo reciente. Hay que verificar soporte exacto en la versión actual de `libdivecomputer` antes de darlo por hecho.

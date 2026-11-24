# Pandive — acciones de desarrollo.
# Flutter no está en el PATH de shells no-interactivos en esta máquina, así que
# lo resolvemos aquí. Todo es sobreescribible: `make apk FLUTTER=/otro/flutter`.

FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/javi/git/flutter/bin/flutter)
ANDROID_HOME ?= $(HOME)/javi/Android
ANDROID_NDK ?= $(ANDROID_HOME)/ndk/27.2.12479018

export ANDROID_HOME
export ANDROID_NDK
export PATH := $(dir $(FLUTTER)):$(ANDROID_HOME)/platform-tools:$(PATH)

# OAuth Web client ID para Google Drive (serverClientId). Se lee de
# android/gdrive_client_id.txt (no versionado) o de la variable de entorno.
GDRIVE_CLIENT_ID ?= $(strip $(shell cat android/gdrive_client_id.txt 2>/dev/null))
# OAuth iOS client ID (flutter_appauth, refresh token para backup de fondo).
GDRIVE_NATIVE_CLIENT_ID ?= $(strip $(shell cat android/gdrive_native_client_id.txt 2>/dev/null))
DART_DEFINES := $(if $(GDRIVE_CLIENT_ID),--dart-define=GDRIVE_SERVER_CLIENT_ID=$(GDRIVE_CLIENT_ID),)
DART_DEFINES += $(if $(GDRIVE_NATIVE_CLIENT_ID),--dart-define=GDRIVE_NATIVE_CLIENT_ID=$(GDRIVE_NATIVE_CLIENT_ID),)
# App Linux: OAuth client "Desktop app" (mismo proyecto Google Cloud) para el
# login de Google. linux/gdrive_desktop_client_{id,secret}.txt (no versionados).
GDRIVE_DESKTOP_CLIENT_ID ?= $(strip $(shell cat linux/gdrive_desktop_client_id.txt 2>/dev/null))
GDRIVE_DESKTOP_CLIENT_SECRET ?= $(strip $(shell cat linux/gdrive_desktop_client_secret.txt 2>/dev/null))
LINUX_DEFINES := $(if $(GDRIVE_DESKTOP_CLIENT_ID),--dart-define=GDRIVE_DESKTOP_CLIENT_ID=$(GDRIVE_DESKTOP_CLIENT_ID),)
LINUX_DEFINES += $(if $(GDRIVE_DESKTOP_CLIENT_SECRET),--dart-define=GDRIVE_DESKTOP_CLIENT_SECRET=$(GDRIVE_DESKTOP_CLIENT_SECRET),)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Muestra esta ayuda
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: ## Instala dependencias Dart (flutter pub get)
	$(FLUTTER) pub get

.PHONY: run
run: ## Compila, instala y lanza en el device conectado
	$(FLUTTER) run

.PHONY: apk
apk: ## Genera APK de depuración (sideload)
	$(FLUTTER) build apk --debug $(DART_DEFINES)

.PHONY: apk-release
apk-release: ## Genera APK de release arm64 (sideload)
	# --no-tree-shake-icons: incluye la fuente de iconos completa. El recorte
	# producía una OTF que en algunos Android no se parsea y deja todos los
	# iconos como cuadrados grises (tofu): hamburguesa, barra inferior, FAB...
	$(FLUTTER) build apk --release --target-platform android-arm64 \
		--no-tree-shake-icons $(DART_DEFINES)

APK := build/app/outputs/flutter-apk/app-debug.apk

.PHONY: install
install: ## Instala el APK de depuración en el device conectado
	$(FLUTTER) install --debug

.PHONY: install-apk
install-apk: ## Instala app-debug.apk con adb (donde esté el móvil)
	adb install -r $(APK)

.PHONY: apk-path
apk-path: ## Imprime la ruta absoluta del APK de depuración
	@echo "$(CURDIR)/$(APK)"

.PHONY: test
test: ## Ejecuta los tests (unitarios + contra la DB real si existe)
	$(FLUTTER) test

.PHONY: analyze
analyze: ## Análisis estático
	$(FLUTTER) analyze

.PHONY: fmt
fmt: ## Formatea el código Dart
	$(FLUTTER) format lib test

.PHONY: devices
devices: ## Lista devices/emuladores detectados
	$(FLUTTER) devices

.PHONY: clean
clean: ## Limpia artefactos de build (Flutter + Gradle), conserva los .so nativos
	$(FLUTTER) clean
	@rm -rf .dart_tool build \
		android/.gradle android/build android/app/build \
		android/app/.cxx
	@echo "Limpio (jniLibs nativos conservados; usa 'make distclean' para borrarlos)"

.PHONY: distclean
distclean: clean ## clean + borra libdivecomputer compilado (.so + headers); fuerza re-cross-compile
	@rm -rf android/app/src/main/jniLibs \
		android/app/src/main/cpp/include/libdivecomputer linux/ldc
	@echo "Artefactos nativos borrados: reconstruye con 'make dc-libs'"

.PHONY: ldc-android
ldc-android: ## Cross-compila libdivecomputer para Android (NDK)
	./scripts/build-libdivecomputer-android.sh

.PHONY: dc-libs
dc-libs: ldc-android ## Cross-compila y copia .so + headers al proyecto Android
	@for abi in arm64-v8a armeabi-v7a x86_64; do \
		mkdir -p android/app/src/main/jniLibs/$$abi; \
		cp build/android/$$abi/install/lib/libdivecomputer.so android/app/src/main/jniLibs/$$abi/; \
	done
	@rm -rf android/app/src/main/cpp/include/libdivecomputer
	@cp -r build/android/arm64-v8a/install/include/libdivecomputer android/app/src/main/cpp/include/
	@echo "libdivecomputer .so + headers copiados a android/app/src/main/"

.PHONY: ldc-linux
ldc-linux: ## Compila libdivecomputer estática para la app Linux (linux/ldc/)
	./scripts/build-libdivecomputer-linux.sh
	@mkdir -p linux/ldc
	@cp build/linux-ldc/install/lib/libdivecomputer.a linux/ldc/
	@echo "libdivecomputer.a copiada a linux/ldc/"

.PHONY: linux
linux: ## Compila la app Linux (release)
	$(FLUTTER) build linux --release $(LINUX_DEFINES)

.PHONY: run-linux
run-linux: ## Compila y lanza la app Linux (debug) con el client de Google
	$(FLUTTER) run -d linux $(LINUX_DEFINES)

# Instalación de la app Linux (el bundle de `make linux`, sin recompilar).
#   make install-linux                          -> en tu home (~/.local, ~/.local/opt/pandive)
#   sudo make install-linux PREFIX=/usr/local   -> sistema (/usr/local, /opt/pandive)
PREFIX ?= $(HOME)/.local
APPDIR ?= $(if $(filter $(HOME)/%,$(PREFIX)),$(PREFIX)/opt/pandive,/opt/pandive)
LINUX_BUNDLE := build/linux/x64/release/bundle
APP_ID := org.drslump.pandive
ICON_SIZES := 16 22 24 32 48 64 128 256 512

.PHONY: check-appdir
check-appdir:
	@case "$(APPDIR)" in */pandive) ;; *) echo "APPDIR debe acabar en /pandive: '$(APPDIR)'"; exit 1;; esac

.PHONY: install-linux
install-linux: check-appdir ## Instala la app Linux (PREFIX=~/.local; sudo ... PREFIX=/usr/local)
	@test -x $(LINUX_BUNDLE)/pandive || { echo "Falta el bundle: ejecuta 'make linux' antes (sin sudo)"; exit 1; }
	rm -rf "$(DESTDIR)$(APPDIR)"
	mkdir -p "$(DESTDIR)$(APPDIR)"
	cp -r $(LINUX_BUNDLE)/. "$(DESTDIR)$(APPDIR)/"
	install -d "$(DESTDIR)$(PREFIX)/bin"
	ln -sf "$(APPDIR)/pandive" "$(DESTDIR)$(PREFIX)/bin/pandive"
	for n in $(ICON_SIZES); do \
		install -Dm644 linux/packaging/icons/$$n.png \
			"$(DESTDIR)$(PREFIX)/share/icons/hicolor/$${n}x$$n/apps/$(APP_ID).png"; \
	done
	sed 's|@APPDIR@|$(APPDIR)|' linux/packaging/$(APP_ID).desktop | \
		install -Dm644 /dev/stdin "$(DESTDIR)$(PREFIX)/share/applications/$(APP_ID).desktop"
	-@gtk-update-icon-cache -q -t -f "$(DESTDIR)$(PREFIX)/share/icons/hicolor" 2>/dev/null
	-@update-desktop-database -q "$(DESTDIR)$(PREFIX)/share/applications" 2>/dev/null
	@echo "Pandive instalado en $(APPDIR) (lanzador: $(PREFIX)/bin/pandive)"

.PHONY: uninstall-linux
uninstall-linux: check-appdir ## Desinstala la app Linux (mismo PREFIX que al instalar)
	rm -rf "$(DESTDIR)$(APPDIR)"
	rm -f "$(DESTDIR)$(PREFIX)/bin/pandive" \
		"$(DESTDIR)$(PREFIX)/share/applications/$(APP_ID).desktop"
	for n in $(ICON_SIZES); do \
		rm -f "$(DESTDIR)$(PREFIX)/share/icons/hicolor/$${n}x$$n/apps/$(APP_ID).png"; \
	done
	-@gtk-update-icon-cache -q -t -f "$(DESTDIR)$(PREFIX)/share/icons/hicolor" 2>/dev/null
	-@update-desktop-database -q "$(DESTDIR)$(PREFIX)/share/applications" 2>/dev/null
	@echo "Pandive desinstalado (los datos de cada usuario en su home se conservan)"

.PHONY: doctor
doctor: ## flutter doctor
	$(FLUTTER) doctor

# Pandive — acciones de desarrollo.
# Flutter no está en el PATH de shells no-interactivos en esta máquina, así que
# lo resolvemos aquí. Todo es sobreescribible: `make apk FLUTTER=/otro/flutter`.

FLUTTER ?= $(shell command -v flutter 2>/dev/null || echo $(HOME)/javi/git/flutter/bin/flutter)
ANDROID_HOME ?= $(HOME)/javi/Android
ANDROID_NDK ?= $(ANDROID_HOME)/ndk/27.2.12479018

export ANDROID_HOME
export ANDROID_NDK
export PATH := $(dir $(FLUTTER)):$(ANDROID_HOME)/platform-tools:$(PATH)

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
	$(FLUTTER) build apk --debug

.PHONY: apk-release
apk-release: ## Genera APK de release (requiere keystore)
	$(FLUTTER) build apk --release

.PHONY: install
install: ## Instala el último APK en el device conectado
	$(FLUTTER) install

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
clean: ## Limpia artefactos de build de Flutter
	$(FLUTTER) clean

.PHONY: ldc-android
ldc-android: ## Cross-compila libdivecomputer para Android (NDK)
	./scripts/build-libdivecomputer-android.sh

.PHONY: doctor
doctor: ## flutter doctor
	$(FLUTTER) doctor

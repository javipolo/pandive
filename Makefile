# Pandive — development tasks.
# Prerequisites: `flutter` on the PATH and ANDROID_HOME pointing to the Android
# SDK (only for the Android targets). See docs/DEVELOPMENT.md.

FLUTTER ?= flutter
NDK_VERSION := 27.2.12479018
ANDROID_NDK ?= $(ANDROID_HOME)/ndk/$(NDK_VERSION)
export ANDROID_NDK

ifdef ANDROID_HOME
export PATH := $(ANDROID_HOME)/platform-tools:$(PATH)
endif

# OAuth Web client ID for Google Drive (serverClientId). Read from
# android/gdrive_client_id.txt (not versioned) or from the environment variable.
GDRIVE_CLIENT_ID ?= $(strip $(shell cat android/gdrive_client_id.txt 2>/dev/null))
# OAuth iOS client ID (flutter_appauth, refresh token for background backup).
GDRIVE_NATIVE_CLIENT_ID ?= $(strip $(shell cat android/gdrive_native_client_id.txt 2>/dev/null))
DART_DEFINES := $(if $(GDRIVE_CLIENT_ID),--dart-define=GDRIVE_SERVER_CLIENT_ID=$(GDRIVE_CLIENT_ID),)
DART_DEFINES += $(if $(GDRIVE_NATIVE_CLIENT_ID),--dart-define=GDRIVE_NATIVE_CLIENT_ID=$(GDRIVE_NATIVE_CLIENT_ID),)
# Linux app: OAuth "Desktop app" client (same Google Cloud project) for the
# Google login. linux/gdrive_desktop_client_{id,secret}.txt (not versioned).
GDRIVE_DESKTOP_CLIENT_ID ?= $(strip $(shell cat linux/gdrive_desktop_client_id.txt 2>/dev/null))
GDRIVE_DESKTOP_CLIENT_SECRET ?= $(strip $(shell cat linux/gdrive_desktop_client_secret.txt 2>/dev/null))
LINUX_DEFINES := $(if $(GDRIVE_DESKTOP_CLIENT_ID),--dart-define=GDRIVE_DESKTOP_CLIENT_ID=$(GDRIVE_DESKTOP_CLIENT_ID),)
LINUX_DEFINES += $(if $(GDRIVE_DESKTOP_CLIENT_SECRET),--dart-define=GDRIVE_DESKTOP_CLIENT_SECRET=$(GDRIVE_DESKTOP_CLIENT_SECRET),)

# Versioning: the git tag is the source of truth (pubspec's version is a
# placeholder). versionName = `git describe` without the leading "v"
# (1.1.0 on a tagged commit, 1.1.0-3-gabc1234[-dirty] on a dev build);
# versionCode = commit count, so it always grows and Android accepts updates.
GIT_DESCRIBE := $(shell git describe --tags --always --dirty 2>/dev/null)
BUILD_NAME := $(patsubst v%,%,$(GIT_DESCRIBE))
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null)
VERSION_FLAGS := $(if $(BUILD_NAME),--build-name=$(BUILD_NAME),) \
	$(if $(BUILD_NUMBER),--build-number=$(BUILD_NUMBER),)
RELEASE_TAG := $(shell git describe --tags --exact-match 2>/dev/null)
RELEASES_DIR := releases

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: ## Install Dart dependencies (flutter pub get)
	$(FLUTTER) pub get

.PHONY: require-android
require-android:
	@test -n "$(ANDROID_HOME)" || { echo "ANDROID_HOME is not set: export it with the path to the Android SDK"; exit 1; }

.PHONY: run
run: require-android ## Build (release), install and launch on the connected device
	$(FLUTTER) run --release $(VERSION_FLAGS) $(DART_DEFINES)

.PHONY: apk
apk: require-android ## Build an arm64 release APK (sideload)
	# --no-tree-shake-icons: bundles the full icon font. Tree-shaking
	# produced an OTF that some Android devices fail to parse, leaving all
	# icons as grey squares (tofu): hamburger, bottom bar, FAB...
	$(FLUTTER) build apk --release --target-platform android-arm64 \
		--no-tree-shake-icons $(VERSION_FLAGS) $(DART_DEFINES)

.PHONY: apk-release
apk-release: apk ## Alias of apk

APK := build/app/outputs/flutter-apk/app-release.apk

# Release flow: commit, `git tag vX.Y.Z`, `make release`. Refuses to build
# from a dirty tree or from a commit without an exact tag.
.PHONY: release
release: require-android ## Build the APK of the tagged HEAD into releases/PanDive-Android-<tag>.apk
	@git diff --quiet HEAD || { echo "Uncommitted changes: commit or stash them first"; exit 1; }
	@test -n "$(RELEASE_TAG)" || { echo "HEAD has no tag: run 'git tag vX.Y.Z' first"; exit 1; }
	$(MAKE) apk
	@mkdir -p $(RELEASES_DIR)
	cp $(APK) $(RELEASES_DIR)/PanDive-Android-$(RELEASE_TAG).apk
	@echo "Release $(RELEASE_TAG) (versionCode $(BUILD_NUMBER)): $(RELEASES_DIR)/PanDive-Android-$(RELEASE_TAG).apk"

.PHONY: version
version: ## Print the versionName / versionCode a build would get
	@echo "versionName=$(BUILD_NAME) versionCode=$(BUILD_NUMBER)"

# --user 0: install only for the phone's owner (not in a work profile or a
# Secure Folder / second space). Without other profiles it's the default anyway.
.PHONY: install
install: require-android ## Install the release APK on the connected device (owner user)
	adb install -r --user 0 $(APK)

.PHONY: install-apk
install-apk: install ## Alias of install

.PHONY: apk-path
apk-path: ## Print the absolute path of the release APK
	@echo "$(CURDIR)/$(APK)"

.PHONY: test
test: ## Run the tests (unit + against the real DB if present)
	$(FLUTTER) test

.PHONY: analyze
analyze: ## Static analysis
	$(FLUTTER) analyze

.PHONY: fmt
fmt: ## Format the Dart code
	$(FLUTTER) format lib test

.PHONY: devices
devices: ## List detected devices/emulators
	$(FLUTTER) devices

.PHONY: clean
clean: ## Clean build artifacts (Flutter + Gradle), keeps the native .so files
	$(FLUTTER) clean
	@rm -rf .dart_tool build \
		android/.gradle android/build android/app/build \
		android/app/.cxx
	@echo "Cleaned (native jniLibs kept; use 'make distclean' to remove them)"

.PHONY: distclean
distclean: clean ## clean + remove compiled libdivecomputer (.so + headers); forces a re-cross-compile
	@rm -rf android/app/src/main/jniLibs \
		android/app/src/main/cpp/include/libdivecomputer linux/ldc
	@echo "Native artifacts removed: rebuild with 'make dc-libs'"

.PHONY: ldc-android
ldc-android: require-android ## Cross-compile libdivecomputer for Android (NDK)
	./scripts/build-libdivecomputer-android.sh

.PHONY: dc-libs
dc-libs: ldc-android ## Cross-compile and copy .so + headers into the Android project
	@for abi in arm64-v8a armeabi-v7a x86_64; do \
		mkdir -p android/app/src/main/jniLibs/$$abi; \
		cp build/android/$$abi/install/lib/libdivecomputer.so android/app/src/main/jniLibs/$$abi/; \
	done
	@rm -rf android/app/src/main/cpp/include/libdivecomputer
	@cp -r build/android/arm64-v8a/install/include/libdivecomputer android/app/src/main/cpp/include/
	@echo "libdivecomputer .so + headers copied to android/app/src/main/"

.PHONY: ldc-linux
ldc-linux: ## Build static libdivecomputer for the Linux app (linux/ldc/)
	./scripts/build-libdivecomputer-linux.sh
	@mkdir -p linux/ldc
	@cp build/linux-ldc/install/lib/libdivecomputer.a linux/ldc/
	@echo "libdivecomputer.a copied to linux/ldc/"

.PHONY: linux
linux: ## Build the Linux app (release)
	$(FLUTTER) build linux --release $(VERSION_FLAGS) $(LINUX_DEFINES)

.PHONY: run-linux
run-linux: ## Build (release) and launch the Linux app with the Google client
	$(FLUTTER) run --release -d linux $(VERSION_FLAGS) $(LINUX_DEFINES)

# Linux app install (the `make linux` bundle, without rebuilding).
#   make install-linux                          -> in your home (~/.local, ~/.local/opt/pandive)
#   sudo make install-linux PREFIX=/usr/local   -> system-wide (/usr/local, /opt/pandive)
PREFIX ?= $(HOME)/.local
APPDIR ?= $(if $(filter $(HOME)/%,$(PREFIX)),$(PREFIX)/opt/pandive,/opt/pandive)
LINUX_BUNDLE := build/linux/x64/release/bundle
APP_ID := org.drslump.pandive
ICON_SIZES := 16 22 24 32 48 64 128 256 512

.PHONY: check-appdir
check-appdir:
	@case "$(APPDIR)" in */pandive) ;; *) echo "APPDIR must end in /pandive: '$(APPDIR)'"; exit 1;; esac

.PHONY: install-linux
install-linux: check-appdir ## Install the Linux app (PREFIX=~/.local; sudo ... PREFIX=/usr/local)
	@test -x $(LINUX_BUNDLE)/pandive || { echo "Missing bundle: run 'make linux' first (without sudo)"; exit 1; }
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
	@echo "Pandive installed in $(APPDIR) (launcher: $(PREFIX)/bin/pandive)"

.PHONY: uninstall-linux
uninstall-linux: check-appdir ## Uninstall the Linux app (same PREFIX as when installing)
	rm -rf "$(DESTDIR)$(APPDIR)"
	rm -f "$(DESTDIR)$(PREFIX)/bin/pandive" \
		"$(DESTDIR)$(PREFIX)/share/applications/$(APP_ID).desktop"
	for n in $(ICON_SIZES); do \
		rm -f "$(DESTDIR)$(PREFIX)/share/icons/hicolor/$${n}x$$n/apps/$(APP_ID).png"; \
	done
	-@gtk-update-icon-cache -q -t -f "$(DESTDIR)$(PREFIX)/share/icons/hicolor" 2>/dev/null
	-@update-desktop-database -q "$(DESTDIR)$(PREFIX)/share/applications" 2>/dev/null
	@echo "Pandive uninstalled (each user's data in their home is kept)"

.PHONY: doctor
doctor: ## flutter doctor
	$(FLUTTER) doctor

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing from android/key.properties (not versioned). If missing, falls back to debug.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "org.drslump.pandive"
    compileSdk = 36 // file_picker and other plugins require >= 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (java.time APIs on minSdk<26).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.drslump.pandive"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24 // Android 7.0; stable BLE for the dive computer download
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            // ABIs we have prebuilt libdivecomputer for.
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }

        // AppAuth redirect scheme (flutter_appauth): reversed scheme of the
        // iOS OAuth client, derived from the id in android/gdrive_native_client_id.txt
        // (not versioned). Must be lowercase.
        val nativeClientIdFile = rootProject.file("gdrive_native_client_id.txt")
        val nativeClientId =
            if (nativeClientIdFile.exists()) nativeClientIdFile.readText().trim() else ""
        manifestPlaceholders["appAuthRedirectScheme"] =
            if (nativeClientId.isNotEmpty())
                "com.googleusercontent.apps." +
                    nativeClientId.removeSuffix(".apps.googleusercontent.com")
            else "com.googleusercontent.apps.pandive-placeholder"
    }

    // JNI wrapper over libdivecomputer (src/main/cpp).
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    // lintVital breaks in release (javadoc parser bug in a dependency);
    // no necesitamos el lint de release.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Our own release signing (android/key.properties); if missing, debug.
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // R8 with our keep rules: keeps the methods the native side
            // calls via JNI (BleConnection.bleRead/bleWrite, DiveComputer.*).
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

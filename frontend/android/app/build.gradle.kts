plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.SmaranSaathi.smaran_saathi"
    // Pinned rather than taken from `flutter.*`: flutter_tts and the
    // androidx.core the Firebase plugins pull in both require API 36, and the
    // Firebase / connectivity / path_provider plugins all want NDK 27.
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.SmaranSaathi.smaran_saathi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_tts needs 24 and firebase_auth needs 23; Flutter's own
        // default is still 21, so the floor is pinned here.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // fllama bundles a native llama.cpp .so per ABI. Virtually every real
        // device this app targets is arm64 — shipping armeabi-v7a/x86_64 too
        // would multiply the size of the one bundled part of the app that is
        // actually size-sensitive, for devices nobody has.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}


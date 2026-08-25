import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material. Absent during ordinary development, written by CI
// from repository secrets before a release build.
//
// It is not committed and must never be: the keystore is what proves an APK came
// from us, and an installed Android app can only be upgraded by a build carrying
// the same signature. Leak it and someone else can ship an "update" to our
// users; lose it and we cannot ship one ourselves.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.krybk.accent"
    // Pinned rather than flutter.compileSdkVersion, which resolves to 36 while
    // flutter_secure_storage requires 37 — the build fails at
    // checkReleaseAarMetadata otherwise. compileSdk only decides which APIs are
    // available at compile time; minSdk and targetSdk are untouched, so the set
    // of devices that can install the app does not change.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.krybk.accent"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml. With split APKs Flutter adds 1000 * ABI_VERSION
        // automatically, so each architecture gets a distinct, ordered code.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Declared only when the material is present, so a plain `flutter build
        // --debug` on a fresh clone still works with no setup.
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Falling back to the debug key would be worse than failing: a
            // debug-signed APK installs fine, so nobody notices until the first
            // real update, which then cannot be installed over it at all —
            // Android refuses an upgrade whose signature changed. Users would
            // have to uninstall and lose their server profiles.
            //
            // So: no key.properties, no release build.
            signingConfig = signingConfigs.findByName("release")
                ?: throw GradleException(
                    "Release signing is not configured. Provide android/key.properties " +
                        "(see key.properties.example). Refusing to sign a release with " +
                        "the debug key: it would make every future update uninstallable."
                )

            isMinifyEnabled = true
            isShrinkResources = true
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

flutter {
    source = "../.."
}

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
            // Left null when there is no key.properties. Nothing signs a release
            // by accident as a result: the task-graph check below stops the build
            // before it gets that far. The check has to live there rather than
            // here — see the comment on it.
            signingConfig = signingConfigs.findByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// No key.properties, no release build.
//
// Falling back to the debug key would be worse than failing: a debug-signed APK
// installs fine, so nobody notices until the first real update, which then
// cannot be installed over it at all — Android refuses an upgrade whose
// signature changed. Users would have to uninstall and lose their server
// profiles.
//
// Checked against the task graph rather than inside the `release` buildType,
// because that block is evaluated during configuration for *every* invocation.
// Throwing from there failed `flutter build apk --debug` too, which is the build
// CI runs — so the guard for releases broke the check that never signs anything.
val releaseTask = Regex("^(assemble|bundle|package)\\w*Release$")
gradle.taskGraph.whenReady {
    if (keystoreProperties.isEmpty() && allTasks.any { releaseTask.matches(it.name) }) {
        throw GradleException(
            "Release signing is not configured. Provide android/key.properties " +
                "(see key.properties.example). Refusing to sign a release with " +
                "the debug key: it would make every future update uninstallable."
        )
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

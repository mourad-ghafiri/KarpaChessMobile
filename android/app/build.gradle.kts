import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing reads android/key.properties (storeFile, storePassword,
// keyAlias, keyPassword). The file and the keystore it names are secrets:
// both are git-ignored, and docs/RELEASE.md says how to create them. Without
// the file, release builds fall back to the debug key so `flutter run
// --release` keeps working locally — such a build is NOT uploadable, and
// Gradle says so.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()
val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.karpachess.karpachess"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.karpachess.karpachess"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Ships native debug symbols inside the App Bundle, so Play
            // Console can symbolicate a crash in the Stockfish library (they
            // are uploaded, never delivered to devices). FULL, not
            // SYMBOL_TABLE: SYMBOL_TABLE keeps every non-debug section, and
            // the engine's .rodata is its ~98 MB embedded net, so each ABI's
            // symbol file came out the size of the library. FULL keeps only
            // the debug sections (~16 MB) and adds file and line numbers.
            ndk {
                debugSymbolLevel = "FULL"
            }
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                if (buildingRelease) {
                    logger.warn(
                        "android/key.properties not found: this release build is " +
                            "signed with the DEBUG key and cannot be uploaded to " +
                            "Google Play. See docs/RELEASE.md."
                    )
                }
                signingConfigs.getByName("debug")
            }
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

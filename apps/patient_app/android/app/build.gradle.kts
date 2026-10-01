import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Create android/key.properties (never commit it) with:
//   storePassword=...
//   keyPassword=...
//   keyAlias=upload
//   storeFile=/absolute/or/relative/path/to/upload-keystore.jks
// When the file is absent, release builds fall back to the debug key so that
// `flutter build apk --release` still works on any machine (NOT uploadable to Play).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.carecompanion.patient"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.carecompanion.patient"
        // Health Connect (`health` plugin) requires API 26+.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // versionCode / versionName come from `version:` in pubspec.yaml
        // (e.g. 1.0.0+1 -> versionName 1.0.0, versionCode 1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Network security config: the strict file (cleartext only to the emulator
        // host / localhost) unless this is a DEMO build made with
        // -PdemoCleartext=true (or ORG_GRADLE_PROJECT_demoCleartext=true), which
        // allows plain HTTP to a PC on the LAN (runtime "Server address" setting).
        val demoCleartext = project.findProperty("demoCleartext")?.toString()?.toBoolean() == true
        manifestPlaceholders["networkSecurityConfig"] =
            if (demoCleartext) "@xml/network_security_config_demo" else "@xml/network_security_config"
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            signingConfig =
                if (hasReleaseKeystore) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            // R8: shrink + obfuscate code and strip unused resources.
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

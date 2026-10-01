import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (never committed; see README).
// When it is absent the release build falls back to the debug key so CI and
// local `flutter build apk --release` still work. Such builds can't be
// uploaded to Play.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.carecompanion.doctor"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.carecompanion.doctor"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml `version: x.y.z+code`.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("android/key.properties not found: signing the release build with the DEBUG key.")
                signingConfigs.getByName("debug")
            }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

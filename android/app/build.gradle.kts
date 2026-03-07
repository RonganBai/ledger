import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.ledger_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.ledger_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val keyAliasValue = keystoreProperties.getProperty("keyAlias")
            val keyPasswordValue = keystoreProperties.getProperty("keyPassword")
            val storeFileValue = keystoreProperties.getProperty("storeFile")
            val storePasswordValue = keystoreProperties.getProperty("storePassword")
            create("release") {
                keyAlias = requireNotNull(keyAliasValue) { "Missing keyAlias in android/key.properties" }
                keyPassword = requireNotNull(keyPasswordValue) { "Missing keyPassword in android/key.properties" }
                storeFile = rootProject.file(requireNotNull(storeFileValue) { "Missing storeFile in android/key.properties" })
                storePassword = requireNotNull(storePasswordValue) { "Missing storePassword in android/key.properties" }
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}

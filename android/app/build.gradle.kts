plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Use environment variables for GitHub Actions
val keyAliasString = System.getenv("KEY_ALIAS") ?: keystoreProperties["keyAlias"] as String?
val keyPasswordString = System.getenv("KEY_PASSWORD") ?: keystoreProperties["keyPassword"] as String?
val storePasswordString = System.getenv("STORE_PASSWORD") ?: keystoreProperties["storePassword"] as String?
val storeFilePath = System.getenv("STORE_FILE") ?: keystoreProperties["storeFile"] as String?

android {
    namespace = "com.just_look_at_now.m_team"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.just_look_at_now.m_team"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            println(">>> storeFile inside signingConfig = $storeFilePath")
            this.keyAlias = keyAliasString
            this.keyPassword = keyPasswordString
            if (storeFilePath != null) {
                this.storeFile = file(storeFilePath)
            }
            this.storePassword = storePasswordString
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

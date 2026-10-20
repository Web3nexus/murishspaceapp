import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Release signing is read from android/key.properties, which is never committed.
// See android/key.properties.example and android/RELEASE_SIGNING.md.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.murihspace.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.murihspace.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Release builds are signed with the upload keystore from key.properties.
            // They never fall back to the debug key; see the check below.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Stop release packaging before any task runs if the signing setup is missing,
// instead of producing a build signed with the debug key. Debug builds are unaffected.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any { task ->
        task.project == project && Regex("(assemble|bundle|install)Release").matches(task.name)
    }
    if (releaseRequested) {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Release signing is not configured: android/key.properties is missing. " +
                    "Copy android/key.properties.example to android/key.properties, fill in your " +
                    "keystore details, then retry. See android/RELEASE_SIGNING.md."
            )
        }
        val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Release signing is incomplete: android/key.properties is missing " +
                    "${missing.joinToString(", ")}. See android/RELEASE_SIGNING.md."
            )
        }
    }
}

flutter {
    source = "../.."
}

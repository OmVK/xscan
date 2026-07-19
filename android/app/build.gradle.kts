import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

val hasValidSigning = keystoreProperties["storeFile"] != null &&
        (keystoreProperties["storeFile"] as String).isNotEmpty()

android {
    namespace = "com.xscan.xscan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as? String ?: ""
            keyPassword = keystoreProperties["keyPassword"] as? String ?: ""
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as? String ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.xscan.xscan"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasValidSigning) {
                signingConfigs.getByName("release")
            } else {
                // Fall back to debug signing for development builds only.
                // For production releases, key.properties MUST be configured.
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}


// Validate signing configuration for release builds.
gradle.projectsEvaluated {
    tasks.withType<com.android.build.gradle.tasks.PackageApplication>().configureEach {
        doFirst {
            if (!hasValidSigning) {
                logger.warn(
                    "WARNING: No valid signing configuration found in key.properties. " +
                    "The release APK/AAB will be signed with the debug key. " +
                    "This is NOT suitable for production releases or Play Store uploads."
                )
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

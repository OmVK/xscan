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

// CI runners have no keystore; their release artifacts are throwaway builds.
val isCi = System.getenv("CI") == "true"

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
            } else if (isCi) {
                // CI artifacts are unsigned debug-key placeholders; production
                // releases must go through a machine with key.properties.
                signingConfigs.getByName("debug")
            } else {
                // Refuse to silently produce debug-signed "release" APKs
                // locally — this masks missing keystore setup.
                signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            // Trim native binaries to phone-only ABIs for the release APK.
            // Debug/test builds keep every ABI (incl. x86_64 emulators).
            ndk {
                abiFilters += listOf("arm64-v8a", "armeabi-v7a")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}


// Validate signing configuration for release builds.
gradle.projectsEvaluated {
    tasks.withType<com.android.build.gradle.tasks.PackageApplication>().configureEach {
        doFirst {
            if (!hasValidSigning && !isCi) {
                throw GradleException(
                    "Cannot build a release APK: no keystore in android/key.properties.\n" +
                    "Create android/key.properties with storeFile/keyAlias/keyPassword/storePassword " +
                    "or use 'flutter run' / debug builds for development.\n" +
                    "Refusing to silently sign a release build with the debug key."
                )
            }
            if (!hasValidSigning && isCi) {
                logger.warn(
                    "CI build: no keystore configured — release artifact is signed " +
                    "with the debug key and is NOT suitable for Play Store upload."
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

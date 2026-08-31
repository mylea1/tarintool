plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.File
import java.util.Base64

val kiloReleaseKeystorePath = System.getenv("KILO_ANDROID_KEYSTORE")?.trim()?.takeIf { it.isNotEmpty() }
val kiloReleaseKeystoreBase64 = System.getenv("KILO_ANDROID_KEYSTORE_B64")?.trim()?.takeIf { it.isNotEmpty() }
val kiloReleaseStorePassword = System.getenv("KILO_ANDROID_STORE_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
val kiloReleaseKeyAlias = System.getenv("KILO_ANDROID_KEY_ALIAS")?.trim()?.takeIf { it.isNotEmpty() }
val kiloReleaseKeyPassword = System.getenv("KILO_ANDROID_KEY_PASSWORD")?.trim()?.takeIf { it.isNotEmpty() }
val releaseBuildRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

val missingKiloReleaseVariables = buildList {
    if (kiloReleaseStorePassword == null) add("KILO_ANDROID_STORE_PASSWORD")
    if (kiloReleaseKeyAlias == null) add("KILO_ANDROID_KEY_ALIAS")
    if (kiloReleaseKeyPassword == null) add("KILO_ANDROID_KEY_PASSWORD")
    if (kiloReleaseKeystorePath == null && kiloReleaseKeystoreBase64 == null) {
        add("KILO_ANDROID_KEYSTORE or KILO_ANDROID_KEYSTORE_B64")
    }
}

if (releaseBuildRequested && missingKiloReleaseVariables.isNotEmpty()) {
    throw GradleException(
        "Release signing is required. Missing ${missingKiloReleaseVariables.joinToString()}. " +
            "Set the KILO_ANDROID_* variables; release builds never use the debug key."
    )
}

val kiloReleaseKeystoreFile: File? = when {
    kiloReleaseKeystorePath != null -> file(kiloReleaseKeystorePath)
    kiloReleaseKeystoreBase64 != null -> {
        val generatedPath = layout.buildDirectory.dir("kilo-signing").get().asFile
            .resolve("kilo-release.jks")
        generatedPath.parentFile.mkdirs()
        try {
            generatedPath.writeBytes(Base64.getDecoder().decode(kiloReleaseKeystoreBase64))
        } catch (error: IllegalArgumentException) {
            throw GradleException("KILO_ANDROID_KEYSTORE_B64 is not valid Base64.", error)
        }
        generatedPath
    }
    else -> null
}

if (releaseBuildRequested && kiloReleaseKeystoreFile?.isFile != true) {
    throw GradleException(
        "Release signing keystore was not found at ${kiloReleaseKeystoreFile?.absolutePath ?: "<unset>"}. " +
            "Check KILO_ANDROID_KEYSTORE or provide KILO_ANDROID_KEYSTORE_B64."
    )
}

val kiloReleaseCredentialsReady = kiloReleaseKeystoreFile?.isFile == true &&
    kiloReleaseStorePassword != null && kiloReleaseKeyAlias != null && kiloReleaseKeyPassword != null

android {
    namespace = "com.kilostrength.kilo_strength"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kilostrength.kilo_strength"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "market"
    productFlavors {
        create("cn") {
            dimension = "market"
            // Keep the existing application id so this remains update-compatible.
            applicationId = "com.kilostrength.kilo_strength"
            resValue("string", "app_name", "形域")
        }
        create("global") {
            dimension = "market"
            applicationIdSuffix = ".global"
            resValue("string", "app_name", "KILO Strength")
        }
    }

    signingConfigs {
        if (kiloReleaseCredentialsReady) {
            create("kiloRelease") {
                storeFile = kiloReleaseKeystoreFile
                storePassword = kiloReleaseStorePassword
                keyAlias = kiloReleaseKeyAlias
                keyPassword = kiloReleaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // A release variant is never allowed to fall back to the debug key.
            // The guard above fails the build before Gradle can produce a
            // misleading, non-upgradable APK.
            if (kiloReleaseCredentialsReady) {
                signingConfig = signingConfigs.getByName("kiloRelease")
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

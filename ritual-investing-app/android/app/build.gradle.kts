plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val ritualAuth0Domain = providers.gradleProperty("auth0Domain").orNull
    ?: providers.environmentVariable("AUTH0_DOMAIN").orNull
    ?: "localhost"
val ritualAuth0Scheme = providers.gradleProperty("auth0Scheme").orNull
    ?: "https"
val ritualLinkHost = providers.gradleProperty("ritualLinkHost").orNull
    ?: providers.environmentVariable("RITUAL_LINK_HOST").orNull
    ?: "just-build-this.app"

android {
    namespace = "com.ritualinvesting.ritual_investing_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ritualinvesting.ritual_investing_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // HTTPS App Links are the production default. Passing
        // -Pauth0Scheme=com.ritualinvesting.ritual_investing_app retains
        // Auth0's custom-scheme rollback.
        manifestPlaceholders["auth0Domain"] = ritualAuth0Domain
        manifestPlaceholders["auth0Scheme"] = ritualAuth0Scheme
        manifestPlaceholders["ritualLinkHost"] = ritualLinkHost
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

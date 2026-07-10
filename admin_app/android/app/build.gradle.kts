import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
val posTerminalMinSdk = 23
val isPosTerminalBuild =
    providers.gradleProperty("posTerminalBuild").orNull.toBoolean() ||
        System.getenv("POS_TERMINAL_BUILD").orEmpty().let {
            it.equals("true", ignoreCase = true) || it == "1"
        }

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else if (isReleaseBuildRequested) {
    throw GradleException(
        "Release signing is not configured. Create android/key.properties and an upload keystore before building release."
    )
}

android {
    namespace = "com.terabyteai.foodmania.posadmin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring lets us use newer java.time APIs on older
        // Android versions — required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.terabyteai.foodmania.posadmin"
        minSdk = if (isPosTerminalBuild) posTerminalMinSdk else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Shrink + obfuscate to keep the dex/method footprint small. Keep
            // rules live in proguard-rules.pro (Sunmi/Facebook/printer plugins
            // use reflection/AIDL).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("com.facebook.android:facebook-login:18.2.3")
    implementation("com.sunmi:printerlibrary:1.0.15")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

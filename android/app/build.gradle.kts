// android/app/build.gradle.kts
// Z.A.R.A. v9.0 — Android Build Config
// Wake Word: Energy VAD + Whisper (no Vosk dependency needed)

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace  = "com.mahakal.zara"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mahakal.zara"
        minSdk        = 24
        targetSdk     = 35
        versionCode   = 1
        versionName   = "9.0.0"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            isMinifyEnabled     = false
            isShrinkResources   = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        release {
            isMinifyEnabled   = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ── Vosk — Offline Wake Word Detection ("Hii Zara", "Sunna") ─────────────
    // Maven Central pe available: com.alphacephei:vosk-android:0.3.75
    // Model: https://alphacephei.com/vosk/models → vosk-model-small-en-in-0.4
    // Place unzipped as: android/app/src/main/assets/model/
    implementation("com.alphacephei:vosk-android:0.3.75")
}

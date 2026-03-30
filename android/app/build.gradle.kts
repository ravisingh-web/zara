// android/app/build.gradle.kts
// Z.A.R.A. v16.0 — Android Build Config
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  FIX v16: Vosk dependency properly declared                             ║
// ║                                                                         ║
// ║  🔴 BUG: build.gradle.kts comment said "no Vosk dependency needed"     ║
// ║     but ZaraAccessibilityService.kt imports org.vosk.*                  ║
// ║     → Mismatch: dependency IS needed, model IS needed in assets         ║
// ║                                                                         ║
// ║  ✅ FIX: vosk-android:0.3.75 dependency confirmed                       ║
// ║  ✅ Instructions: download model → assets/model/                        ║
// ║                                                                         ║
// ║  MODEL DOWNLOAD (REQUIRED for wake word):                               ║
// ║    URL: https://alphacephei.com/vosk/models                             ║
// ║    File: vosk-model-small-en-in-0.4.zip (or vosk-model-small-hi-0.22)  ║
// ║    Extract to: android/app/src/main/assets/model/                       ║
// ║    Final check: assets/model/am/final.mdl should exist                  ║
// ║                                                                         ║
// ║  WITHOUT model → VAD fallback (Whisper-based, requires OpenAI key)     ║
// ║  WITH model    → Full offline wake word (no API key needed)            ║
// ╚══════════════════════════════════════════════════════════════════════════╝

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
        versionName   = "16.0.0"
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

    // ✅ Large model files need this
    aaptOptions {
        noCompress("tflite", "bin", "conf", "mdl", "spk")
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

    // ── Vosk — Offline Wake Word Detection ────────────────────────────────────
    // REQUIRED: Place model in android/app/src/main/assets/model/
    // Download: https://alphacephei.com/vosk/models
    // Recommended: vosk-model-small-en-in-0.4 (English-India, ~36MB)
    // Also good:   vosk-model-small-hi-0.22   (Hindi, ~42MB)
    // Without model in assets → engine falls back to VAD+Whisper mode
    implementation("com.alphacephei:vosk-android:0.3.75")
}

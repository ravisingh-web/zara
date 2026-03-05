// android/app/build.gradle.kts
// Z.A.R.A. v8.0 — Android Build Config
// ✅ targetSdk 35  — Android 15 ready, "keeps stopping" FIXED
// ✅ compileSdk 35 — aligned (was 36 vs targetSdk 33 = mismatch crash)
// ✅ coreLibraryDesugaringEnabled = true (just_audio + record need this)
// ✅ Java 17 / Kotlin 17
// ✅ minSdk 24 — covers 99%+ active devices

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace  = "com.mahakal.zara"
    compileSdk = 35
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
        versionName   = "8.0.0"
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
    // Coroutines — required by ZaraAccessibilityService (replaces Thread.sleep)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

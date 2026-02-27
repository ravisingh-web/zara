plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mahakal.zara"
    
    // ✅ Explicit SDK versions for Guardian Mode compatibility
    compileSdk = 34  // Android 14 (required for foreground service types)
    ndkVersion = "26.1.10909125"  // Flutter-compatible NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ✅ Enable desugaring for Java 8+ APIs on older Android
        isCoreLibraryDesugaringEnabled = true
    }

    compilerOptions {
        jvmTarget.set(JavaVersion.VERSION_17).toString()
        // ✅ Enable coroutines & suspend functions
        freeCompilerArgs += "-opt-in=kotlinx.coroutines.ExperimentalCoroutinesApi"
    }

    defaultConfig {
        applicationId = "com.mahakal.zara"
        minSdk = 24  // Android 7.0+ (required for AccessibilityService features)
        targetSdk = 34  // Android 14
        versionCode = 1
        versionName = "1.0.0"
        
        // ✅ Multi-ABI support for Termux compatibility
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
        
        // ✅ Manifest placeholders for dynamic permissions
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.mahakal.zara.auth"
        )
    }

    // ✅ ABI Splits for smaller APKs (Termux-friendly)
    splits {
        abi {
            isEnable = true
            reset()            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = false  // Set true if you want a single APK for all ABIs
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        release {
            isMinifyEnabled = true  // Enable code shrinking
            isShrinkResources = true  // Remove unused resources
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // ✅ Release signing config (replace with your keystore)
            signingConfig = signingConfigs.getByName("debug") // TODO: Replace with release keystore
        }
    }

    // ✅ Product Flavors for different build variants
    flavorDimensions += "version"
    productFlavors {
        create("standard") {
            dimension = "version"
            applicationIdSuffix = ""
            versionNameSuffix = ""
        }
        create("guardian") {
            dimension = "version"
            applicationIdSuffix = ".guardian"
            versionNameSuffix = "-guardian"
            // Extra permissions for enhanced Guardian Mode
            manifestPlaceholders += mapOf(
                "guardianMode" to "true"
            )
        }
    }

    // ✅ Packaging options for native libraries
    packaging {
        resources {            excludes += listOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/license.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/notice.txt",
                "META-INF/ASL2.0",
                "META-INF/*.kotlin_module"
            )
        }
        jniLibs {
            // ✅ Keep only required ABIs to reduce APK size
            useLegacyPackaging = false
        }
    }
}

// ✅ Flutter integration
flutter {
    source = "../.."
}

dependencies {
    // ✅ Core desugaring for Java 8+ APIs on Android 7-9
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ✅ Kotlin stdlib
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    
    // ✅ AndroidX Core libraries
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.fragment:fragment-ktx:1.6.2")
    
    // ✅ Camera2 API for intruder photo capture
    implementation("androidx.camera:camera-camera2:1.3.1")
    implementation("androidx.camera:camera-lifecycle:1.3.1")
    implementation("androidx.camera:camera-view:1.3.1")
    implementation("androidx.camera:camera-extensions:1.3.1")
    
    // ✅ Location services for GPS tracking
    implementation("com.google.android.gms:play-services-location:21.1.0")
    
    // ✅ WorkManager for background tasks (Guardian Mode monitoring)
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    
    // ✅ Notification compatibility    implementation("androidx.core:core-ktx:1.12.0")
    
    // ✅ Lifecycle components
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    
    // ✅ Security crypto for key storage (optional, for API key encryption)
    // implementation("androidx.security:security-crypto:1.1.0-alpha06")
    
    // ✅ Testing dependencies
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}

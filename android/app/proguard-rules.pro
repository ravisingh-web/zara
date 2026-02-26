# android/app/proguard-rules.pro
# Z.A.R.A. — ProGuard/R8 Rules for Release Builds
# ✅ Flutter • Camera2 • Location • Accessibility • Kotlin Coroutines

# ========== FLUTTER (Required) ==========
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedded.** { *; }

# ========== KOTLIN (Required) ==========
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**
-keep class kotlin.coroutines.** { *; }

# ========== ANDROIDX (Required) ==========
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**
-keep class android.arch.** { *; }
-dontwarn android.arch.**

# ========== CAMERA2 API (For Intruder Photos) ==========
-keep class android.hardware.camera2.** { *; }
-keep interface android.hardware.camera2.** { *; }
-keep class androidx.camera.** { *; }
-keep interface androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ========== LOCATION SERVICES (For GPS Tracking) ==========
-keep class com.google.android.gms.location.** { *; }
-keep interface com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.location.**
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.common.**

# ========== ACCESSIBILITY SERVICE (For Guardian Mode) ==========
-keep class android.accessibilityservice.** { *; }
-keep interface android.accessibilityservice.** { *; }
-keep class android.view.accessibility.** { *; }
-keep interface android.view.accessibility.** { *; }-dontwarn android.accessibilityservice.**

# ========== WORKMANAGER (For Background Tasks) ==========
-keep class androidx.work.** { *; }
-keep interface androidx.work.** { *; }
-dontwarn androidx.work.**

# ========== SHARED PREFERENCES (For API Key Storage) ==========
-keep class android.content.SharedPreferences { *; }
-keep interface android.content.SharedPreferences { *; }

# ========== HTTP/NETWORK (For API Calls) ==========
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }
-dontwarn retrofit2.**

# ========== GSON/JSON (If Used) ==========
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.GsonSerializer { *; }
-keep class * implements com.google.gson.GsonDeserializer { *; }
-dontwarn com.google.gson.**

# ========== PERMISSION HANDLER ==========
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ========== URL LAUNCHER ==========
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# ========== PATH PROVIDER ==========
-keep class io.flutter.plugins.pathprovider.** { *; }
-dontwarn io.flutter.plugins.pathprovider.**

# ========== PROVIDER (State Management) ==========
-keep class com.mahakal.zara.features.zara_engine.providers.** { *; }
-keep class com.mahakal.zara.** extends android.app.Activity { *; }
-keep class com.mahakal.zara.** extends android.app.Service { *; }
-keep class com.mahakal.zara.** extends android.content.BroadcastReceiver { *; }

# ========== Z.A.R.A. SPECIFIC (Keep All App Classes) ==========
-keep class com.mahakal.zara.** { *; }
-keep class com.mahakal.zara.* { *; }
-dontwarn com.mahakal.zara.**
# Keep all model classes
-keep class com.mahakal.zara.features.zara_engine.models.** { *; }
-keep class com.mahakal.zara.core.constants.** { *; }
-keep class com.mahakal.zara.core.enums.** { *; }
-keep class com.mahakal.zara.services.** { *; }
-keep class com.mahakal.zara.features.hologram_ui.** { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep Native Methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Custom Views
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep View Constructors for XML inflation
-keepclassmembers public class * extends android.view.View {    void set*(***);
    *** get*();
}

# Keep R (Resource) classes
-keep class **.R$* { *; }
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ========== OPTIMIZATIONS ==========
# Enable aggressive optimization for smaller APK
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
-repackageclasses ''
-verbose

# ========== DON'T WARN (Suppress Common Warnings) ==========
-dontwarn sun.misc.**
-dontwarn java.beans.**
-dontwarn javax.naming.**
-dontwarn javax.security.**
-dontwarn java.awt.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# ========== END OF PROGUARD RULES ==========
# Z.A.R.A. — Zenith Autonomous Reasoning Array
# Made with ❤️ for Sir

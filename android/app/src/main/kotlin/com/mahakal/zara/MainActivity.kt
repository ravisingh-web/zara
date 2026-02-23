// android/app/src/main/kotlin/com/mahakal/zara/MainActivity.kt
// Z.A.R.A. — Main Activity with Accessibility Platform Channel

package com.mahakal.zara

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mahakal.zara/accessibility"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAccessibilityEnabled" -> {
                    val isEnabled = ZaraAccessibilityService.instance != null
                    result.success(isEnabled)
                }
                
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                
                "resetWrongPasswordCount" -> {
                    ZaraAccessibilityService.instance?.resetWrongPasswordCount()
                    result.success(null)
                }
                
                "getWrongPasswordCount" -> {
                    // This would need to be stored in SharedPreferences for persistence
                    result.success(0)
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set method channel reference in Accessibility Service
        ZaraAccessibilityService.setMethodChannel(
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        )
    }
    
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings
            val intent = Intent(Settings.ACTION_SETTINGS)
            startActivity(intent)
        }
    }
}

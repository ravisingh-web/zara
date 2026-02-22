// lib/main.dart
// Z.A.R.A. — Main Entry Point
// ✅ API Keys Auto-Load from SharedPreferences (No Hardcoding)
// ✅ Holographic UI Theme • Dark Mode • RobotoMono Font
// ✅ Provider Setup • Accessibility Service Ready

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Core imports
import 'core/constants/api_keys.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';

// Feature imports
import 'features/zara_engine/providers/zara_provider.dart';
import 'features/hologram_ui/screens/zara_home_screen.dart';

// Services imports (for initialization)
import 'services/accessibility_service.dart';
import 'services/ai_api_service.dart';

/// Application entry point
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode (mobile-first design)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Enable edge-to-edge display (modern Android)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // Set system bar colors to match app theme
  await SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 🔐 Initialize API Keys from SharedPreferences
  // This loads Gemini, Qwen, Llama keys + voice settings
  await ApiKeys.initialize();

  // 🔧 Initialize Services (Accessibility, AI, etc.)
  await _initializeServices();

  // Debug logging (removed in production via kDebugMode)
  if (kDebugMode) {
    debugPrint('🤖 Z.A.R.A. Core Initializing...');
    await Future.delayed(const Duration(milliseconds: 800));
    
    debugPrint('🔐 API Status:');
    debugPrint('  • Gemini: ${ApiKeys.status['gemini'] ?? false ? "✓" : "✗"}');
    debugPrint('  • Qwen: ${ApiKeys.status['qwen'] ?? false ? "✓" : "✗"}');
    debugPrint('  • Llama: ${ApiKeys.status['llama'] ?? false ? "✓" : "✗"}');
    debugPrint('  • Voice: ${ApiKeys.voiceName} (${ApiKeys.languageCode})');
    
    if (ApiKeys.isConfigured) {
      debugPrint('✅ All APIs Ready — Full features enabled');
    } else {
      debugPrint('⚠️ Missing APIs: ${ApiKeys.missing.join(", ")}');
      debugPrint('💡 User can configure in Settings screen');
    }
  }

  // Launch the app
  runApp(const ZaraApp());
}

/// Initialize all background services
Future<void> _initializeServices() async {
  try {
    // Initialize Accessibility Service bridge (for Guardian Mode + Auto-Type)
    await AccessibilityService().initialize();
    
    // Initialize AI API Service (for code generation, chat, voice)
    // No async init needed — lazy loading on first use
    
    if (kDebugMode) {
      debugPrint('✅ Services Initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Service Init Warning: $e');
    }
    // Continue app launch even if some services fail
  }
}

/// Root widget of Z.A.R.A. application
class ZaraApp extends StatelessWidget {
  const ZaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ZaraController>(
      create: (_) => ZaraController(),
      child: MaterialApp(
        // App identity
        title: 'Z.A.R.A.',
        debugShowCheckedModeBanner: false,

        // Theme configuration — Holographic Dark UI
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          
          // Colors
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.cyanPrimary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.cyanPrimary,
            secondary: AppColors.magentaAccent,
            surface: AppColors.surface,
            error: AppColors.errorRed,
          ),
          
          // Typography
          fontFamily: 'RobotoMono',
          textTheme: AppTextStyles.baseTheme,
          
          // Component themes
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanPrimary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.textDim.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cyanPrimary, width: 1.5),
            ),
          ),
        ),

        // Dark theme overrides (for consistency)
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.cyanPrimary,
          fontFamily: 'RobotoMono',
        ),
        themeMode: ThemeMode.dark, // Force dark mode for holographic effect

        // Home screen
        home: const ZaraHomeScreen(),

        // Optional: Add routes here for navigation
        // routes: {
        //   '/settings': (_) => const SettingsScreen(),
        //   '/code-generator': (_) => const CodeGeneratorScreen(),
        // },
      ),
    );
  }
}

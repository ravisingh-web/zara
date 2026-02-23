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
import 'package:zara_ai/core/constants/api_keys.dart';
import 'package:zara_ai/core/constants/app_colors.dart';
import 'package:zara_ai/core/constants/app_text_styles.dart';


// Feature imports
import 'package:zara_ai/features/zara_engine/providers/zara_provider.dart';
import 'package:zara_ai/features/hologram_ui/screens/zara_home_screen.dart';

// Services imports
import 'package:zara_ai/services/accessibility_service.dart';
import 'package:zara_ai/services/ai_api_service.dart';

/// Application entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait mode
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Enable edge-to-edge display (returns void - NO await)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // Set system bar colors
      SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize API Keys
  await ApiKeys.initialize();

  // Initialize Services
  await _initializeServices();

  // Debug logging
  if (kDebugMode) {
    debugPrint('🤖 Z.A.R.A. Core Initializing...');
    await Future.delayed(const Duration(milliseconds: 800));
    debugPrint('🔐 API Status:');
    debugPrint('  • Gemini: ${(ApiKeys.status['gemini'] ?? false) ? "✓" : "✗"}');
    debugPrint('  • Qwen: ${(ApiKeys.status['qwen'] ?? false) ? "✓" : "✗"}');
    debugPrint('  • Llama: ${(ApiKeys.status['llama'] ?? false) ? "✓" : "✗"}');
    debugPrint('  • Voice: ${ApiKeys.voiceName} (${ApiKeys.languageCode})');
    if (ApiKeys.isConfigured) {
      debugPrint('✅ All APIs Ready — Full features enabled');
    } else {
      debugPrint('⚠️ Missing APIs: ${ApiKeys.missing.join(", ")}');
    }
  }

  runApp(const ZaraApp());
}

/// Initialize all background services
Future<void> _initializeServices() async {
  try {
    await AccessibilityService().initialize();
    if (kDebugMode) debugPrint('✅ Services Initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Service Init Warning: $e');
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
        title: 'Z.A.R.A.',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.cyanPrimary,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.cyanPrimary,
            secondary: AppColors.magentaAccent,
            surface: AppColors.surface,
            error: AppColors.errorRed,
          ),
          fontFamily: 'RobotoMono',
          textTheme: AppTextStyles.baseTheme,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.cyanPrimary,
          fontFamily: 'RobotoMono',
        ),
        themeMode: ThemeMode.dark,
        home: const ZaraHomeScreen(),
      ),
    );
  }
}

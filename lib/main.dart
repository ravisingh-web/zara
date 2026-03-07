// lib/main.dart
// Z.A.R.A. — High-Tech Neural AI Interface
// ✅ Real Working Code • No Dummy • Single API Key from Settings

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

// Core imports
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';

// Feature imports
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/hologram_ui/screens/zara_home_screen.dart';

// Screen imports
import 'package:zara/screens/settings_screen.dart';

void main() async {
  // 1. Ensure Flutter Engine is Ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Lock Orientation to Portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 3. Immersive Full-Screen Mode (Edge-to-Edge)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 4. Initialize API Keys from Settings (CRITICAL)
  await ApiKeys.init();

  // 5. NOTE: AccessibilityService + NotificationService initialized AFTER runApp
  // inside ZaraController.initialize() — MethodChannel needs engine ready first.
  // ZaraAccessibilityService.kt handles this — no Flutter init needed.
  if (kDebugMode) debugPrint('✅ Z.A.R.A. starting...');

  // 7. Launch App
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ZaraController()..initialize(),
        ),
      ],
      child: const ZaraApp(),
    ),
  );
}

class ZaraApp extends StatelessWidget {
  const ZaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZARA AI',
      debugShowCheckedModeBanner: false,

      // 🎨 HOLOGRAPHIC THEME
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.deepSpaceBlack,
        fontFamily: 'monospace',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF00F0FF),
          secondary: Color(0xFFFF00FF),
          surface:   Color(0xFF0A0E17),
          error:     Color(0xFFFF4444),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(
            color: Colors.white,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
          bodyMedium: TextStyle(
            color: Colors.white70,
            fontFamily: 'monospace',
          ),
          labelLarge: TextStyle(
            color: Color(0xFF00F0FF),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00F0FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.deepSpaceBlack,
        primaryColor: const Color(0xFF00F0FF),
        fontFamily: 'monospace',
      ),
      themeMode: ThemeMode.dark,

      // Home with API Key Guard
      home: const ApiKeyGuard(child: ZaraHomeScreen()),
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

// 🔐 API Key Guard
class ApiKeyGuard extends StatelessWidget {
  final Widget child;
  const ApiKeyGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(
      builder: (context, controller, _) {
        if (!ApiKeys.ready) return _buildSetupScreen(context);
        return child;
      },
    );
  }

  Widget _buildSetupScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpaceBlack,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Z.A.R.A.',
                style: TextStyle(
                  color: const Color(0xFF00F0FF),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  fontFamily: 'monospace',
                  shadows: [
                    Shadow(
                      color: const Color(0xFF00F0FF).withOpacity(0.5),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Zenith Autonomous Reasoning Array',
                style: TextStyle(
                  color: const Color(0xFFFF00FF).withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFFF4444).withOpacity(0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.deepSpaceBlue,
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFF4444), size: 40),
                    SizedBox(height: 12),
                    Text(
                      'API Key Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Configure Gemini OR OpenRouter API key\nin Settings to activate Z.A.R.A.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.settings, color: Colors.black),
                label: const Text(
                  'Configure API Key',
                  style: TextStyle(fontFamily: 'monospace'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00F0FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Get key: https://aistudio.google.com/apikey',
                style: TextStyle(
                  color: const Color(0xFFFF00FF).withOpacity(0.7),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

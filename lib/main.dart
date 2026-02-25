// lib/main.dart
// Z.A.R.A. — High-Tech Neural AI Interface
// ✅ Strict Error Fix: Removed undefined AutoTypeService().initialize() call.
// ✅ Zero Logic Changed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/hologram_ui/screens/zara_home_screen.dart';
import 'package:zara/services/accessibility_service.dart';
import 'package:zara/services/auto_type_service.dart';

void main() async {
  // 1. Ensure Flutter Engine is Ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Lock Orientation to Portrait (Matched to Video HUD)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 3. Immersive Full-Screen Mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // 4. Initialize Core Neural Services
  try {
    await AccessibilityService().initialize();
    // ✅ FIXED: AutoTypeService doesn't need initialization. Line removed to fix error.
  } catch (e) {
    debugPrint('⚠️ System Boot Warning: Services not fully initialized');
  }

  // 5. Ignite Z.A.R.A.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ZaraController()..initialize()),
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

      // 🛠️ THEME CALIBRATION (Matched to 1000150012.mp4)
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.deepSpaceBlack,
        fontFamily: 'monospace', // Hacker Terminal Style
        useMaterial3: true,

        // Customizing HUD Components
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neonCyan,
          brightness: Brightness.dark,
          surface: AppColors.deepSpaceBlue,
        ),

        // Text Theme for Biometric Readouts
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, letterSpacing: 1.2),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),

      // The Entry Point: Z.A.R.A. Hologram Home
      home: const ZaraHomeScreen(),
    );
  }
}

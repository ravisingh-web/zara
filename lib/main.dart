// lib/main.dart
// Z.A.R.A. — Main Entry Point
// ✅ Fixed: Using ChangeNotifierProvider instead of ProviderScope

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/api_keys.dart';
import 'core/constants/app_colors.dart';
import 'features/zara_engine/providers/zara_provider.dart';
import 'features/hologram_ui/screens/zara_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  await ApiKeys.initialize();
  
  debugPrint('🤖 Z.A.R.A. Initializing...');
  await Future.delayed(const Duration(milliseconds: 800));
  
  if (ApiKeys.isConfigured) {
    debugPrint('✅ All APIs Ready');
  } else {
    debugPrint('⚠️ Missing: ${ApiKeys.missing.join(", ")}');
  }
  
  runApp(const ZaraApp());
}

class ZaraApp extends StatelessWidget {
  const ZaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ZaraController(),
      child: MaterialApp(
        title: 'Z.A.R.A.',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          primaryColor: AppColors.cyanPrimary,
          fontFamily: 'RobotoMono',
        ),
        home: const ZaraHomeScreen(),
      ),
    );
  }
}

// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — Main Holographic Home Screen

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

// Core imports
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/app_text_styles.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/core/enums/mood_enum.dart';

// Feature imports (✅ ADDED 'features/' in paths)
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/hologram_ui/widgets/zara_orb_painter.dart';
import 'package:zara/features/hologram_ui/widgets/status_header.dart';
import 'package:zara/features/hologram_ui/widgets/floating_prompts.dart';
import 'package:zara/features/hologram_ui/widgets/central_response_panel.dart';

// Screen imports
import 'package:zara/screens/settings_screen.dart';

// Service imports
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';

class ZaraHomeScreen extends StatefulWidget {
  const ZaraHomeScreen({super.key});
  @override
  State<ZaraHomeScreen> createState() => _ZaraHomeScreenState();
}

class _ZaraHomeScreenState extends State<ZaraHomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isListening = false;
  bool _isOverlayVisible = false;
  double _voiceAmplitude = 0.0;
  Timer? _amplitudeTimer;
  final _commandController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<ZaraController>().activate(); });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _commandController.dispose();
    _focusNode.dispose();
    _amplitudeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zara = context.watch<ZaraController>();
    final state = zara.state;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: StatusHeader(
          mood: state.mood,
          batteryLevel: state.batteryLevel,
          batteryState: state.batteryState,
          isWifiConnected: state.isWifiConnected,
          isMobileConnected: state.isMobileConnected,
          integrity: state.calculatedIntegrity,
          timestamp: DateTime.now(),
        ),
      ),
      body: Stack(
        children: [
          _buildBackgroundMesh(state.mood),
          Center(
            child: GestureDetector(
              onTap: () => _handleOrbTap(zara),
              onLongPress: () => _showOrbMenu(context, state),
              onVerticalDragUpdate: (details) => _handleOrbDrag(details, zara),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(280, 280),
                    painter: ZaraOrbPainter(
                      mood: state.mood,
                      pulseProgress: _pulseAnimation.value,
                      orbScale: state.orbScale,
                      glowIntensity: state.glowIntensity,
                      batteryLevel: state.batteryLevel,
                      isActive: state.isActive,
                      isSpeaking: _isListening,
                      amplitude: _voiceAmplitude,
                    ),
                  );
                },
              ),
            ),
          ),
          if (state.isActive || state.lastResponse.isNotEmpty)
            Positioned.fill(
              top: 80,
              bottom: 200,
              left: 20,
              right: 20,
              child: CentralResponsePanel(
                mood: state.mood,
                content: state.lastResponse,
                deviceModel: state.deviceModel,
                androidVersion: state.androidVersion,
                batteryLevel: state.batteryLevel,
              ),
            ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildCommandArea(zara, state)),
          if (_isListening) _buildListeningOverlay(state),
          if (_isOverlayVisible) _buildHolographicOverlay(zara, state),
        ],
      ),
    );
  }

  Widget _buildBackgroundMesh(Mood mood) => CustomPaint(
    size: Size.infinite,
    painter: _BackgroundMeshPainter(color: mood.primaryColor.withOpacity(0.06), time: _pulseAnimation.value),
  );

  Widget _buildCommandArea(ZaraController zara, ZaraState state) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.background, AppColors.background.withOpacity(0.95), Colors.transparent],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingPrompts(mood: state.mood, onSelected: (prompt) => _handleCommand(prompt, zara)),
        const SizedBox(height: 12),
        _buildInputField(zara, state),
      ],
    ),
  );

  Widget _buildInputField(ZaraController zara, ZaraState state) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: state.mood.primaryColor.withOpacity(0.6), width: 1.5),
      boxShadow: [BoxShadow(color: state.mood.primaryColor.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)],
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: state.mood.primaryColor),
          onPressed: () => _toggleVoiceInput(zara),
          tooltip: _isListening ? 'Stop listening' : 'Start voice command',
        ),
        Expanded(
          child: TextField(
            controller: _commandController,
            focusNode: _focusNode,
            style: AppTextStyles.terminalText.copyWith(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ask Z.A.R.A., Sir...',
              hintStyle: AppTextStyles.terminalText.copyWith(color: AppColors.textDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (value) => _handleCommand(value.trim(), zara),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send, color: AppColors.cyanPrimary),
          onPressed: () {
            if (_commandController.text.trim().isNotEmpty) _handleCommand(_commandController.text.trim(), zara);
          },
          tooltip: 'Send command',
        ),
      ],
    ),
  );

  void _toggleVoiceInput(ZaraController zara) {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      _startAmplitudeSimulation();
      Future.delayed(const Duration(seconds: 3), () {
        if (_isListening && mounted) {
          _stopVoiceInput(zara);
          _handleCommand('Hello Z.A.R.A., kya haal hai?', zara);
        }
      });
    } else {
      _stopVoiceInput(zara);
    }
  }

  void _startAmplitudeSimulation() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isListening || !mounted) {
        timer.cancel();
        return;
      }
      setState(() => _voiceAmplitude = 0.3 + (DateTime.now().millisecond / 1000) * 0.7);
    });
  }

  void _stopVoiceInput(ZaraController zara) {
    setState(() {
      _isListening = false;
      _voiceAmplitude = 0.0;
    });
    _amplitudeTimer?.cancel();
  }

  void _handleOrbTap(ZaraController zara) {
    setState(() => _isOverlayVisible = true);
    zara.activate();
    HapticFeedback.lightImpact();
  }

  void _showOrbMenu(BuildContext context, ZaraState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Z.A.R.A. Quick Actions', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 16)),
            const SizedBox(height: 16),
            _buildQuickAction(icon: Icons.security, label: 'Guardian Mode', onTap: () {
              Navigator.pop(context);
              context.read<ZaraController>().toggleGuardianMode();
            }),
            _buildQuickAction(icon: Icons.location_on, label: 'Get Location', onTap: () {
              Navigator.pop(context);
              _getCurrentLocation();
            }),
            _buildQuickAction(icon: Icons.camera_alt, label: 'Capture Photo', onTap: () {
              Navigator.pop(context);
              _captureIntruderPhoto();
            }),
            _buildQuickAction(icon: Icons.code, label: 'Analyze Code', onTap: () {
              Navigator.pop(context);
              context.read<ZaraController>().changeMood(Mood.coding);
            }),
            _buildQuickAction(icon: Icons.settings, label: 'Settings', onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String label, required VoidCallback onTap}) => ListTile(
    leading: Icon(icon, color: AppColors.cyanPrimary),
    title: Text(label, style: AppTextStyles.terminalText.copyWith(color: AppColors.textPrimary)),
    trailing: const Icon(Icons.chevron_right, color: AppColors.textDim),
    onTap: onTap,
  );

  void _handleOrbDrag(DragUpdateDetails details, ZaraController zara) {
    final delta = details.delta.dy;
    if (delta < -20 && zara.state.mood != Mood.excited) zara.changeMood(Mood.excited);
    else if (delta > 20 && zara.state.mood != Mood.calm) zara.changeMood(Mood.calm);
  }

  void _handleCommand(String command, ZaraController zara) {
    if (command.isEmpty) return;
    final lower = command.toLowerCase();
    if (_containsAny(lower, ['guardian', 'security'])) zara.toggleGuardianMode();
    else if (_containsAny(lower, ['location', 'where'])) _getCurrentLocation();
    else if (_containsAny(lower, ['photo', 'camera'])) _captureIntruderPhoto();
    else if (_containsAny(lower, ['code', 'dart', 'fix'])) {
      zara.changeMood(Mood.coding);
      zara.receiveCommand(command);
    } else if (_containsAny(lower, ['settings', 'api', 'voice'])) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    } else {
      zara.receiveCommand(command);
    }
    _commandController.clear();
    _focusNode.unfocus();
    if (_containsAny(lower, ['thank', 'nice', 'good', 'love', 'pyar'])) zara.addAffection();
  }

  bool _containsAny(String text, List<String> keywords) => keywords.any((kw) => text.contains(kw.toLowerCase()));

  Future<void> _getCurrentLocation() async {
    final zara = context.read<ZaraController>();
    final location = await LocationService().getCurrentLocation();
    if (location != null && mounted) {
      final link = LocationService().getGoogleMapsLink();
      final address = LocationService().getFormattedAddress();
      zara.generateResponse('📍 Location Found!\nCoordinates: ${location.latitude}, ${location.longitude}\nAddress: $address\nMaps: $link');
    } else {
      zara.generateResponse('⚠️ Location unavailable — Check permissions, Sir');
    }
  }

  Future<void> _captureIntruderPhoto() async {
    final zara = context.read<ZaraController>();
    final granted = await CameraService().requestPermission();
    if (!granted) {
      zara.generateResponse('⚠️ Camera permission denied — Enable in Settings');
      return;
    }
    final photoPath = await CameraService().captureIntruderPhoto();
    if (photoPath != null && mounted) {
      zara.generateResponse('📸 Photo Captured!\nPath: $photoPath\n\nEmail bhej doon Sir?');
    } else {
      zara.generateResponse('⚠️ Photo capture failed — Try again, Sir');
    }
  }

  Widget _buildListeningOverlay(ZaraState state) => Container(
    color: Colors.black54,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 80 + (_voiceAmplitude * 60),
            height: 80 + (_voiceAmplitude * 60),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: state.mood.primaryColor, width: 2 + _voiceAmplitude * 4),
              boxShadow: [BoxShadow(color: state.mood.primaryColor.withOpacity(0.6), blurRadius: 20 + _voiceAmplitude * 40, spreadRadius: 5)],
            ),
          ),
          const SizedBox(height: 20),
          Text('Listening, Sir...', style: AppTextStyles.terminalText.copyWith(color: state.mood.primaryColor, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Tap anywhere to stop', style: AppTextStyles.terminalText.copyWith(color: AppColors.textDim, fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _buildHolographicOverlay(ZaraController zara, ZaraState state) => Container(
    color: AppColors.background.withOpacity(0.95),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Z.A.R.A. Control Panel', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 16)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () {
                  setState(() => _isOverlayVisible = false);
                  zara.deactivate();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMetricCard(
                  icon: Icons.battery_full,
                  title: 'Battery',
                  value: '${state.batteryLevel}%',
                  subtitle: state.batteryState.toString().split('.').last,
                  color: _getBatteryColor(state.batteryLevel),
                ),
                _buildMetricCard(
                  icon: Icons.phone_android,
                  title: 'Device',
                  value: state.deviceModel,
                  subtitle: 'Android ${state.androidVersion}',
                  color: AppColors.cyanPrimary,
                ),
                _buildMetricCard(
                  icon: state.isWifiConnected ? Icons.wifi : Icons.signal_cellular_4_bar,
                  title: 'Network',
                  value: state.isWifiConnected ? 'WiFi' : (state.isMobileConnected ? 'Mobile' : 'Offline'),
                  subtitle: state.isWifiConnected ? 'Connected' : 'Searching...',
                  color: state.isWifiConnected ? AppColors.successGreen : AppColors.warningOrange,
                ),
                _buildGuardianCard(zara, state),
                if (state.securityAlerts.isNotEmpty) _buildSecurityAlertsCard(state.securityAlerts),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
    child: ListTile(
      leading: Icon(icon, color: color, size: 32),
      title: Text(title, style: const TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'RobotoMono')),
      subtitle: Text(
        subtitle,
        style: (AppTextStyles.baseTheme.labelSmall ?? const TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'RobotoMono')).copyWith(
          color: color.withOpacity(0.8),
          fontSize: 11,
        ),
      ),
      trailing: Text(value, style: AppTextStyles.terminalText.copyWith(color: color, fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );

  Widget _buildGuardianCard(ZaraController zara, ZaraState state) => Card(
    color: state.isGuardianActive ? AppColors.errorRed.withOpacity(0.1) : AppColors.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: state.isGuardianActive ? AppColors.errorRed : AppColors.textDim, width: state.isGuardianActive ? 1.5 : 0.5),
    ),
    child: ListTile(
      leading: Icon(
        state.isGuardianActive ? Icons.shield : Icons.shield_outlined,
        color: state.isGuardianActive ? AppColors.errorRed : AppColors.textDim,
        size: 32,
      ),
      title: const Text('Guardian Mode', style: const TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'RobotoMono')),
      subtitle: Text(
        state.isGuardianActive ? 'ACTIVE • Monitoring' : 'Standby • Tap to activate',
        style: (AppTextStyles.baseTheme.labelSmall ?? const TextStyle(color: AppColors.textDim, fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'RobotoMono')).copyWith(
          color: state.isGuardianActive ? AppColors.errorRed : AppColors.textDim,
        ),
      ),
      trailing: Switch(
        value: state.isGuardianActive,
        onChanged: (_) => zara.toggleGuardianMode(),
        activeColor: AppColors.errorRed,
      ),
    ),
  );

  Widget _buildSecurityAlertsCard(List<dynamic> alerts) => Card(
    color: AppColors.errorRed.withOpacity(0.1),
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.errorRed, width: 1)),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, color: AppColors.errorRed, size: 20),
              const SizedBox(width: 8),
              Text('Security Alerts (${alerts.length})', style: AppTextStyles.sciFiTitle.copyWith(fontSize: 12, color: AppColors.errorRed)),
            ],
          ),
          const SizedBox(height: 8),
          ...alerts.take(3).map((alert) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${(alert as Map<String, dynamic>)['message'] ?? 'Alert'}', style: AppTextStyles.terminalText.copyWith(fontSize: 11)),
          )).toList(),
        ],
      ),
    ),
  );

  Color _getBatteryColor(int level) {
    if (level <= 20) return AppColors.errorRed;
    if (level <= 50) return AppColors.warningOrange;
    return AppColors.successGreen;
  }
}

class _BackgroundMeshPainter extends CustomPainter {
  final Color color;
  final double time;
  const _BackgroundMeshPainter({required this.color, required this.time});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.4;
    const spacing = 45.0;
    for (var x = 0.0; x < size.width; x += spacing) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (var y = 0.0; y < size.height; y += spacing) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    final random = Random((time * 400).toInt());
    final particlePaint = Paint()..color = color.withOpacity(0.5);
    for (var i = 0; i < 25; i++) {
      final x = (sin(time * 0.25 + i) * 0.5 + 0.5) * size.width;
      final y = (cos(time * 0.3 + i * 0.6) * 0.5 + 0.5) * size.height;
      canvas.drawCircle(Offset(x, y), 1.2, particlePaint);
    }
  }
  
  @override
  bool shouldRepaint(_BackgroundMeshPainter old) => old.time != time || old.color != color;
}

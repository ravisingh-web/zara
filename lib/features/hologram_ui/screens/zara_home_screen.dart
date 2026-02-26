// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — The Final Sci-Fi HUD Interface
// ✅ Real Working • Proper Method Names • Service Connections • Null-Safe

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/enums/mood_enum.dart';
import '../../zara_engine/providers/zara_provider.dart';
import '../../zara_engine/models/zara_state.dart';
import '../widgets/zara_orb_painter.dart';
import '../widgets/status_header.dart';
import '../widgets/central_response_panel.dart';
import '../widgets/floating_prompts.dart';
import '../../../screens/settings_screen.dart';
import '../../../services/camera_service.dart';
import '../../../services/location_service.dart';
import '../../../services/email_service.dart';

class ZaraHomeScreen extends StatefulWidget {
  const ZaraHomeScreen({super.key});
  @override
  State<ZaraHomeScreen> createState() => _ZaraHomeScreenState();
}

class _ZaraHomeScreenState extends State<ZaraHomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  late AnimationController _gridController;
  late AnimationController _dnaController;
  late AnimationController _glitchController;

  final _cameraService = CameraService();
  final _locationService = LocationService();
  final _emailService = EmailService();

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _dnaController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _glitchController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
    ));
    _cameraService.initialize();
    _locationService.initialize();
    _emailService.initialize();
  }

  @override
  void dispose() {
    _gridController.dispose();
    _dnaController.dispose();
    _glitchController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zara = context.watch<ZaraController>();
    final state = zara.state;

    if (state.isGuardianActive && !_glitchController.isAnimating) {
      _glitchController.repeat(reverse: true);
    } else if (!state.isGuardianActive) {
      _glitchController.stop();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.deepSpaceBlack,
      resizeToAvoidBottomInset: false,
      drawer: _buildNeuralArchivesDrawer(context, zara, state),
      body: Stack(
        children: [
          _buildNeuralGrid(),
          _buildBackgroundDNA(state.isGuardianActive),
          if (state.isGuardianActive) _buildGuardianGlitch(),
          Center(
            child: ZaraOrbWidget(
              guardianMode: state.isGuardianActive,
              pulseValue: state.pulseValue,
              mood: state.mood,
            ),
          ),
          const CentralResponsePanel(),
          Positioned(            top: 0,
            left: 0,
            right: 0,
            child: StatusHeader(
              topicTitle: state.lastResponse.isEmpty ? "NEURAL INTERFACE" : "RESPONSE ACTIVE",
              guardianMode: state.isGuardianActive,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onNewChat: () => zara.reset(),
              onSettingsTap: () => _showSettings(context),
              onRenameTitle: (newTitle) {},
            ),
          ),
          _buildBottomActionPanel(zara, state),
        ],
      ),
    );
  }

  Widget _buildNeuralGrid() {
    return AnimatedBuilder(
      animation: _gridController,
      builder: (context, _) => CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _GridPainter(progress: _gridController.value),
      ),
    );
  }

  Widget _buildBackgroundDNA(bool isGuardian) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _dnaController,
        builder: (context, _) => CustomPaint(
          painter: _DNAPainter(
            progress: _dnaController.value,
            color: isGuardian ? AppColors.errorRed : AppColors.cyanPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildGuardianGlitch() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, _) => IgnorePointer(
        child: Container(
          color: AppColors.errorRed.withOpacity(0.05 * _glitchController.value),
          child: CustomPaint(
            size: MediaQuery.of(context).size,            painter: _GlitchPainter(progress: _glitchController.value),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionPanel(ZaraController zara, ZaraState state) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingPrompts(
            mood: state.mood,
            onSelected: (text) => zara.receiveCommand(text),
          ),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 15,
                  top: 15,
                  bottom: MediaQuery.of(context).padding.bottom + 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  border: Border(
                    top: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    _buildMicButton(zara),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: "ENTER NEURAL COMMAND, OWNER RAVI...",                          hintStyle: TextStyle(
                            color: AppColors.cyanPrimary.withOpacity(0.3),
                            fontSize: 10,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            zara.receiveCommand(val);
                            _inputController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.cyanPrimary, size: 20),
                      onPressed: () {
                        if (_inputController.text.isNotEmpty) {
                          zara.receiveCommand(_inputController.text);
                          _inputController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(ZaraController zara) {
    return GestureDetector(
      onTap: () async {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎤 Listening... (STT stub - implement native)'), duration: Duration(seconds: 2)),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.successGreen.withOpacity(0.5),
            width: 2,          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.successGreen.withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.mic_none_rounded,
          color: AppColors.cyanPrimary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildNeuralArchivesDrawer(BuildContext context, ZaraController zara, ZaraState state) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cyanPrimary, width: 0.5),
              ),
            ),
            child: Center(
              child: Text(
                'NEURAL ARCHIVES',
                style: TextStyle(
                  color: AppColors.cyanPrimary,
                  letterSpacing: 5,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          Expanded(
            child: state.dialogueHistory.isEmpty
                ? const Center(
                    child: Text(
                      'NO ARCHIVES DETECTED',
                      style: TextStyle(
                        color: Colors.white30,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),                    ),
                  )
                : ListView.builder(
                    itemCount: state.dialogueHistory.length,
                    itemBuilder: (context, index) {
                      final message = state.dialogueHistory[index];
                      return ListTile(
                        leading: const Icon(Icons.memory, color: AppColors.cyanPrimary, size: 20),
                        title: Text(
                          message.length > 30 ? '${message.substring(0, 30)}...' : message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Message #$index',
                          style: TextStyle(
                            color: AppColors.cyanPrimary.withOpacity(0.5),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                        onTap: () {
                          zara.generateResponse(message);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGuardianAction(
                  icon: Icons.camera_alt,
                  label: 'Capture Intruder',
                  onTap: () async {
                    Navigator.pop(context);
                    await _captureIntruderPhoto();
                  },
                ),
                _buildGuardianAction(
                  icon: Icons.location_on,
                  label: 'Get Location',
                  onTap: () async {                    Navigator.pop(context);
                    await _getCurrentLocation();
                  },
                ),
                _buildGuardianAction(
                  icon: Icons.email,
                  label: 'Send Alert',
                  onTap: () async {
                    Navigator.pop(context);
                    await _sendSecurityAlert();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardianAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyanPrimary, size: 20),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Future<void> _captureIntruderPhoto() async {
    try {
      final photoPath = await _cameraService.captureIntruderPhoto();
      if (photoPath != null && mounted) {
        context.read<ZaraController>().generateResponse('📸 Photo captured: $photoPath\nEmail bhej doon Sir?');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Camera error: $e')),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        final mapsLink = _locationService.getGoogleMapsLink();
        final address = _locationService.getFormattedAddress();
        context.read<ZaraController>().generateResponse(
          '📍 Location: $address\nCoordinates: ${position.latitude}, ${position.longitude}\nMaps: $mapsLink',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Location error: $e')),
        );
      }
    }
  }

  Future<void> _sendSecurityAlert() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final mapsLink = position != null ? _locationService.getGoogleMapsLink() : null;
      final address = _locationService.getFormattedAddress();
      final sent = await _emailService.sendSecurityAlert(
        alertType: 'MANUAL ALERT',
        message: 'Sir ne manual alert trigger kiya hai.',
        locationUrl: mapsLink,
        addressText: address,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sent ? '✅ Alert sent!' : '⚠️ Email app not available'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Email error: $e')),
        );
      }
    }
  }

  void _showSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }
}
// ========== Custom Painters ==========

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyanPrimary.withOpacity(0.05)
      ..strokeWidth = 0.5;
    final spacing = 45.0;
    final offset = progress * spacing;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = offset; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DNAPainter extends CustomPainter {
  final double progress;
  final Color color;
  _DNAPainter({required this.progress, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final centerX = size.width * 0.9;
    final amplitude = 20.0;
    for (double y = 0; y < size.height; y += 5) {
      final angle = (y * 0.02) + (progress * 2 * pi);
      final x1 = centerX + sin(angle) * amplitude;
      final x2 = centerX + sin(angle + pi) * amplitude;
      canvas.drawCircle(Offset(x1, y), 1, paint..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x2, y), 1, paint..style = PaintingStyle.fill);
      if (y % 20 == 0) {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), paint..style = PaintingStyle.stroke);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class _GlitchPainter extends CustomPainter {
  final double progress;
  _GlitchPainter({required this.progress});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.errorRed.withOpacity(0.1)
      ..strokeWidth = 1.0;
    final random = Random();
    for (int i = 0; i < 5; i++) {
      final y = random.nextDouble() * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ========== ZaraOrbPainter — Real Working Holographic Orb ==========
class ZaraOrbPainter extends CustomPainter {
  final Mood mood;
  final double pulseProgress;
  final double orbScale;
  final double glowIntensity;
  final int batteryLevel;
  final bool isActive;
  final bool isSpeaking;
  final double amplitude;

  ZaraOrbPainter({
    required this.mood,
    required this.pulseProgress,
    required this.orbScale,
    required this.glowIntensity,
    required this.batteryLevel,
    required this.isActive,
    required this.isSpeaking,
    required this.amplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide / 2 * 0.4;
    final radius = baseRadius * orbScale;

    // Outer glow
    if (glowIntensity > 0) {
      final glowPaint = Paint()
        ..color = mood.primaryColor.withOpacity(0.25 * glowIntensity)        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      canvas.drawCircle(center, radius * 2.2, glowPaint);
    }

    // Pulse ring
    final ringPaint = Paint()
      ..color = mood.primaryColor.withOpacity(0.5 + pulseProgress * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + pulseProgress * 3;
    canvas.drawCircle(center, radius * (1.3 + pulseProgress * 0.4), ringPaint);

    // Main orb gradient
    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        mood.primaryColor.withOpacity(0.9),
        mood.primaryColor.withOpacity(0.4),
        Colors.transparent,
      ],
      stops: const [0.0, 0.7, 1.0],
    );
    final orbPaint = Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, orbPaint);

    // Core highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(center.dx - radius * 0.3, center.dy - radius * 0.3), radius * 0.25, highlightPaint);

    // Battery indicator ring (bottom)
    if (batteryLevel < 100) {
      final batteryColor = batteryLevel <= 20 ? AppColors.errorRed : (batteryLevel <= 50 ? AppColors.warningOrange : AppColors.successGreen);
      final batteryPaint = Paint()
        ..color = batteryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      final startAngle = -pi / 2;
      final sweepAngle = (batteryLevel / 100) * 2 * pi;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius * 1.15), startAngle, sweepAngle, false, batteryPaint);
    }

    // Speaking animation (voice waves)
    if (isSpeaking && amplitude > 0) {
      for (var i = 0; i < 3; i++) {
        final waveRadius = radius * (1.4 + i * 0.3 + amplitude * 0.2);
        final wavePaint = Paint()
          ..color = mood.primaryColor.withOpacity(0.3 - i * 0.1)
          ..style = PaintingStyle.stroke          ..strokeWidth = 1.5;
        canvas.drawCircle(center, waveRadius, wavePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ZaraOrbPainter old) {
    return old.mood != mood ||
        old.pulseProgress != pulseProgress ||
        old.orbScale != orbScale ||
        old.glowIntensity != glowIntensity ||
        old.batteryLevel != batteryLevel ||
        old.isActive != isActive ||
        old.isSpeaking != isSpeaking ||
        old.amplitude != amplitude;
  }
}

// ========== ZaraOrbWidget ==========
class ZaraOrbWidget extends StatelessWidget {
  final bool guardianMode;
  final double pulseValue;
  final Mood mood;
  const ZaraOrbWidget({
    super.key,
    required this.guardianMode,
    required this.pulseValue,
    required this.mood,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<ZaraController>().activate(),
      onLongPress: () => _showOrbMenu(context),
      child: CustomPaint(
        size: const Size(280, 280),
        painter: ZaraOrbPainter(
          mood: mood,
          pulseProgress: pulseValue,
          orbScale: 1.0 + (pulseValue * 0.2),
          glowIntensity: mood.glowIntensity,
          batteryLevel: 85,
          isActive: true,
          isSpeaking: false,
          amplitude: pulseValue,
        ),
      ),
    );
  }  void _showOrbMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Z.A.R.A. Quick Actions',
              style: TextStyle(
                color: AppColors.cyanPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickAction(
              icon: Icons.security,
              label: 'Guardian Mode',
              onTap: () {
                Navigator.pop(context);
                context.read<ZaraController>().toggleGuardianMode();
              },
            ),
            _buildQuickAction(
              icon: Icons.location_on,
              label: 'Get Location',
              onTap: () async {
                Navigator.pop(context);
                final location = await LocationService().getCurrentLocation();
                if (location != null && context.mounted) {
                  final link = LocationService().getGoogleMapsLink();
                  context.read<ZaraController>().generateResponse(
                    '📍 Location: ${location.latitude}, ${location.longitude}\nMaps: $link',
                  );
                }
              },
            ),
            _buildQuickAction(
              icon: Icons.camera_alt,
              label: 'Capture Photo',
              onTap: () async {
                Navigator.pop(context);
                final path = await CameraService().captureIntruderPhoto();                if (path != null && context.mounted) {
                  context.read<ZaraController>().generateResponse('📸 Photo: $path');
                }
              },
            ),
            _buildQuickAction(
              icon: Icons.settings,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildQuickAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyanPrimary),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.cyanPrimary),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

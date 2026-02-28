// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — The Final Sci-Fi HUD Interface
// ✅ Real Working • Proper Method Names • Service Connections • Null-Safe

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/enums/mood_enum.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/hologram_ui/widgets/zara_orb_painter.dart';
import 'package:zara/features/hologram_ui/widgets/status_header.dart';
import 'package:zara/features/hologram_ui/widgets/central_response_panel.dart';
import 'package:zara/features/hologram_ui/widgets/floating_prompts.dart';
import 'package:zara/screens/settings_screen.dart';
import 'package:zara/services/camera_service.dart';
import 'package:zara/services/location_service.dart';
import 'package:zara/services/email_service.dart';

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
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();    _dnaController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
    );
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
          _buildNeuralGrid(),          _buildBackgroundDNA(state.isGuardianActive),
          if (state.isGuardianActive) _buildGuardianGlitch(),
          Center(
            child: ZaraOrbWidget(
              guardianMode: state.isGuardianActive,
              pulseValue: state.pulseValue,
              mood: state.mood,
            ),
          ),
          const CentralResponsePanel(),
          Positioned(
            top: 0,
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
      ),    );
  }

  Widget _buildGuardianGlitch() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, _) => IgnorePointer(
        child: Container(
          color: AppColors.errorRed.withOpacity(0.05 * _glitchController.value),
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _GlitchPainter(progress: _glitchController.value),
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
                    top: BorderSide(
                      color: AppColors.cyanPrimary.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [                    _buildMicButton(zara),
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
                          hintText: "ENTER NEURAL COMMAND, OWNER RAVI...",
                          hintStyle: TextStyle(
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
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppColors.cyanPrimary,
                        size: 20,
                      ),
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
            const SnackBar(
              content: Text('🎤 Listening... (STT stub - implement native)'),
              duration: Duration(seconds: 2),
            ),
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
            width: 2,
          ),
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

  Widget _buildNeuralArchivesDrawer(
    BuildContext context,
    ZaraController zara,
    ZaraState state,
  ) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cyanPrimary, width: 0.5),              ),
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
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.dialogueHistory.length,
                    itemBuilder: (context, index) {
                      final message = state.dialogueHistory[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.memory,
                          color: AppColors.cyanPrimary,
                          size: 20,
                        ),
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
                            color: AppColors.cyanPrimary.withOpacity(0.5),                            fontSize: 10,
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
                  onTap: () async {
                    Navigator.pop(context);
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

  Widget _buildGuardianAction({
    required IconData icon,    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyanPrimary, size: 20),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'monospace',
          fontSize: 12,
        ),
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
        context.read<ZaraController>().generateResponse(
          '📸 Photo captured: $photoPath\nEmail bhej doon Sir?',
        );
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
    try {
      final position = await _locationService.getCurrentLocation();
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
          SnackBar(content: Text('⚠️ Location error: $e')),        );
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
}

// ========== Custom Painters ==========

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()      ..color = AppColors.cyanPrimary.withOpacity(0.05)
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

  @override  void paint(Canvas canvas, Size size) {
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

// ZaraOrbPainter and ZaraOrbWidget are in separate file: zara_orb_painter.dart
// This file imports them via package:zara/features/hologram_ui/widgets/zara_orb_painter.dart

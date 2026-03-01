// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — Sci-Fi HUD Interface v2.0
// ✅ Keyboard-safe (input never hidden)
// ✅ Real STT mic using record package
// ✅ ChatMessage model (not plain strings)
// ✅ TTS auto-speak toggle
// ✅ All existing painters & widgets preserved

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zara/core/constants/app_colors.dart';
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

class _ZaraHomeScreenState extends State<ZaraHomeScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  // ── Animations (unchanged from original) ──────────────────────────────────
  late AnimationController _gridController;
  late AnimationController _dnaController;
  late AnimationController _glitchController;

  // ── Services (unchanged) ───────────────────────────────────────────────────
  final _cameraService   = CameraService();
  final _locationService = LocationService();
  final _emailService    = EmailService();

  // ── Audio (NEW) ────────────────────────────────────────────────────────────
  final _recorder = AudioRecorder();
  final _player   = AudioPlayer();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();

    // Exact same animation setup as original
    _gridController = AnimationController(
      vsync: this, duration: const Duration(seconds: 15),
    )..repeat();

    _dnaController = AnimationController(
      vsync: this, duration: const Duration(seconds: 20),
    )..repeat();

    _glitchController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200),
    );

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
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
    _scrollCtrl.dispose();
    _recorder.dispose();
    _player.dispose();
    _cameraService.dispose();
    super.dispose();
  }

  // ── Scroll to latest message ───────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send text command ──────────────────────────────────────────────────────
  Future<void> _sendCommand(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();
    _inputFocusNode.unfocus();

    final ctrl = context.read<ZaraController>();
    await ctrl.receiveCommand(text.trim());
    _scrollToBottom();

    // Auto TTS if enabled
    if (ctrl.state.ttsEnabled) {
      await _playTts(ctrl);
    }
  }

  // ── Mic STT ────────────────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    final ctrl = context.read<ZaraController>();

    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      ctrl.stopListening();

      if (path != null) {
        await ctrl.processAudio(path);
        _scrollToBottom();
        if (ctrl.state.ttsEnabled) await _playTts(ctrl);
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🎙️ Microphone permission required!'),
            backgroundColor: AppColors.errorRed,
          ));
        }
        return;
      }
      final dir  = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/zara_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      setState(() => _isRecording = true);
      ctrl.startListening();
    }
  }

  Future<void> _playTts(ZaraController ctrl) async {
    final path = await ctrl.speakLastResponse();
    if (path != null) {
      try {
        await _player.setFilePath(path);
        await _player.play();
      } catch (_) {}
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD — structure identical to original, only chatbox area updated
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final zara  = context.watch<ZaraController>();
    final state = zara.state;

    // Guardian glitch animation (unchanged)
    if (state.isGuardianActive && !_glitchController.isAnimating) {
      _glitchController.repeat(reverse: true);
    } else if (!state.isGuardianActive) {
      _glitchController.stop();
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.deepSpaceBlack,
      // ✅ KEY FIX: true so scaffold resizes when keyboard appears
      resizeToAvoidBottomInset: true,
      drawer: _buildNeuralArchivesDrawer(context, zara, state),
      body: Column(
        children: [
          // ── Background layers + Orb + Header (unchanged visuals) ────────────
          Expanded(
            child: Stack(
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
                // ✅ Chat panel now uses ChatMessage model
                CentralResponsePanel(scrollCtrl: _scrollCtrl),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: StatusHeader(
                    topicTitle: state.lastResponse.isEmpty
                        ? 'NEURAL INTERFACE'
                        : 'RESPONSE ACTIVE',
                    guardianMode: state.isGuardianActive,
                    ttsEnabled: state.ttsEnabled,
                    onMenuTap:     () => _scaffoldKey.currentState?.openDrawer(),
                    onNewChat:     () => zara.newChat(),
                    onSettingsTap: () => _showSettings(context),
                    onRenameTitle: (_) {},
                    onTtsTap:      () => zara.toggleTts(),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating Prompts + Input Bar ──────────────────────────────────
          // ✅ Outside the Stack so it moves up with keyboard automatically
          _buildBottomSection(zara, state),
        ],
      ),
    );
  }

  // ── Background painters (UNCHANGED from original) ─────────────────────────
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
            size: MediaQuery.of(context).size,
            painter: _GlitchPainter(progress: _glitchController.value),
          ),
        ),
      ),
    );
  }

  // ── Bottom Section (prompts + input) ──────────────────────────────────────
  Widget _buildBottomSection(ZaraController zara, ZaraState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.01),
        border: Border(
          top: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating prompt chips
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: FloatingPrompts(
              mood: state.mood,
              onSelected: (text) => _sendCommand(text),
            ),
          ),
          // Input bar with glassmorphism
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 12,
                  top: 10,
                  bottom: MediaQuery.of(context).padding.bottom + 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  border: Border(
                    top: BorderSide(
                        color: AppColors.cyanPrimary.withOpacity(0.2)),
                  ),
                ),
                child: Row(children: [
                  // ✅ Real mic button
                  _buildMicButton(zara),
                  const SizedBox(width: 12),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? '🎙️ Bol Sir...'
                            : 'Kuch bolo Sir...',
                        hintStyle: TextStyle(
                          color: AppColors.cyanPrimary.withOpacity(0.3),
                          fontSize: 11,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: _sendCommand,
                    ),
                  ),
                  // Send button
                  GestureDetector(
                    onTap: () => _sendCommand(_inputController.text),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.cyanPrimary,
                            AppColors.cyanPrimary.withOpacity(0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyanPrimary.withOpacity(0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.black, size: 18),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Real mic button — glows red when recording
  Widget _buildMicButton(ZaraController zara) {
    return GestureDetector(
      onTap: _toggleMic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isRecording
              ? AppColors.errorRed.withOpacity(0.15)
              : Colors.transparent,
          border: Border.all(
            color: _isRecording
                ? AppColors.errorRed
                : AppColors.successGreen.withOpacity(0.5),
            width: _isRecording ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? AppColors.errorRed.withOpacity(0.4)
                  : AppColors.successGreen.withOpacity(0.15),
              blurRadius: _isRecording ? 14 : 8,
            ),
          ],
        ),
        child: Icon(
          _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
          color: _isRecording ? AppColors.errorRed : AppColors.cyanPrimary,
          size: 20,
        ),
      ),
    );
  }

  // ── Neural Archives Drawer (updated to use ChatSession) ───────────────────
  Widget _buildNeuralArchivesDrawer(
    BuildContext context,
    ZaraController zara,
    ZaraState state,
  ) {
    final archives = state.chatArchives;
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Column(children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16, left: 16, right: 16,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.cyanPrimary, width: 0.5),
            ),
          ),
          child: Row(children: [
            const Expanded(
              child: Text(
                'NEURAL ARCHIVES',
                style: TextStyle(
                  color: AppColors.cyanPrimary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            // New chat icon
            GestureDetector(
              onTap: () { Navigator.pop(context); zara.newChat(); },
              child: const Icon(Icons.edit_rounded,
                  color: AppColors.cyanPrimary, size: 18),
            ),
          ]),
        ),

        // Current chat entry
        _drawerTile(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Current Chat',
          subtitle: '${state.messages.length} messages',
          color: AppColors.cyanPrimary,
          onTap: () => Navigator.pop(context),
        ),

        if (archives.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text('SAVED CHATS',
                style: TextStyle(
                  color: Colors.white24, fontSize: 9, letterSpacing: 2,
                  fontFamily: 'monospace',
                )),
          ),

        Expanded(
          child: archives.isEmpty
              ? const Center(
                  child: Text('NO ARCHIVES DETECTED',
                      style: TextStyle(
                        color: Colors.white30, fontFamily: 'monospace',
                        fontSize: 11,
                      )))
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: archives.length,
                  itemBuilder: (_, i) {
                    final s = archives[i];
                    return _drawerTile(
                      icon: Icons.history_rounded,
                      title: s.topicName,
                      subtitle: s.preview,
                      color: Colors.white54,
                      onTap: () {
                        Navigator.pop(context);
                        zara.loadArchivedChat(s.id);
                      },
                      onDelete: () => zara.deleteArchivedChat(s.id),
                    );
                  },
                ),
        ),

        // Guardian actions (unchanged from original)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
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
          ]),
        ),
      ]),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onDelete,
  }) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: color, size: 18),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color, fontFamily: 'monospace', fontSize: 12,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white30, fontSize: 10),
      ),
      trailing: onDelete != null
          ? GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.close_rounded,
                  color: Colors.white24, size: 14),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildGuardianAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.cyanPrimary, size: 20),
      title: Text(label,
          style: const TextStyle(
            color: Colors.white, fontFamily: 'monospace', fontSize: 12,
          )),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  // ── Service helpers (unchanged from original) ─────────────────────────────
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
            SnackBar(content: Text('⚠️ Camera: $e')));
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        context.read<ZaraController>().generateResponse(
          '📍 ${_locationService.getFormattedAddress()}\n'
          'Lat: ${pos.latitude}, Lng: ${pos.longitude}\n'
          '${_locationService.getGoogleMapsLink()}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ Location: $e')));
      }
    }
  }

  Future<void> _sendSecurityAlert() async {
    try {
      final pos  = await _locationService.getCurrentLocation();
      final link = pos != null ? _locationService.getGoogleMapsLink() : null;
      final sent = await _emailService.sendSecurityAlert(
        alertType:   'MANUAL ALERT',
        message:     'Sir ne manual alert trigger kiya hai.',
        locationUrl: link,
        addressText: _locationService.getFormattedAddress(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(sent ? '✅ Alert sent!' : '⚠️ Email app unavailable'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('⚠️ Email: $e')));
      }
    }
  }

  void _showSettings(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
}

// ── Painters (100% unchanged from original) ───────────────────────────────

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.cyanPrimary.withOpacity(0.05)
      ..strokeWidth = 0.5;
    const spacing = 45.0;
    final offset = progress * spacing;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = offset; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
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
    const amplitude = 20.0;
    for (double y = 0; y < size.height; y += 5) {
      final angle = (y * 0.02) + (progress * 2 * pi);
      final x1 = centerX + sin(angle) * amplitude;
      final x2 = centerX + sin(angle + pi) * amplitude;
      canvas.drawCircle(Offset(x1, y), 1, paint..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x2, y), 1, paint..style = PaintingStyle.fill);
      if (y % 20 == 0) {
        canvas.drawLine(
            Offset(x1, y), Offset(x2, y), paint..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

class _GlitchPainter extends CustomPainter {
  final double progress;
  _GlitchPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.errorRed.withOpacity(0.1)
      ..strokeWidth = 1.0;
    final rnd = Random();
    for (int i = 0; i < 5; i++) {
      final y = rnd.nextDouble() * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

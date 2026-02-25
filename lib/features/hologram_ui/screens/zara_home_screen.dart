// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. — The Final Sci-Fi HUD Interface
// ✅ Mic Button Linked: startListening() triggered on tap.

import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/hologram_ui/widgets/zara_orb_painter.dart';
import 'package:zara/features/hologram_ui/widgets/status_header.dart';
import 'package:zara/features/hologram_ui/widgets/central_response_panel.dart';
import 'package:zara/features/hologram_ui/widgets/floating_prompts.dart';
import 'package:zara/screens/settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _dnaController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _glitchController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.black, statusBarIconBrightness: Brightness.light));
  }

  @override
  void dispose() {
    _gridController.dispose();
    _dnaController.dispose();
    _glitchController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
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
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      drawer: _buildNeuralArchivesDrawer(context, zara, state),
      body: Stack(
        children: [
          _buildNeuralGrid(),
          _buildBackgroundDNA(state.isGuardianActive),
          if (state.isGuardianActive) _buildGuardianGlitch(),
          Center(child: ZaraOrbWidget(guardianMode: state.isGuardianActive, pulseValue: state.pulseValue)),
          const CentralResponsePanel(),
          Positioned(
            top: 0, left: 0, right: 0,
            child: StatusHeader(
              topicTitle: state.currentTopic.isEmpty ? "NEURAL INTERFACE" : state.currentTopic,
              guardianMode: state.isGuardianActive,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onNewChat: () => zara.resetSystem(),
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
      builder: (context, _) => CustomPaint(size: MediaQuery.of(context).size, painter: _GridPainter(progress: _gridController.value)),
    );
  }

  Widget _buildBackgroundDNA(bool isGuardian) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _dnaController,
        builder: (context, _) => CustomPaint(painter: _DNAPainter(progress: _dnaController.value, color: isGuardian ? AppColors.alertRed : AppColors.neonCyan)),
      ),
    );
  }

  Widget _buildGuardianGlitch() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, _) => IgnorePointer(child: Container(color: AppColors.alertRed.withOpacity(0.05 * _glitchController.value), child: CustomPaint(size: MediaQuery.of(context).size, painter: _GlitchPainter(progress: _glitchController.value)))),
    );
  }

  Widget _buildBottomActionPanel(ZaraController zara, ZaraState state) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom,
      left: 0, right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingPrompts(mood: state.mood, onSelected: (text) => zara.receiveCommand(text)),
          ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: EdgeInsets.only(left: 20, right: 15, top: 15, bottom: MediaQuery.of(context).padding.bottom + 15),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), border: Border(top: BorderSide(color: AppColors.neonCyan.withOpacity(0.2)))),
                child: Row(
                  children: [
                    _buildMicButton(zara),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: _inputController, focusNode: _inputFocusNode,
                        style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                        decoration: InputDecoration(hintText: "ENTER NEURAL COMMAND, OWNER RAVI...", hintStyle: TextStyle(color: AppColors.neonCyan.withOpacity(0.3), fontSize: 10), border: InputBorder.none),
                        onSubmitted: (val) { if (val.isNotEmpty) { zara.receiveCommand(val); _inputController.clear(); } },
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.send_rounded, color: AppColors.neonCyan, size: 20), onPressed: () { if (_inputController.text.isNotEmpty) { zara.receiveCommand(_inputController.text); _inputController.clear(); } }),
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
      onTap: () => zara.startListening(), // ✅ FIXED: Mic now calls startListening()
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: zara.isListening ? AppColors.neonGreen : AppColors.neonCyan.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: zara.isListening ? AppColors.neonGreen.withOpacity(0.4) : AppColors.neonCyan.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Icon(zara.isListening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, color: zara.isListening ? AppColors.neonGreen : AppColors.neonCyan, size: 20),
      ),
    );
  }

  Widget _buildNeuralArchivesDrawer(BuildContext context, ZaraController zara, ZaraState state) {
    return Drawer(
      backgroundColor: Colors.black.withOpacity(0.95),
      child: Column(
        children: [
          const DrawerHeader(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.neonCyan, width: 0.5))), child: Center(child: Text('NEURAL ARCHIVES', style: TextStyle(color: AppColors.neonCyan, letterSpacing: 5, fontWeight: FontWeight.bold, fontFamily: 'monospace')))),
          Expanded(child: state.chatArchives.isEmpty ? const Center(child: Text('NO ARCHIVES DETECTED', style: TextStyle(color: Colors.white30, fontFamily: 'monospace', fontSize: 12))) : ListView.builder(itemCount: state.chatArchives.length, itemBuilder: (context, index) { final archive = state.chatArchives[index]; final dateStr = "${archive.timestamp.day.toString().padLeft(2, '0')}/${archive.timestamp.month.toString().padLeft(2, '0')}"; return ListTile(leading: const Icon(Icons.memory, color: AppColors.neonCyan, size: 20), title: Text(archive.topicName, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text("$dateStr • ${archive.messages.length} exchanges", style: TextStyle(color: AppColors.neonCyan.withOpacity(0.5), fontSize: 10, fontFamily: 'monospace')), onTap: () { zara.loadArchivedChat(archive.id); Navigator.pop(context); }, onLongPress: () { showDialog(context: context, builder: (ctx) => BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: AlertDialog(backgroundColor: Colors.black.withOpacity(0.9), shape: RoundedRectangleBorder(side: const BorderSide(color: AppColors.alertRed, width: 1.5), borderRadius: BorderRadius.circular(15)), title: const Text('PURGE ARCHIVE?', style: TextStyle(color: AppColors.alertRed, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold)), content: Text("Delete '${archive.topicName}' permanently from Neural Memory?", style: const TextStyle(color: Colors.white70, fontSize: 12)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))), TextButton(onPressed: () { zara.deleteArchivedChat(archive.id); Navigator.pop(ctx); }, child: const Text('PURGE', style: TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold)))],))); },); })),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) { Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }
}

class _GridPainter extends CustomPainter {
  final double progress;
  _GridPainter({required this.progress});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = AppColors.neonCyan.withOpacity(0.05)..strokeWidth = 0.5; double spacing = 45.0; double offset = progress * spacing; for (double i = 0; i < size.width; i += spacing) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); } for (double i = offset; i < size.height; i += spacing) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DNAPainter extends CustomPainter {
  final double progress; final Color color;
  _DNAPainter({required this.progress, required this.color});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = color.withOpacity(0.15)..strokeWidth = 1.0..style = PaintingStyle.stroke; double centerX = size.width * 0.9; double amplitude = 20.0; for (double y = 0; y < size.height; y += 5) { double angle = (y * 0.02) + (progress * 2 * pi); double x1 = centerX + sin(angle) * amplitude; double x2 = centerX + sin(angle + pi) * amplitude; canvas.drawCircle(Offset(x1, y), 1, paint..style = PaintingStyle.fill); canvas.drawCircle(Offset(x2, y), 1, paint..style = PaintingStyle.fill); if (y % 20 == 0) canvas.drawLine(Offset(x1, y), Offset(x2, y), paint..style = PaintingStyle.stroke); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GlitchPainter extends CustomPainter {
  final double progress;
  _GlitchPainter({required this.progress});
  @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = AppColors.alertRed.withOpacity(0.1)..strokeWidth = 1.0; final random = Random(); for (int i = 0; i < 5; i++) { double y = random.nextDouble() * size.height; canvas.drawLine(Offset(0, y), Offset(size.width, y), paint); } }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

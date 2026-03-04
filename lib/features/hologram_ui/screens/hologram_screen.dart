// lib/features/hologram_ui/screens/hologram_screen.dart
// Z.A.R.A. — Professional Chat Interface v2.0
// ✅ WhatsApp/Instagram style message bubbles
// ✅ Left Sidebar Drawer — Chat History
// ✅ Long-press: Copy / Edit / Delete
// ✅ Mic STT button + TTS auto-speak toggle
// ✅ Keyboard-safe input (never hides behind keyboard)
// ✅ Glassmorphism + Neon Glow UI
// ✅ Zara response top-left, User top-right
// ✅ Typing indicator while AI processes
// ✅ New Chat button

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/screens/settings_screen.dart';
import 'package:zara/widgets/zara_floating_orb.dart'; // ✅ Floating ORB

class HologramScreen extends StatefulWidget {
  const HologramScreen({super.key});

  @override
  State<HologramScreen> createState() => _HologramScreenState();
}

class _HologramScreenState extends State<HologramScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _msgCtrl      = TextEditingController();
  final _scrollCtrl   = ScrollController();
  final _drawerKey    = GlobalKey<ScaffoldState>();

  // ── Audio ──────────────────────────────────────────────────────────────────
  final _player   = AudioPlayer();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordPath;

  // ── Edit Mode ──────────────────────────────────────────────────────────────
  String? _editingMessageId;

  // ── Animation ──────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ZaraController>().initialize();
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseCtrl.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Scroll to bottom ───────────────────────────────────────────────────────
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  // ── Send Message ───────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final ctrl = context.read<ZaraController>();

    if (_editingMessageId != null) {
      // Edit mode — update existing message
      ctrl.editMessage(_editingMessageId!, text);
      setState(() { _editingMessageId = null; });
      _msgCtrl.clear();
      return;
    }

    _msgCtrl.clear();
    FocusScope.of(context).unfocus();
    await ctrl.receiveCommand(text);
    _scrollToBottom();

    // Auto TTS
    if (ctrl.state.ttsEnabled) {
      await _playTts(ctrl);
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

  // ── Mic Recording ──────────────────────────────────────────────────────────
  Future<void> _toggleMic() async {
    final ctrl = context.read<ZaraController>();

    if (_isRecording) {
      // Stop recording
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      ctrl.stopListening();
      if (path != null) {
        await ctrl.processAudio(path);
        _scrollToBottom();
        if (ctrl.state.ttsEnabled) await _playTts(ctrl);
      }
    } else {
      // Start recording
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack('🎙️ Microphone permission required!');
        return;
      }
      final dir  = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/zara_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      setState(() { _isRecording = true; _recordPath = path; });
      ctrl.startListening();
    }
  }

  // ── Long Press Menu ────────────────────────────────────────────────────────
  void _showMessageMenu(BuildContext ctx, ChatMessage msg) {
    final ctrl = context.read<ZaraController>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MessageMenu(
        message: msg,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: msg.text));
          _showSnack('✅ Copied!');
        },
        onEdit: msg.role == MessageRole.user
            ? () {
                setState(() => _editingMessageId = msg.id);
                _msgCtrl.text = msg.text;
                FocusScope.of(context).requestFocus(FocusNode());
              }
            : null,
        onDelete: () {
          ctrl.deleteMessage(msg.id);
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppColors.deepSpaceBlue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(
      builder: (context, ctrl, _) {
        final state = ctrl.state;
        _scrollToBottom();
        return Stack(
          children: [
            Scaffold(
              key: _drawerKey,
              backgroundColor: AppColors.deepSpaceBlack,
              // ── Left Drawer — Chat History ──────────────────────────────────
              drawer: _buildSidebar(ctrl, state),
              body: SafeArea(
                child: Column(
                  children: [
                    // ── Top Bar ───────────────────────────────────────────────
                    _buildTopBar(ctrl, state),
                    // ── Zara Status Strip ─────────────────────────────────────
                    _buildStatusStrip(state),
                    // ── Chat Messages ─────────────────────────────────────────
                    Expanded(child: _buildMessageList(ctrl, state)),
                    // ── Typing Indicator ──────────────────────────────────────
                    if (state.isProcessing) _buildTypingIndicator(),
                    // ── Input Bar (keyboard-safe) ─────────────────────────────
                    _buildInputBar(ctrl, state),
                  ],
                ),
              ),
            ),
            // ✅ Floating Voice-Reactive ORB — hamesha sab ke upar
            // Tap karo → Hands-free ON/OFF
            // Drag karo → screen pe kahan bhi rakh lo
            const ZaraFloatingOrb(),
          ],
        );
      },
    );
  }

  // ── Top Bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar(ZaraController ctrl, ZaraState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        border: Border(
          bottom: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.2)),
        ),
      ),
      child: Row(children: [
        // Hamburger menu
        GestureDetector(
          onTap: () => _drawerKey.currentState?.openDrawer(),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.cyanPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.menu_rounded, color: AppColors.cyanPrimary, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        // Zara Avatar + Name
        _buildZaraAvatar(state, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Z.A.R.A.',
                  style: TextStyle(
                    color: AppColors.cyanPrimary,
                    fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2,
                  )),
              Text(
                state.isProcessing  ? '● typing...'
                    : state.isListening ? '🎙️ listening...'
                    : state.isSpeaking  ? '🔊 speaking...'
                    : '● Online',
                style: TextStyle(
                  color: state.isProcessing
                      ? Colors.amberAccent
                      : AppColors.successGreen,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // TTS Toggle
        GestureDetector(
          onTap: () => ctrl.toggleTts(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: state.ttsEnabled
                  ? AppColors.cyanPrimary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: state.ttsEnabled
                    ? AppColors.cyanPrimary.withOpacity(0.5)
                    : Colors.white12,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                state.ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: state.ttsEnabled ? AppColors.cyanPrimary : Colors.white38,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                state.ttsEnabled ? 'ON' : 'OFF',
                style: TextStyle(
                  color: state.ttsEnabled ? AppColors.cyanPrimary : Colors.white38,
                  fontSize: 9, fontWeight: FontWeight.bold,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // New Chat
        GestureDetector(
          onTap: () {
            ctrl.newChat();
            _showSnack('✨ New chat started!');
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white54, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Settings
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white54, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Zara Avatar (animated orb) ─────────────────────────────────────────────
  Widget _buildZaraAvatar(ZaraState state, {double size = 40}) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Transform.scale(
        scale: state.isProcessing ? _pulseAnim.value : 1.0,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF00FFFF), Color(0xFF003366)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyanPrimary.withOpacity(
                  state.isProcessing ? 0.7 : 0.3,
                ),
                blurRadius: state.isProcessing ? 16 : 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              'Z',
              style: TextStyle(
                color: Colors.black,
                fontSize: size * 0.45,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status Strip ───────────────────────────────────────────────────────────
  Widget _buildStatusStrip(ZaraState state) {
    if (!ApiKeys.ready) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: AppColors.errorRed.withOpacity(0.15),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.errorRed, size: 14),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'API key not configured. Tap Settings to activate Z.A.R.A.',
              style: TextStyle(color: AppColors.errorRed, fontSize: 10),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: const Text('Fix →',
                style: TextStyle(color: AppColors.cyanPrimary, fontSize: 10)),
          ),
        ]),
      );
    }
    return const SizedBox.shrink();
  }

  // ── Message List ───────────────────────────────────────────────────────────
  Widget _buildMessageList(ZaraController ctrl, ZaraState state) {
    final msgs = state.messages;
    if (msgs.isEmpty) {
      return _buildEmptyState(state);
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: msgs.length,
      itemBuilder: (ctx, i) {
        final msg  = msgs[i];
        final prev = i > 0 ? msgs[i - 1] : null;
        final showDate = prev == null ||
            !_sameDay(msg.timestamp, prev.timestamp);
        return Column(children: [
          if (showDate) _dateDivider(msg.timestamp),
          _buildBubble(msg, ctrl),
        ]);
      },
    );
  }

  Widget _buildEmptyState(ZaraState state) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF00FFFF), Color(0xFF001133)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanPrimary.withOpacity(0.5),
                    blurRadius: 30, spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('Z.A.R.A',
                    style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold,
                      fontSize: 13, letterSpacing: 1,
                    )),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Namaste, ${state.ownerName} 💙',
          style: const TextStyle(
            color: AppColors.cyanPrimary, fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ummm... kuch bolo Sir, main sun rahi hoon.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 20),
        // Quick command chips
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            '🎙️ Mic se bolo',
            '📱 Instagram kholo',
            '🧠 Code likhdo',
            '❤️ Kaisi ho Zara?',
          ].map((t) => GestureDetector(
            onTap: () {
              if (!t.startsWith('🎙️')) {
                _msgCtrl.text = t.replaceAll(RegExp(r'^[^\s]+ '), '');
                _sendMessage();
              } else {
                _toggleMic();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cyanPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.25)),
              ),
              child: Text(t,
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  // ── Single Message Bubble ──────────────────────────────────────────────────
  Widget _buildBubble(ChatMessage msg, ZaraController ctrl) {
    final isUser   = msg.role == MessageRole.user;
    final isSystem = msg.role == MessageRole.system;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg.text,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Zara avatar (left side only)
          if (!isUser) ...[
            _buildZaraAvatar(ctrl.state, size: 28),
            const SizedBox(width: 6),
          ],

          // Bubble
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageMenu(context, msg),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isUser
                      ? const LinearGradient(
                          colors: [Color(0xFF003355), Color(0xFF001A33)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            AppColors.cyanPrimary.withOpacity(0.12),
                            AppColors.cyanPrimary.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: isUser
                        ? Colors.blue.withOpacity(0.25)
                        : AppColors.cyanPrimary.withOpacity(0.25),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isUser
                          ? Colors.blue.withOpacity(0.08)
                          : AppColors.cyanPrimary.withOpacity(0.08),
                      blurRadius: 8, spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message text (selectable)
                    SelectableText(
                      msg.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.white.withOpacity(0.92),
                        fontSize: 13.5, height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Timestamp + edited badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(msg.timestamp),
                          style: TextStyle(
                            color: isUser
                                ? Colors.white38
                                : AppColors.cyanPrimary.withOpacity(0.5),
                            fontSize: 9,
                          ),
                        ),
                        if (msg.isEdited) ...[
                          const SizedBox(width: 4),
                          Text('edited',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 9,
                                fontStyle: FontStyle.italic,
                              )),
                        ],
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.done_all_rounded,
                              size: 12, color: AppColors.cyanPrimary),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Spacer on Zara side
          if (!isUser) const SizedBox(width: 28),
        ],
      ),
    );
  }

  // ── Typing Indicator ───────────────────────────────────────────────────────
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(children: [
        _buildZaraAvatar(context.read<ZaraController>().state, size: 24),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cyanPrimary.withOpacity(0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
            ),
            border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _dot(0), _dot(150), _dot(300),
          ]),
        ),
      ]),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: AppColors.cyanPrimary.withOpacity(v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── Date Divider ───────────────────────────────────────────────────────────
  Widget _dateDivider(DateTime dt) {
    final now   = DateTime.now();
    final label = _sameDay(dt, now)
        ? 'Today'
        : _sameDay(dt, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : DateFormat('d MMM yyyy').format(dt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ),
        Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Input Bar ──────────────────────────────────────────────────────────────
  Widget _buildInputBar(ZaraController ctrl, ZaraState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        border: Border(
          top: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.15)),
        ),
      ),
      // ✅ KEYBOARD FIX: Padding adjusts with keyboard inset
      padding: EdgeInsets.only(
        left: 12, right: 12,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 8
            : 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Edit mode banner
        if (_editingMessageId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amberAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.edit_rounded, size: 12, color: Colors.amberAccent),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Editing message...',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 10)),
              ),
              GestureDetector(
                onTap: () {
                  setState(() => _editingMessageId = null);
                  _msgCtrl.clear();
                },
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.amberAccent),
              ),
            ]),
          ),

        Row(children: [
          // Mic Button
          GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? AppColors.errorRed.withOpacity(0.2)
                    : AppColors.cyanPrimary.withOpacity(0.08),
                border: Border.all(
                  color: _isRecording
                      ? AppColors.errorRed
                      : AppColors.cyanPrimary.withOpacity(0.3),
                  width: _isRecording ? 2 : 1,
                ),
                boxShadow: _isRecording
                    ? [BoxShadow(
                        color: AppColors.errorRed.withOpacity(0.4),
                        blurRadius: 12, spreadRadius: 2,
                      )]
                    : [],
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                color: _isRecording
                    ? AppColors.errorRed
                    : AppColors.cyanPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text Input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.cyanPrimary.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(
                  color: Colors.white, fontSize: 13.5,
                ),
                decoration: InputDecoration(
                  hintText: _isRecording
                      ? '🎙️ Recording... tap stop when done'
                      : 'Kuch bolo Sir...',
                  hintStyle: const TextStyle(
                    color: Colors.white30, fontSize: 12,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FFFF), Color(0xFF0099BB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyanPrimary.withOpacity(0.35),
                    blurRadius: 10, spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded, color: Colors.black, size: 18,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Left Sidebar Drawer ────────────────────────────────────────────────────
  Widget _buildSidebar(ZaraController ctrl, ZaraState state) {
    final archives = state.chatArchives;
    return ClipRRect(
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.78,
          color: Colors.black.withOpacity(0.85),
          child: Column(children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.2)),
                ),
              ),
              child: Row(children: [
                _buildZaraAvatar(state, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Z.A.R.A.',
                        style: TextStyle(
                          color: AppColors.cyanPrimary,
                          fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2,
                        )),
                    Text(
                      '${archives.length} saved chats',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ]),
                ),
                // New Chat
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    ctrl.newChat();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyanPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        color: AppColors.cyanPrimary, size: 16),
                  ),
                ),
              ]),
            ),

            // Current Chat
            _sidebarTile(
              icon: Icons.chat_bubble_rounded,
              title: 'Current Chat',
              subtitle: '${state.messages.length} messages',
              isActive: true,
              onTap: () => Navigator.pop(context),
              onDelete: null,
            ),

            if (archives.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  const Text('HISTORY',
                      style: TextStyle(
                        color: Colors.white24, fontSize: 9, letterSpacing: 2,
                      )),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _confirmClearAll(ctrl),
                    child: const Text('Clear all',
                        style: TextStyle(
                          color: AppColors.errorRed, fontSize: 9,
                        )),
                  ),
                ]),
              ),
            ],

            // Archive List
            Expanded(
              child: archives.isEmpty
                  ? const Center(
                      child: Text('No saved chats yet',
                          style: TextStyle(color: Colors.white24, fontSize: 11)),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: archives.length,
                      itemBuilder: (_, i) {
                        final session = archives[i];
                        return _sidebarTile(
                          icon: Icons.history_rounded,
                          title: session.topicName,
                          subtitle: session.preview,
                          timestamp: session.timestamp,
                          isActive: false,
                          onTap: () {
                            Navigator.pop(context);
                            ctrl.loadArchivedChat(session.id);
                          },
                          onDelete: () => ctrl.deleteArchivedChat(session.id),
                          onRename: () => _showRenameDialog(ctrl, session),
                        );
                      },
                    ),
            ),

            // Settings Link
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.1)),
                ),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
                child: Row(children: const [
                  Icon(Icons.settings_rounded, color: Colors.white38, size: 18),
                  SizedBox(width: 10),
                  Text('Settings',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sidebarTile({
    required IconData icon,
    required String title,
    required String subtitle,
    DateTime? timestamp,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onDelete,
    VoidCallback? onRename,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onRename,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.cyanPrimary.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.cyanPrimary.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(children: [
          Icon(icon,
              color: isActive ? AppColors.cyanPrimary : Colors.white38,
              size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? AppColors.cyanPrimary : Colors.white70,
                  fontSize: 12, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white30, fontSize: 10),
              ),
            ]),
          ),
          if (timestamp != null)
            Text(
              DateFormat('d MMM').format(timestamp),
              style: const TextStyle(color: Colors.white24, fontSize: 9),
            ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDelete,
              child: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white24, size: 14),
            ),
          ],
        ]),
      ),
    );
  }

  void _confirmClearAll(ZaraController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deepSpaceBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.errorRed.withOpacity(0.4)),
        ),
        title: const Text('Clear All History?',
            style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
        content: const Text(
          'Sab archived chats delete ho jayenge. Ye undo nahi hoga.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed, foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ctrl.clearAllArchives();
            },
            child: const Text('Clear', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(ZaraController ctrl, ChatSession session) {
    final nameCtrl = TextEditingController(text: session.topicName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deepSpaceBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3)),
        ),
        title: const Text('Rename Chat',
            style: TextStyle(color: AppColors.cyanPrimary, fontSize: 14)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            filled: true, fillColor: Colors.black45,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanPrimary, foregroundColor: Colors.black,
            ),
            onPressed: () {
              ctrl.renameArchivedChat(session.id, nameCtrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ─── Message Long-Press Menu ───────────────────────────────────────────────
class _MessageMenu extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _MessageMenu({
    required this.message,
    required this.onCopy,
    this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanPrimary.withOpacity(0.1),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Message preview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Text(
            message.text.length > 80
                ? '${message.text.substring(0, 80)}…'
                : message.text,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        // Copy
        _menuItem(
          icon: Icons.copy_rounded,
          label: 'Copy Message',
          color: Colors.white70,
          onTap: () { Navigator.pop(context); onCopy(); },
        ),
        // Edit (user messages only)
        if (onEdit != null) ...[
          const Divider(color: Colors.white12, height: 1),
          _menuItem(
            icon: Icons.edit_rounded,
            label: 'Edit Message',
            color: Colors.amberAccent,
            onTap: () { Navigator.pop(context); onEdit!(); },
          ),
        ],
        const Divider(color: Colors.white12, height: 1),
        // Delete
        _menuItem(
          icon: Icons.delete_outline_rounded,
          label: 'Delete Message',
          color: AppColors.errorRed,
          onTap: () { Navigator.pop(context); onDelete(); },
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ]),
      ),
    );
  }
}

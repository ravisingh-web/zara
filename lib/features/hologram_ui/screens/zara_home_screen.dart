// lib/features/hologram_ui/screens/zara_home_screen.dart
// Z.A.R.A. v9.0 — JARVIS Supreme Home Screen
//
// ✅ ZaraOverlayChatManager wraps entire app — overlay chat always available
// ✅ Hands-Free mode toggle — one button, full Iron Man Jarvis mode
// ✅ Wake word status indicator — "Hii Zara" listening badge
// ✅ PendingReply approval card — Zara proposes reply, user approves/edits
// ✅ Agent Mode indicator — when Zara replies as proxy
// ✅ Floating orb volume-reactive
// ✅ Full chat message list (CentralResponsePanel)
// ✅ Cyberpunk hologram grid background

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/hologram_ui/widgets/zara_orb_painter.dart';
import 'package:zara/features/hologram_ui/widgets/central_response_panel.dart';
import 'package:zara/widgets/zara_overlay_chat.dart';
import 'package:zara/screens/settings_screen.dart';

class ZaraHomeScreen extends StatefulWidget {
  const ZaraHomeScreen({super.key});
  @override
  State<ZaraHomeScreen> createState() => _ZaraHomeScreenState();
}

class _ZaraHomeScreenState extends State<ZaraHomeScreen>
    with TickerProviderStateMixin {

  final _textCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  double _currentVolume = 0.0;

  // Wake word pulse animation
  late AnimationController _wakeAnim;
  late Animation<double>   _wakePulse;

  // Hands-free shimmer
  late AnimationController _hfAnim;
  late Animation<double>   _hfGlow;

  @override
  void initState() {
    super.initState();

    _wakeAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _wakePulse = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _wakeAnim, curve: Curves.easeInOut));

    _hfAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _hfGlow = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _hfAnim, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<ZaraController>();
      // Wire TTS volume → orb animation
      ctrl.onVolumeLevel = (v) {
        if (mounted) setState(() => _currentVolume = v);
      };
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _wakeAnim.dispose();
    _hfAnim.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  OrbState _orbState(ZaraController c) {
    if (c.isListening)            return OrbState.listening;
    if (c.state.isProcessing)     return OrbState.thinking;
    if (c.state.isSpeaking)       return OrbState.speaking;
    return OrbState.idle;
  }

  void _send(ZaraController ctrl) {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    ctrl.receiveCommand(t);
    _scrollToBottom();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(
      builder: (context, ctrl, _) {
        _scrollToBottom();
        return ZaraOverlayChatManager(
          child: Scaffold(
            backgroundColor: const Color(0xFF050A14),
            resizeToAvoidBottomInset: true,
            body: Stack(
              children: [

                // ── HOLOGRAM GRID ────────────────────────────────────────────
                const Positioned.fill(child: _GridBackground()),

                // ── MAIN LAYOUT ──────────────────────────────────────────────
                SafeArea(
                  child: Column(
                    children: [

                      // ── TOP BAR ───────────────────────────────────────────
                      _TopBar(ctrl: ctrl, wakePulse: _wakePulse, hfGlow: _hfGlow),

                      // ── WAKE WORD STATUS BANNER ───────────────────────────
                      if (ctrl.wakeWordListening)
                        _WakeWordBanner(pulse: _wakePulse),

                      // ── PENDING REPLY CARD ────────────────────────────────
                      if (ctrl.pendingReply != null)
                        _PendingReplyCard(
                          pending: ctrl.pendingReply!,
                          ctrl:    ctrl,
                        ),

                      // ── AGENT MODE BANNER ─────────────────────────────────
                      if (ctrl.agentModeActive)
                        _AgentModeBanner(ctrl: ctrl),

                      // ── CHAT MESSAGES ─────────────────────────────────────
                      Expanded(
                        child: ctrl.state.messages.isEmpty
                            ? _EmptyState(
                                orbState:   _orbState(ctrl),
                                volume:     _currentVolume,
                                ctrl:       ctrl,
                                wakePulse:  _wakePulse,
                              )
                            : CentralResponsePanel(scrollCtrl: _scrollCtrl),
                      ),

                      // ── INPUT BAR ─────────────────────────────────────────
                      _InputBar(
                        ctrl:     ctrl,
                        textCtrl: _textCtrl,
                        orbState: _orbState(ctrl),
                        volume:   _currentVolume,
                        onSend:   () => _send(ctrl),
                      ),

                    ],
                  ),
                ),

              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TOP BAR
// ══════════════════════════════════════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final ZaraController     ctrl;
  final Animation<double>  wakePulse;
  final Animation<double>  hfGlow;
  const _TopBar({required this.ctrl, required this.wakePulse, required this.hfGlow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: AppColors.cyanPrimary.withOpacity(0.15), width: 0.5),
        ),
      ),
      child: Row(
        children: [

          // Z.A.R.A. title + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Z.A.R.A.',
                style: TextStyle(
                  color: AppColors.cyanPrimary, fontSize: 18,
                  fontWeight: FontWeight.bold, letterSpacing: 3,
                  fontFamily: 'monospace',
                )),
              AnimatedBuilder(
                animation: hfGlow,
                builder: (_, __) => Text(
                  ctrl.state.isSpeaking    ? '● Speaking...'     :
                  ctrl.isListening         ? '● Listening...'    :
                  ctrl.state.isProcessing  ? '● Processing...'   :
                  ctrl.realtimeActive      ? '● Hands-Free ON'   :
                  ctrl.wakeWordListening   ? '● Wake Word Active' :
                  '● Ready',
                  style: TextStyle(
                    color: ctrl.state.isSpeaking    ? const Color(0xFFBB00FF) :
                           ctrl.isListening         ? AppColors.successGreen  :
                           ctrl.state.isProcessing  ? AppColors.warningOrange :
                           ctrl.realtimeActive      ? AppColors.cyanPrimary.withOpacity(hfGlow.value) :
                           ctrl.wakeWordListening   ? AppColors.cyanPrimary.withOpacity(0.6) :
                           AppColors.cyanPrimary.withOpacity(0.5),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // ── HANDS-FREE BUTTON ───────────────────────────────────────────
          _HandsFreeButton(ctrl: ctrl, glow: hfGlow),

          const SizedBox(width: 6),

          // ── WAKE WORD BUTTON ────────────────────────────────────────────
          _WakeWordButton(ctrl: ctrl, pulse: wakePulse),

          const SizedBox(width: 4),

          // Settings
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.cyanPrimary, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// HANDS-FREE BUTTON
// ══════════════════════════════════════════════════════════════════════════

class _HandsFreeButton extends StatelessWidget {
  final ZaraController    ctrl;
  final Animation<double> glow;
  const _HandsFreeButton({required this.ctrl, required this.glow});

  @override
  Widget build(BuildContext context) {
    final active = ctrl.realtimeActive;
    return AnimatedBuilder(
      animation: glow,
      builder: (_, __) {
        final color = active ? AppColors.cyanPrimary : Colors.white38;
        final opacity = active ? glow.value : 0.5;
        return GestureDetector(
          onTap: () => ctrl.toggleRealtime(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12 * opacity),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.7), width: 1.2),
              boxShadow: active
                  ? [BoxShadow(
                      color: AppColors.cyanPrimary.withOpacity(0.3 * opacity),
                      blurRadius: 12, spreadRadius: 1)]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? Icons.hearing : Icons.hearing_disabled,
                  color: color, size: 14,
                ),
                const SizedBox(width: 5),
                Text(
                  active ? 'LIVE' : 'MUTE',
                  style: TextStyle(
                    color: color, fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WAKE WORD BUTTON
// ══════════════════════════════════════════════════════════════════════════

class _WakeWordButton extends StatelessWidget {
  final ZaraController    ctrl;
  final Animation<double> pulse;
  const _WakeWordButton({required this.ctrl, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final active = ctrl.wakeWordListening;
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final color = active
            ? const Color(0xFF00FF88)
            : Colors.white30;
        return GestureDetector(
          onTap: () => active
              ? ctrl.stopWakeWordEngine()
              : ctrl.startWakeWordEngine(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(active ? 0.12 * pulse.value : 0.05),
              border: Border.all(color: color.withOpacity(active ? 0.8 : 0.3), width: 1),
              boxShadow: active
                  ? [BoxShadow(
                      color: color.withOpacity(0.4 * pulse.value),
                      blurRadius: 10, spreadRadius: 0)]
                  : [],
            ),
            child: Icon(
              active ? Icons.record_voice_over : Icons.voice_over_off,
              color: color, size: 16,
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WAKE WORD BANNER — shown when always-on mic is active
// ══════════════════════════════════════════════════════════════════════════

class _WakeWordBanner extends StatelessWidget {
  final Animation<double> pulse;
  const _WakeWordBanner({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: const Color(0xFF00FF88).withOpacity(0.06 * pulse.value),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00FF88).withOpacity(pulse.value),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '"Hii Zara" ya "Sunna" bolein — main sun rahi hoon',
              style: TextStyle(
                color: const Color(0xFF00FF88).withOpacity(0.8),
                fontSize: 10, fontFamily: 'monospace', letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PENDING REPLY CARD — Zara suggests a reply, user approves/edits/rejects
// ══════════════════════════════════════════════════════════════════════════

class _PendingReplyCard extends StatefulWidget {
  final PendingReply    pending;
  final ZaraController ctrl;
  const _PendingReplyCard({required this.pending, required this.ctrl});

  @override
  State<_PendingReplyCard> createState() => _PendingReplyCardState();
}

class _PendingReplyCardState extends State<_PendingReplyCard> {
  late TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.pending.message);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = const Color(0xFF00FF88);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Header
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.pending.app} · ${widget.pending.contact}',
                  style: TextStyle(
                    color: color, fontSize: 11,
                    fontFamily: 'monospace', fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Edit toggle
              GestureDetector(
                onTap: () => setState(() => _editing = !_editing),
                child: Icon(
                  _editing ? Icons.check : Icons.edit,
                  color: color.withOpacity(0.7), size: 16,
                ),
              ),
              const SizedBox(width: 8),
              // Dismiss
              GestureDetector(
                onTap: widget.ctrl.dismissPendingReply,
                child: Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Reply text — editable or static
          _editing
              ? TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  maxLines: 3, minLines: 1,
                  decoration: InputDecoration(
                    isDense: true, filled: true, fillColor: Colors.black26,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                )
              : Text(
                  '"${_ctrl.text}"',
                  style: const TextStyle(
                    color: Colors.white70, fontSize: 13,
                    fontFamily: 'monospace', fontStyle: FontStyle.italic,
                  ),
                ),

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              const Spacer(),
              // REJECT
              _ActionBtn(
                label: 'SKIP',
                color: Colors.white30,
                icon:  Icons.block,
                onTap: widget.ctrl.dismissPendingReply,
              ),
              const SizedBox(width: 10),
              // SEND
              _ActionBtn(
                label: 'SEND ✓',
                color: color,
                icon:  Icons.send,
                onTap: () => widget.ctrl.approvePendingReply(_ctrl.text),
              ),
            ],
          ),

        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String   label;
  final Color    color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.label, required this.color,
    required this.icon,  required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
            style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.bold, letterSpacing: 1,
              fontFamily: 'monospace',
            )),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════
// AGENT MODE BANNER
// ══════════════════════════════════════════════════════════════════════════

class _AgentModeBanner extends StatelessWidget {
  final ZaraController ctrl;
  const _AgentModeBanner({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: const Color(0xFFBB00FF).withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.android, color: const Color(0xFFBB00FF), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Agent Mode: Zara replies as you on ${ctrl.agentContact}',
              style: const TextStyle(
                color: const Color(0xFFBB00FF), fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ctrl.receiveCommand('agent mode band karo'),
            child: const Text('STOP',
              style: TextStyle(
                color: const Color(0xFFBB00FF), fontSize: 10,
                fontWeight: FontWeight.bold, fontFamily: 'monospace',
              )),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// EMPTY STATE (no messages yet)
// ══════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final OrbState orbState;
  final double   volume;
  final ZaraController ctrl;
  final Animation<double> wakePulse;
  const _EmptyState({
    required this.orbState, required this.volume,
    required this.ctrl,     required this.wakePulse,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Big centered orb
          ZaraFloatingOrb(
            state:       orbState,
            volumeLevel: volume,
            onTap:       ctrl.isListening ? ctrl.stopListening : ctrl.startListening,
          ),

          const SizedBox(height: 28),

          // Status text
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              key: ValueKey(orbState),
              orbState == OrbState.listening ? 'Sun rahi hoon, Sir...'     :
              orbState == OrbState.speaking  ? 'Bol rahi hoon...'          :
              orbState == OrbState.thinking  ? 'Soch rahi hoon...'         :
              ctrl.realtimeActive            ? '"Hii Zara" — try karo!'    :
              'Tap karo · mic se bolo · ya type karo',
              style: TextStyle(
                color: AppColors.cyanPrimary.withOpacity(0.65),
                fontSize: 13, fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Quick action chips
          _QuickActions(ctrl: ctrl),

        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// QUICK ACTIONS — voice prompt chips
// ══════════════════════════════════════════════════════════════════════════

class _QuickActions extends StatelessWidget {
  final ZaraController ctrl;
  const _QuickActions({required this.ctrl});

  static const _actions = [
    ('YouTube pe Arijit Singh', Icons.play_circle_outline),
    ('WhatsApp pe Rahul ko Hi bolo', Icons.chat_outlined),
    ('Instagram Reels kholo', Icons.video_collection_outlined),
    ('Kal ka weather kya hai?', Icons.wb_sunny_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8, runSpacing: 8,
      children: _actions.map((a) => GestureDetector(
        onTap: () => ctrl.receiveCommand(a.$1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.cyanPrimary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.cyanPrimary.withOpacity(0.2), width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.$2, color: AppColors.cyanPrimary.withOpacity(0.6), size: 13),
              const SizedBox(width: 5),
              Text(
                a.$1,
                style: TextStyle(
                  color: AppColors.cyanPrimary.withOpacity(0.7),
                  fontSize: 11, fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// INPUT BAR
// ══════════════════════════════════════════════════════════════════════════

class _InputBar extends StatelessWidget {
  final ZaraController ctrl;
  final TextEditingController textCtrl;
  final OrbState     orbState;
  final double       volume;
  final VoidCallback onSend;
  const _InputBar({
    required this.ctrl, required this.textCtrl,
    required this.orbState, required this.volume, required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF080D1A),
        border: Border(
          top: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.1), width: 0.5),
        ),
      ),
      child: Row(
        children: [

          // Orb mic button
          ZaraFloatingOrb(
            state:       orbState,
            volumeLevel: volume,
            onTap: () => ctrl.isListening
                ? ctrl.stopListening()
                : ctrl.startListening(),
          ),

          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: TextField(
              controller: textCtrl,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: ctrl.realtimeActive
                    ? 'Hands-Free active — bolna shuru karo...'
                    : 'Kuch bolo ya type karo...',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.28), fontSize: 12),
                filled:        true,
                fillColor:     const Color(0xFF0D1525),
                border:        OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:   BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: AppColors.cyanPrimary.withOpacity(0.4))),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
              maxLines: 3, minLines: 1,
              textInputAction: TextInputAction.send,
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color:  AppColors.cyanPrimary.withOpacity(0.12),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: AppColors.cyanPrimary.withOpacity(0.4), width: 1.2),
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppColors.cyanPrimary, size: 18),
            ),
          ),

        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// GRID BACKGROUND
// ══════════════════════════════════════════════════════════════════════════

class _GridBackground extends StatelessWidget {
  const _GridBackground();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter());
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color       = const Color(0xFF00F0FF).withOpacity(0.035)
      ..strokeWidth = 0.5;
    const step = 42.0;
    for (double x = 0; x < size.width;  x += step)
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += step)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override bool shouldRepaint(_) => false;
}

// lib/widgets/zara_overlay_chat.dart
// Z.A.R.A. v7.0 — Floating Overlay Chat
//
// Ek transparent floating panel jo HAR app ke upar dikhta hai.
// Andar se:
//   - Last 3 messages (user + Zara) show karta hai
//   - Mic button — tap to speak
//   - Hands-Free toggle — activate karo, Zara continuously sunega
//   - Orb state indicator — still/listening/thinking/speaking
//   - Draggable — screen pe kahin bhi move karo
//   - Double-tap header = collapse/expand
//
// Native side: ZaraForegroundService.kt ka overlay orb alag hai.
// Ye Flutter side ka chat overlay hai — app ke andar show hota hai
// aur system overlay (ZaraForegroundService) ke saath sync hota hai.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';

class ZaraOverlayChatManager extends StatefulWidget {
  final Widget child;
  const ZaraOverlayChatManager({super.key, required this.child});

  @override
  State<ZaraOverlayChatManager> createState() => _ZaraOverlayChatManagerState();
}

class _ZaraOverlayChatManagerState extends State<ZaraOverlayChatManager> {
  bool _overlayVisible = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_overlayVisible)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: ZaraOverlayChatPanel(
                onClose: () => setState(() => _overlayVisible = false),
              ),
            ),
          ),
        // Floating trigger button — always visible, bottom-right
        Positioned(
          right: 16,
          bottom: 100,
          child: _OverlayTriggerButton(
            isOpen: _overlayVisible,
            onTap: () => setState(() => _overlayVisible = !_overlayVisible),
          ),
        ),
      ],
    );
  }
}

// ── Trigger button ──────────────────────────────────────────────────────────

class _OverlayTriggerButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onTap;
  const _OverlayTriggerButton({required this.isOpen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(
      builder: (_, ctrl, __) {
        final color = ctrl.isSpeaking  ? const Color(0xFFBB00FF) :
                      ctrl.isListening ? const Color(0xFF00FF88) :
                      ctrl.realtimeActive ? const Color(0xFF00CCFF) :
                      const Color(0xFF00CCFF);
        final hasPending = ctrl.pendingReply != null;
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color, width: 2),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.4),
                      blurRadius: 12, spreadRadius: 2)],
                ),
                child: Icon(
                  isOpen ? Icons.close : Icons.chat_bubble_outline,
                  color: color, size: 22,
                ),
              ),
              // Pending reply notification badge
              if (hasPending)
                Positioned(
                  top: -3, right: -3,
                  child: Container(
                    width: 18, height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00FF88),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: Colors.black,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// OVERLAY CHAT PANEL
// ══════════════════════════════════════════════════════════════════════════

class ZaraOverlayChatPanel extends StatefulWidget {
  final VoidCallback onClose;
  const ZaraOverlayChatPanel({super.key, required this.onClose});

  @override
  State<ZaraOverlayChatPanel> createState() => _ZaraOverlayChatPanelState();
}

class _ZaraOverlayChatPanelState extends State<ZaraOverlayChatPanel>
    with SingleTickerProviderStateMixin {

  late AnimationController _anim;
  late Animation<double>   _scale;

  bool _collapsed    = false;
  bool _showInput    = false;
  final _textCtrl    = TextEditingController();
  final _scrollCtrl  = ScrollController();

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ZaraController>(
      builder: (ctx, ctrl, _) {
        final messages = ctrl.state.messages;
        final recent   = messages.length > 4
            ? messages.sublist(messages.length - 4)
            : messages;

        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
            child: ScaleTransition(
              scale: _scale,
              child: _collapsed
                  ? _buildCollapsed(ctrl)
                  : _buildExpanded(ctrl, recent),
            ),
          ),
        );
      },
    );
  }

  // ── Collapsed view — just orb + status ───────────────────────────────────

  Widget _buildCollapsed(ZaraController ctrl) {
    final color = _orbColor(ctrl);
    return GestureDetector(
      onTap: () => setState(() => _collapsed = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF050F1A).withOpacity(0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withOpacity(0.6)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3),
              blurRadius: 12)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _OrbDot(color: color, animate: ctrl.isSpeaking || ctrl.isListening),
          const SizedBox(width: 10),
          Text(
            ctrl.isSpeaking  ? 'Bol rahi hoon...' :
            ctrl.isListening ? 'Sun rahi hoon...' :
            ctrl.realtimeActive ? 'Hands-Free ON' : 'Z.A.R.A.',
            style: TextStyle(color: color, fontSize: 13,
                fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          Icon(Icons.expand_less, color: color, size: 16),
        ]),
      ),
    );
  }

  // ── Expanded view ─────────────────────────────────────────────────────────

  Widget _buildExpanded(ZaraController ctrl, List<ChatMessage> recent) {
    final color = _orbColor(ctrl);
    return Container(
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: const Color(0xFF050F1A).withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 20),
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 10),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(ctrl, color),
          const Divider(color: Color(0xFF1A3040), height: 1),
          // ── PENDING REPLY BANNER ─────────────────────────────────────────
          if (ctrl.pendingReply != null) _buildPendingReplyBanner(ctrl, color),
          if (recent.isNotEmpty) _buildMessages(recent, color),
          const Divider(color: Color(0xFF1A3040), height: 1),
          _buildControls(ctrl, color),
          if (_showInput) _buildTextInput(ctrl, color),
        ],
      ),
    );
  }

  // ── Pending Reply Banner — Jarvis-style message card ─────────────────────

  Widget _buildPendingReplyBanner(ZaraController ctrl, Color color) {
    final pending = ctrl.pendingReply!;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF001A0A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
        boxShadow: [BoxShadow(
          color: const Color(0xFF00FF88).withOpacity(0.12),
          blurRadius: 8,
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App + contact header
          Row(children: [
            Icon(Icons.message_rounded,
                color: const Color(0xFF00FF88), size: 14),
            const SizedBox(width: 6),
            Text(
              '${pending.app} · ${pending.contact}',
              style: const TextStyle(
                color: Color(0xFF00FF88), fontSize: 11,
                fontWeight: FontWeight.bold, fontFamily: 'monospace',
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: ctrl.dismissPendingReply,
              child: const Icon(Icons.close,
                  color: Colors.white24, size: 14),
            ),
          ]),
          const SizedBox(height: 6),
          // Message text
          Text(
            '"${pending.message}"',
            style: const TextStyle(
              color: Colors.white70, fontSize: 12,
              fontFamily: 'monospace', fontStyle: FontStyle.italic,
            ),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(children: [
            // Quick reply via voice
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // Listen for reply then approve
                  ctrl.startListening(onTranscribed: (text) {
                    ctrl.approvePendingReply(text);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF88).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic, color: Color(0xFF00FF88), size: 13),
                      SizedBox(width: 4),
                      Text('Bolke Reply',
                        style: TextStyle(
                          color: Color(0xFF00FF88), fontSize: 10,
                          fontFamily: 'monospace',
                        )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // AI auto-reply
            Expanded(
              child: GestureDetector(
                onTap: () => ctrl.approvePendingReply(''),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBB00FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFBB00FF).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome,
                          color: Color(0xFFBB00FF), size: 13),
                      SizedBox(width: 4),
                      Text('AI Reply',
                        style: TextStyle(
                          color: Color(0xFFBB00FF), fontSize: 10,
                          fontFamily: 'monospace',
                        )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Dismiss
            GestureDetector(
              onTap: ctrl.dismissPendingReply,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text('Skip',
                  style: TextStyle(
                    color: Colors.white38, fontSize: 10,
                    fontFamily: 'monospace',
                  )),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(ZaraController ctrl, Color color) {
    return GestureDetector(
      onDoubleTap: () => setState(() => _collapsed = true),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        child: Row(children: [
          _OrbDot(color: color, animate: ctrl.isSpeaking || ctrl.isListening),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Z.A.R.A.', style: TextStyle(
                  color: color, fontSize: 13, letterSpacing: 2,
                  fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              Text(
                ctrl.isSpeaking     ? '● Speaking...'      :
                ctrl.isListening    ? '● Listening...'     :
                ctrl.realtimeActive ? '● Hands-Free ACTIVE' :
                ctrl.state.isProcessing ? '● Thinking...'  : '● Standby',
                style: TextStyle(
                    color: color.withOpacity(0.7),
                    fontSize: 10, fontFamily: 'monospace'),
              ),
            ]),
          ),
          // Hands-Free toggle
          GestureDetector(
            onTap: () => ctrl.toggleRealtime(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ctrl.realtimeActive
                    ? const Color(0xFF00FF88).withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ctrl.realtimeActive
                      ? const Color(0xFF00FF88)
                      : Colors.white24,
                ),
              ),
              child: Text(
                ctrl.realtimeActive ? '🎙 ON' : '🎙 OFF',
                style: TextStyle(
                    fontSize: 11,
                    color: ctrl.realtimeActive
                        ? const Color(0xFF00FF88)
                        : Colors.white54),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClose,
            child: const Icon(Icons.close, color: Colors.white38, size: 18),
          ),
        ]),
      ),
    );
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Widget _buildMessages(List<ChatMessage> messages, Color color) {
    return Flexible(
      child: ListView.builder(
        controller: _scrollCtrl,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: messages.length,
        itemBuilder: (_, i) {
          final m      = messages[i];
          final isUser = m.role == MessageRole.user;
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: isUser
                    ? color.withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isUser ? color.withOpacity(0.4) : Colors.white12,
                ),
              ),
              child: Text(
                m.text,
                style: TextStyle(
                  color: isUser ? color : Colors.white70,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────────────────────

  Widget _buildControls(ZaraController ctrl, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // Mic button
        _ControlBtn(
          icon:    ctrl.isListening ? Icons.stop : Icons.mic,
          color:   ctrl.isListening ? Colors.red : color,
          label:   ctrl.isListening ? 'Stop' : 'Mic',
          onTap:   () => ctrl.isListening
              ? ctrl.stopListening()
              : ctrl.startListening(),
          pulse:   ctrl.isListening,
        ),
        const SizedBox(width: 8),
        // Text input toggle
        _ControlBtn(
          icon:  Icons.keyboard,
          color: _showInput ? color : Colors.white38,
          label: 'Type',
          onTap: () => setState(() => _showInput = !_showInput),
        ),
        const SizedBox(width: 8),
        // Repeat last response
        _ControlBtn(
          icon:  Icons.volume_up,
          color: Colors.white38,
          label: 'Repeat',
          onTap: () => ctrl.speakLastResponse(),
        ),
        const Spacer(),
        // Collapse
        GestureDetector(
          onTap: () => setState(() => _collapsed = true),
          child: const Icon(Icons.expand_more, color: Colors.white24, size: 20),
        ),
      ]),
    );
  }

  // ── Text input ─────────────────────────────────────────────────────────────

  Widget _buildTextInput(ZaraController ctrl, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _textCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Kuch bolo Sir...',
              hintStyle: TextStyle(color: color.withOpacity(0.4), fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color.withOpacity(0.3)),
              ),
            ),
            onSubmitted: (t) {
              if (t.trim().isNotEmpty) {
                ctrl.receiveCommand(t.trim());
                _textCtrl.clear();
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            final t = _textCtrl.text.trim();
            if (t.isNotEmpty) { ctrl.receiveCommand(t); _textCtrl.clear(); }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(Icons.send, color: color, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _orbColor(ZaraController ctrl) {
    if (ctrl.isSpeaking)    return const Color(0xFFBB00FF);
    if (ctrl.isListening)   return const Color(0xFF00FF88);
    if (ctrl.realtimeActive) return const Color(0xFF00CCFF);
    return const Color(0xFF00CCFF);
  }
}

// ── Orb dot ────────────────────────────────────────────────────────────────

class _OrbDot extends StatefulWidget {
  final Color color;
  final bool  animate;
  const _OrbDot({required this.color, required this.animate});

  @override
  State<_OrbDot> createState() => _OrbDotState();
}

class _OrbDotState extends State<_OrbDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double>   _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.5, end: 1.0).animate(_c);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(width: 10, height: 10,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: widget.color));
    }
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withOpacity(_a.value),
          boxShadow: [BoxShadow(
              color: widget.color.withOpacity(_a.value * 0.6),
              blurRadius: 8)],
        ),
      ),
    );
  }
}

// ── Control button ─────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final VoidCallback onTap;
  final bool     pulse;
  const _ControlBtn({
    required this.icon, required this.color,
    required this.label, required this.onTap,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 9, fontFamily: 'monospace')),
      ]),
    );
  }
}

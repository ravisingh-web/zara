// lib/features/hologram_ui/widgets/central_response_panel.dart
// Z.A.R.A. — Chat Panel v2.0
// ✅ ChatMessage model (Left=Zara, Right=User)
// ✅ Long-press: Copy / Edit / Delete
// ✅ Timestamp on each bubble
// ✅ Typing indicator while AI processes
// ✅ Glassmorphic cyberpunk bubbles (same visual style)
// ✅ Keyboard-safe via external ScrollController

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/features/zara_engine/providers/zara_provider.dart';
import 'package:zara/features/zara_engine/models/zara_state.dart';

class CentralResponsePanel extends StatelessWidget {
  final ScrollController scrollCtrl;

  const CentralResponsePanel({
    super.key,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final zara  = context.watch<ZaraController>();
    final state = zara.state;
    final msgs  = state.messages;

    return Stack(children: [
      // Background branding logo (unchanged)
      _buildNeuralLogo(),

      // Chat message list
      Positioned.fill(
        top: 90,
        bottom: 8,
        child: msgs.isEmpty
            ? const SizedBox.shrink()
            : ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: msgs.length + (state.isProcessing ? 1 : 0),
                itemBuilder: (ctx, i) {
                  // Typing indicator as last item
                  if (state.isProcessing && i == msgs.length) {
                    return _TypingIndicator(moodColor: state.mood.primaryColor);
                  }
                  final msg  = msgs[i];
                  final prev = i > 0 ? msgs[i - 1] : null;
                  final showDate = prev == null ||
                      !_sameDay(msg.timestamp, prev.timestamp);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate) _DateDivider(dt: msg.timestamp),
                      _ChatBubble(
                        message:    msg,
                        moodColor:  state.mood.primaryColor,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Copied!'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onEdit: msg.role == MessageRole.user
                            ? (newText) =>
                                context.read<ZaraController>()
                                    .editMessage(msg.id, newText)
                            : null,
                        onDelete: () =>
                            context.read<ZaraController>()
                                .deleteMessage(msg.id),
                      ),
                    ],
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildNeuralLogo() {
    return Align(
      alignment: Alignment.center,
      child: Opacity(
        opacity: 0.10,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 50),
          const Text('BIOMETRIC INTELLIGENCE INTERFACE',
              style: TextStyle(
                color: AppColors.neonCyan, fontSize: 8, letterSpacing: 4,
              )),
          const SizedBox(height: 10),
          Text(
            'ZARA AI',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontSize: 52,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
              fontFamily: 'monospace',
              shadows: [
                Shadow(color: AppColors.neonCyan.withOpacity(0.5), blurRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 5),
          const Text('ADVANCED NEURAL COMMAND SYSTEM',
              style: TextStyle(
                color: AppColors.neonCyan, fontSize: 10,
                letterSpacing: 3, fontFamily: 'monospace',
              )),
        ]),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─── Single Chat Bubble ────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Color moodColor;
  final VoidCallback onCopy;
  final ValueChanged<String>? onEdit;
  final VoidCallback onDelete;

  const _ChatBubble({
    required this.message,
    required this.moodColor,
    required this.onCopy,
    this.onEdit,
    required this.onDelete,
  });

  bool get _isZara   => message.role == MessageRole.zara;
  bool get _isSystem => message.role == MessageRole.system;

  @override
  Widget build(BuildContext context) {
    if (_isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(message.text,
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ),
        ),
      );
    }

    final borderColor = _isZara
        ? moodColor.withOpacity(0.5)
        : AppColors.neonGreen.withOpacity(0.45);
    final shadowColor = _isZara
        ? moodColor.withOpacity(0.12)
        : AppColors.neonGreen.withOpacity(0.12);
    final senderLabel = _isZara ? 'Z.A.R.A.' : 'OWNER RAVI';
    final labelColor  = _isZara ? moodColor : AppColors.neonGreen;

    return Align(
      alignment: _isZara ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: GestureDetector(
          onLongPress: () => _showMenu(context),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: _isZara
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                // Sender label
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
                  child: Text(senderLabel,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      )),
                ),
                // Bubble
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  _isZara ? Radius.zero : const Radius.circular(16),
                    bottomRight: _isZara ? const Radius.circular(16) : Radius.zero,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        border: Border.all(color: borderColor, width: 1),
                        borderRadius: BorderRadius.only(
                          topLeft:     const Radius.circular(16),
                          topRight:    const Radius.circular(16),
                          bottomLeft:  _isZara
                              ? Radius.zero
                              : const Radius.circular(16),
                          bottomRight: _isZara
                              ? const Radius.circular(16)
                              : Radius.zero,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 14, spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Message text
                          SelectableText(
                            message.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Timestamp + edited tag
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('hh:mm a').format(message.timestamp),
                                style: TextStyle(
                                  color: labelColor.withOpacity(0.5),
                                  fontSize: 9,
                                ),
                              ),
                              if (message.isEdited) ...[
                                const SizedBox(width: 4),
                                Text('edited',
                                    style: TextStyle(
                                      color: Colors.white24,
                                      fontSize: 9,
                                      fontStyle: FontStyle.italic,
                                    )),
                              ],
                              if (!_isZara) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.done_all_rounded,
                                    size: 11, color: moodColor.withOpacity(0.7)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BubbleMenu(
        text:     message.text,
        canEdit:  onEdit != null,
        onCopy:   onCopy,
        onEdit:   onEdit != null
            ? () => _showEditDialog(context)
            : null,
        onDelete: onDelete,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.deepSpaceBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3)),
        ),
        title: const Text('Edit Message',
            style: TextStyle(color: AppColors.cyanPrimary, fontSize: 13)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: null,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.black38,
            border: OutlineInputBorder(borderSide: BorderSide.none),
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
              backgroundColor: AppColors.cyanPrimary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              onEdit!(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ──────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  final Color moodColor;
  const _TypingIndicator({required this.moodColor});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(16),
            topRight:    Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: widget.moodColor.withOpacity(0.4),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Row(
              children: List.generate(3, (i) {
                final delay = i / 3;
                final value = ((_ctrl.value - delay) % 1.0).abs();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.moodColor.withOpacity(
                      value < 0.5 ? 0.3 + value * 1.4 : 1.0 - value,
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Date Divider ──────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime dt;
  const _DateDivider({required this.dt});

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final label = _sameDay(dt, now)
        ? 'Today'
        : _sameDay(dt, now.subtract(const Duration(days: 1)))
            ? 'Yesterday'
            : DateFormat('d MMM yyyy').format(dt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label,
              style: const TextStyle(
                color: Colors.white24, fontSize: 9, fontFamily: 'monospace',
              )),
        ),
        Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
      ]),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─── Long-Press Menu ───────────────────────────────────────────────────────
class _BubbleMenu extends StatelessWidget {
  final String text;
  final bool canEdit;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const _BubbleMenu({
    required this.text,
    required this.canEdit,
    required this.onCopy,
    this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF080C18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.cyanPrimary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyanPrimary.withOpacity(0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Preview
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Text(
            text.length > 80 ? '${text.substring(0, 80)}…' : text,
            style: const TextStyle(
              color: Colors.white38, fontSize: 11, fontFamily: 'monospace',
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        _item(context, Icons.copy_rounded,   'Copy',   Colors.white70, onCopy),
        if (canEdit && onEdit != null) ...[
          const Divider(color: Colors.white12, height: 1),
          _item(context, Icons.edit_rounded,  'Edit',   Colors.amberAccent, onEdit!),
        ],
        const Divider(color: Colors.white12, height: 1),
        _item(context, Icons.delete_outline_rounded, 'Delete',
            AppColors.errorRed, onDelete),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ]),
      ),
    );
  }
}

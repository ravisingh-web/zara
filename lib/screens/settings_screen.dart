// lib/screens/settings_screen.dart
// Z.A.R.A. v15.0 — Settings
//
// APIs: Gemini · ElevenLabs · OpenAI (Whisper) · Mem0 · LiveKit
// ❌ n8n webhooks  — REMOVED
// ❌ Google Sheets — REMOVED
// ✅ Vosk wake word — offline, no key

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/services/accessibility_service.dart';
import 'package:zara/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  bool _loading = false;
  bool _saving  = false;
  bool _accessOn  = false;
  bool _notifOn   = false;
  bool _overlayOn = false;
  Map<Permission, PermissionStatus> _perms = {};

  // ── Controllers — only the 5 active services ──────────────────────────────
  final _gemCtrl    = TextEditingController();
  final _elCtrl     = TextEditingController();
  final _oaiCtrl    = TextEditingController();
  final _mem0Ctrl   = TextEditingController();
  final _lkUrlCtrl  = TextEditingController();
  final _lkTokCtrl  = TextEditingController();
  final _ownerCtrl  = TextEditingController();
  final _userIdCtrl = TextEditingController();

  // ── Visibility toggles ─────────────────────────────────────────────────────
  bool _hideGem   = true;
  bool _hideEl    = true;
  bool _hideOai   = true;
  bool _hideMem0  = true;
  bool _hideLkTok = true;

  // ── Form state ─────────────────────────────────────────────────────────────
  String _model = 'gemini-2.5-flash';
  String _lang  = 'hi-IN';
  int    _aff   = 85;

  Map<String, String> _msgs  = {};
  Map<String, bool>   _valid = {};

  static const _langs = [
    'hi-IN','en-US','en-GB','mr-IN','gu-IN','ta-IN','ur-PK',
  ];

  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _gemCtrl, _elCtrl, _oaiCtrl, _mem0Ctrl,
      _lkUrlCtrl, _lkTokCtrl, _ownerCtrl, _userIdCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);

    _gemCtrl.text    = ApiKeys.geminiKey;
    _elCtrl.text     = ApiKeys.elevenKey;
    _oaiCtrl.text    = ApiKeys.openaiKey;
    _mem0Ctrl.text   = ApiKeys.mem0Key;
    _lkUrlCtrl.text  = ApiKeys.livekitUrl;
    _lkTokCtrl.text  = ApiKeys.livekitToken;
    _ownerCtrl.text  = ApiKeys.ownerName;
    _userIdCtrl.text = ApiKeys.mem0UserId;
    _aff             = ApiKeys.affection;

    final ids = ApiKeys.geminiModels.map((m) => m['id']!).toList();
    _model = ids.contains(ApiKeys.geminiModel) ? ApiKeys.geminiModel : ids.first;
    _lang  = _langs.contains(ApiKeys.lang) ? ApiKeys.lang : 'hi-IN';

    _validate('gem',   _gemCtrl.text);
    _validate('el',    _elCtrl.text);
    _validate('oai',   _oaiCtrl.text);
    _validate('mem0',  _mem0Ctrl.text);
    _validate('lkUrl', _lkUrlCtrl.text);
    _validate('lkTok', _lkTokCtrl.text);

    await _loadPerms();
    try { _accessOn  = await AccessibilityService().checkEnabled(); } catch (_) {}
    try { _notifOn   = await NotificationService().isEnabled();    } catch (_) {}
    try { _overlayOn = await NotificationService().hasOverlayPermission(); } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPerms() async {
    final m = <Permission, PermissionStatus>{};
    for (final p in [
      Permission.microphone,
      Permission.camera,
      Permission.location,
      Permission.notification,
      Permission.manageExternalStorage,
    ]) { m[p] = await p.status; }
    if (mounted) setState(() => _perms = m);
  }

  // ── Validate ──────────────────────────────────────────────────────────────
  void _validate(String key, String val) {
    String msg = '';
    bool   ok  = false;

    switch (key) {
      case 'gem':
        if (val.isEmpty) {
          msg = 'Required — Brain nahi chalega'; ok = false;
        } else if (RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(val)) {
          msg = '✓ Valid'; ok = true;
        } else {
          msg = 'AIza... se shuru hona chahiye'; ok = false;
        }
      case 'el':
        if (val.isEmpty)        { msg = 'Required — Voice nahi aayegi'; ok = false; }
        else if (val.length>=20){ msg = '✓ Valid'; ok = true; }
        else                    { msg = 'Too short'; ok = false; }
      case 'oai':
        if (val.isEmpty)         { msg = 'Optional — Whisper STT ke liye'; ok = false; }
        else if (val.startsWith('sk-')) { msg = '✓ Valid'; ok = true; }
        else                     { msg = 'sk- se shuru hona chahiye'; ok = false; }
      case 'mem0':
        if (val.isEmpty)         { msg = 'Optional — yaadein nahi rahegi'; ok = false; }
        else if (val.length>=10) { msg = '✓ Valid'; ok = true; }
        else                     { msg = 'Too short'; ok = false; }
      case 'lkUrl':
        if (val.isEmpty)         { msg = 'Optional — real-time voice ke liye'; ok = false; }
        else if (val.startsWith('wss://') || val.startsWith('ws://')) {
          msg = '✓ Valid'; ok = true;
        } else {
          msg = 'wss:// se shuru karo'; ok = false;
        }
      case 'lkTok':
        if (val.isEmpty)         { msg = 'LiveKit room token'; ok = false; }
        else if (val.length>=20) { msg = '✓ Valid'; ok = true; }
        else                     { msg = 'Too short'; ok = false; }
    }

    _msgs[key]  = msg;
    _valid[key] = ok;
    if (mounted) setState(() {});
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_valid['gem'] ?? false)) {
      _toast('Gemini key required hai', AppColors.errorRed);
      return;
    }
    if (!(_valid['el'] ?? false)) {
      _toast('ElevenLabs key bhi zaroori hai!', AppColors.warningOrange);
    }

    setState(() => _saving = true);
    try {
      final ok = await ApiKeys.save(
        geminiKey:    _gemCtrl.text,
        elevenKey:    _elCtrl.text,
        openaiKey:    _oaiCtrl.text,
        mem0Key:      _mem0Ctrl.text,
        livekitUrl:   _lkUrlCtrl.text,
        livekitToken: _lkTokCtrl.text,
        geminiModel:  _model,
        lang:         _lang,
        ownerName:    _ownerCtrl.text,
        mem0UserId:   _userIdCtrl.text,
        affection:    _aff,
      );
      if (!mounted) return;
      if (ok) {
        _toast('Saved! Zara ready hai ✅', AppColors.successGreen);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.pop(context);
      } else {
        _toast('Save failed', AppColors.errorRed);
      }
    } catch (e) {
      if (mounted) _toast('Error: $e', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: c, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Future<void> _url(String u) async {
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepSpaceBlack,
    appBar: AppBar(
      title: const Text('Z.A.R.A. SETTINGS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 13, letterSpacing: 2,
          color: AppColors.cyanPrimary)),
      backgroundColor: Colors.transparent, elevation: 0,
      foregroundColor: AppColors.cyanPrimary,
      actions: [
        IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        const SizedBox(width: 8),
      ],
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: AppColors.cyanPrimary,
        labelColor: AppColors.cyanPrimary,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(fontSize: 11, letterSpacing: 1),
        tabs: const [
          Tab(text: 'APIs'),
          Tab(text: 'SYSTEM'),
          Tab(text: 'PERMISSIONS'),
        ],
      ),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.cyanPrimary))
        : TabBarView(
            controller: _tabs,
            children: [_apisTab(), _systemTab(), _permsTab()],
          ),
    bottomNavigationBar: _saveBar(),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // APIs TAB — 5 services + Vosk info card
  // ══════════════════════════════════════════════════════════════════════════

  Widget _apisTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _statusBanner(),
    const SizedBox(height: 16),

    // 1 — Gemini (required)
    _apiCard(
      color:   const Color(0xFF4FC3F7),
      icon:    Icons.psychology_rounded,
      title:   '1 · GEMINI',
      subtitle: 'AI Brain — chat, reasoning, God Mode vision',
      link:    'Get Key →',
      linkUrl: 'https://aistudio.google.com/apikey',
      child: _keyField(
        _gemCtrl, 'AIzaSy...', _hideGem,
        () => setState(() => _hideGem = !_hideGem),
        (v) => _validate('gem', v),
        _valid['gem'] ?? false, _msgs['gem'] ?? '',
      ),
    ),
    const SizedBox(height: 12),

    // 2 — ElevenLabs (required)
    _apiCard(
      color:   const Color(0xFF7B2FFF),
      icon:    Icons.record_voice_over_rounded,
      title:   '2 · ELEVENLABS',
      subtitle: 'Anjura voice — streaming TTS (eleven_turbo_v2_5)',
      link:    'Get Key →',
      linkUrl: 'https://elevenlabs.io/app/subscription',
      child: Column(children: [
        _keyField(
          _elCtrl, 'ElevenLabs API key...', _hideEl,
          () => setState(() => _hideEl = !_hideEl),
          (v) => _validate('el', v),
          _valid['el'] ?? false, _msgs['el'] ?? '',
        ),
        const SizedBox(height: 8),
        _infoChip(
          const Color(0xFF7B2FFF),
          Icons.lock_rounded,
          'Voice: Anjura  ·  ID: rdz6GofVsYlLgQl2dBEE  ·  Model: eleven_turbo_v2_5',
        ),
      ]),
    ),
    const SizedBox(height: 12),

    // 3 — OpenAI / Whisper (optional)
    _apiCard(
      color:   const Color(0xFF4CAF50),
      icon:    Icons.mic_rounded,
      title:   '3 · OPENAI  (Whisper STT)',
      subtitle: 'Voice → Text — optional, Vosk handles wake word',
      link:    'Get Key →',
      linkUrl: 'https://platform.openai.com/api-keys',
      child: _keyField(
        _oaiCtrl, 'sk-...', _hideOai,
        () => setState(() => _hideOai = !_hideOai),
        (v) => _validate('oai', v),
        _valid['oai'] ?? false, _msgs['oai'] ?? '',
      ),
    ),
    const SizedBox(height: 12),

    // 4 — Mem0 (optional)
    _apiCard(
      color:   const Color(0xFFFF9800),
      icon:    Icons.memory_rounded,
      title:   '4 · MEM0',
      subtitle: 'Neural memory — Ravi ji ko hamesha yaad rakhna',
      link:    'Get Key →',
      linkUrl: 'https://app.mem0.ai/dashboard/api-keys',
      child: _keyField(
        _mem0Ctrl, 'm0-...', _hideMem0,
        () => setState(() => _hideMem0 = !_hideMem0),
        (v) => _validate('mem0', v),
        _valid['mem0'] ?? false, _msgs['mem0'] ?? '',
      ),
    ),
    const SizedBox(height: 12),

    // 5 — LiveKit (optional)
    _apiCard(
      color:   const Color(0xFF9C27B0),
      icon:    Icons.graphic_eq_rounded,
      title:   '5 · LIVEKIT',
      subtitle: 'Real-time voice room — ultra-low latency',
      link:    'Dashboard →',
      linkUrl: 'https://cloud.livekit.io',
      child: Column(children: [
        _plainField(
          _lkUrlCtrl, 'wss://your-project.livekit.cloud',
          (v) => _validate('lkUrl', v),
        ),
        const SizedBox(height: 8),
        _keyField(
          _lkTokCtrl, 'LiveKit room token...', _hideLkTok,
          () => setState(() => _hideLkTok = !_hideLkTok),
          (v) => _validate('lkTok', v),
          _valid['lkTok'] ?? false, _msgs['lkTok'] ?? '',
        ),
      ]),
    ),
    const SizedBox(height: 12),

    // Vosk info (no key needed)
    _voskInfoCard(),
    const SizedBox(height: 24),
  ]);

  Widget _voskInfoCard() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0D2B1F),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.35)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.hearing_rounded, color: Color(0xFF00FF88), size: 18),
      ),
      const SizedBox(width: 12),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Wake Word: Vosk  (OFFLINE)',
            style: TextStyle(color: Color(0xFF00FF88),
                fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        SizedBox(height: 4),
        Text(
          '"Hii Zara" / "Sunna" — no API key, zero internet\n'
          'Model  → assets/model/ (vosk-model-small-en-in-0.4)\n'
          'Download → alphacephei.com/vosk/models',
          style: TextStyle(color: Colors.white54, fontSize: 10, height: 1.6),
        ),
      ])),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // SYSTEM TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _systemTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _sectionHeader('🤖  BRAIN MODEL'),
    _box(_modelDropdown()),
    const SizedBox(height: 14),

    _sectionHeader('🌐  LANGUAGE'),
    _box(DropdownButtonFormField<String>(
      value: _lang, dropdownColor: AppColors.deepSpaceBlue,
      isExpanded: true, isDense: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _dropDeco(),
      items: _langs.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
      onChanged: (v) { if (v != null) setState(() => _lang = v); },
    )),
    const SizedBox(height: 14),

    _sectionHeader('👤  PERSONALIZATION'),
    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _textInput(_ownerCtrl, 'Your Name  (Ravi ji ka naam)'),
      const SizedBox(height: 10),
      _textInput(_userIdCtrl, 'Mem0 User ID  (default: zara_ravi)'),
      const SizedBox(height: 14),
      Row(children: [
        const Text('Affection Level',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text('$_aff%', style: TextStyle(
            color: _affColor(_aff),
            fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      Slider(
        value: _aff.toDouble(), min: 0, max: 100, divisions: 10,
        activeColor: _affColor(_aff), inactiveColor: Colors.white12,
        onChanged: (v) => setState(() => _aff = v.toInt()),
      ),
    ])),
    const SizedBox(height: 24),
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // PERMISSIONS TAB
  // ══════════════════════════════════════════════════════════════════════════

  Widget _permsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _box(Column(children: [
      _permRow(Icons.accessibility_new, 'Accessibility Service',
          'God Mode — device control', _accessOn,
          special: true, onTap: () async {
            try { await AccessibilityService().openSettings(); } catch (_) {}
            await Future.delayed(const Duration(seconds: 2));
            try { final e = await AccessibilityService().checkEnabled();
              if (mounted) setState(() => _accessOn = e); } catch (_) {}
          }),
      _permRow(Icons.notifications_active, 'Notification Listener',
          'Proactive WhatsApp/Gmail alerts', _notifOn,
          onTap: () async {
            await NotificationService().openSettings();
            await Future.delayed(const Duration(seconds: 2));
            try { final e = await NotificationService().isEnabled();
              if (mounted) setState(() => _notifOn = e); } catch (_) {}
          }),
      _permRow(Icons.picture_in_picture, 'Overlay Permission',
          'Floating orb on screen', _overlayOn,
          onTap: () async {
            await NotificationService().openOverlaySettings();
            await Future.delayed(const Duration(seconds: 2));
            try { final e = await NotificationService().hasOverlayPermission();
              if (mounted) setState(() => _overlayOn = e); } catch (_) {}
          }),
      _permRow(Icons.mic, 'Microphone',
          'Wake word + Whisper STT', _perms[Permission.microphone]?.isGranted ?? false,
          onTap: () => _grant(Permission.microphone)),
      _permRow(Icons.camera_alt, 'Camera',
          'Vision + Intruder detection', _perms[Permission.camera]?.isGranted ?? false,
          onTap: () => _grant(Permission.camera)),
      _permRow(Icons.location_on, 'Location',
          'GPS tracking', _perms[Permission.location]?.isGranted ?? false,
          onTap: () => _grant(Permission.location)),
      _permRow(Icons.notifications, 'Notifications',
          'Alerts + heads-up', _perms[Permission.notification]?.isGranted ?? false,
          onTap: () => _grant(Permission.notification)),
      _permRow(Icons.folder_open, 'All Files Access',
          'God Mode — file operations', _perms[Permission.manageExternalStorage]?.isGranted ?? false,
          onTap: () => _grant(Permission.manageExternalStorage), last: true),
    ])),
    const SizedBox(height: 24),
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // STATUS BANNER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _statusBanner() {
    final g = ApiKeys.geminiReady;
    final e = ApiKeys.elevenReady;
    final o = ApiKeys.openaiReady;
    final m = ApiKeys.mem0Ready;
    final l = ApiKeys.livekitReady;
    final count = [g, e, o, m, l].where((x) => x).length;

    final c = count == 5 ? AppColors.successGreen
        : count >= 2     ? AppColors.warningOrange
        : AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(count >= 2 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: c, size: 18),
          const SizedBox(width: 8),
          Text('$count / 5 APIs configured',
              style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        _statusRow('Gemini',     g, required: true),
        _statusRow('ElevenLabs', e, required: true),
        _statusRow('OpenAI',     o),
        _statusRow('Mem0',       m),
        _statusRow('LiveKit',    l),
        const SizedBox(height: 4),
        _statusRow('Vosk (offline)', true, icon: Icons.wifi_off_rounded),
      ]),
    );
  }

  Widget _statusRow(String name, bool ok, {bool required = false, IconData? icon}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(
          icon ?? (ok ? Icons.check_circle : Icons.radio_button_unchecked),
          size: 12,
          color: ok ? AppColors.successGreen
              : required ? AppColors.errorRed
              : Colors.white30,
        ),
        const SizedBox(width: 6),
        Text(
          '$name${required && !ok ? "  ← Required" : ""}',
          style: TextStyle(
            fontSize: 10,
            color: ok ? Colors.white70
                : required ? AppColors.errorRed
                : Colors.white30,
          ),
        ),
      ]),
    );

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _apiCard({
    required Color    color,
    required IconData icon,
    required String   title,
    required String   subtitle,
    required String   link,
    required String   linkUrl,
    required Widget   child,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold,
              fontSize: 12, letterSpacing: 0.8)),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
        GestureDetector(
          onTap: () => _url(linkUrl),
          child: Text(link, style: TextStyle(color: color, fontSize: 10,
              decoration: TextDecoration.underline, decorationColor: color)),
        ),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Widget _keyField(
    TextEditingController ctrl,
    String hint,
    bool hide,
    VoidCallback toggle,
    ValueChanged<String> onChanged,
    bool valid,
    String msg, {
    bool obscureToggle = true,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(
      controller: ctrl,
      obscureText: hide,
      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
      decoration: InputDecoration(
        isDense: true, filled: true, fillColor: Colors.black38,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (obscureToggle)
            IconButton(
              icon: Icon(hide ? Icons.visibility_off : Icons.visibility,
                  size: 14, color: Colors.white38),
              onPressed: toggle,
            ),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 14, color: Colors.white38),
            onPressed: () async {
              final c = await Clipboard.getData('text/plain');
              if (c?.text != null) { ctrl.text = c!.text!; onChanged(c.text!); }
            },
          ),
        ]),
      ),
      onChanged: onChanged,
    ),
    const SizedBox(height: 3),
    Row(children: [
      Icon(
        valid ? Icons.check_circle : Icons.error_outline,
        size: 10,
        color: valid
            ? AppColors.successGreen
            : (msg.contains('Optional') || msg.contains('optional'))
                ? Colors.white38
                : AppColors.errorRed,
      ),
      const SizedBox(width: 4),
      Expanded(child: Text(
        msg,
        style: TextStyle(
          fontSize: 9,
          color: valid
              ? AppColors.successGreen
              : (msg.contains('Optional') || msg.contains('optional'))
                  ? Colors.white38
                  : AppColors.errorRed,
        ),
      )),
    ]),
  ]);

  Widget _plainField(
    TextEditingController ctrl,
    String hint,
    ValueChanged<String> onChanged,
  ) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
    decoration: InputDecoration(
      isDense: true, filled: true, fillColor: Colors.black38,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      suffixIcon: IconButton(
        icon: const Icon(Icons.content_paste, size: 14, color: Colors.white38),
        onPressed: () async {
          final c = await Clipboard.getData('text/plain');
          if (c?.text != null) { ctrl.text = c!.text!; onChanged(c.text!); }
        },
      ),
    ),
    onChanged: onChanged,
  );

  Widget _textInput(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 12),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
      filled: true, fillColor: Colors.black26, isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    ),
  );

  Widget _infoChip(Color color, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 10))),
    ]),
  );

  Widget _modelDropdown() {
    final list = ApiKeys.geminiModels;
    if (!list.any((m) => m['id'] == _model)) _model = list.first['id']!;
    return DropdownButtonFormField<String>(
      value: _model,
      dropdownColor: AppColors.deepSpaceBlue,
      isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _dropDeco(),
      items: list.map((m) => DropdownMenuItem(
        value: m['id'],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m['name']!, style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis),
            Text(m['desc']!, style: const TextStyle(fontSize: 9, color: Colors.white54)),
          ],
        ),
      )).toList(),
      onChanged: (v) { if (v != null) setState(() => _model = v); },
    );
  }

  Widget _permRow(
    IconData icon,
    String   title,
    String   sub,
    bool     on, {
    required VoidCallback onTap,
    bool special = false,
    bool last    = false,
  }) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (on ? AppColors.successGreen : AppColors.errorRed).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16,
              color: on ? AppColors.successGreen : AppColors.errorRed),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
        if (on)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ON', style: TextStyle(
                color: AppColors.successGreen,
                fontSize: 9, fontWeight: FontWeight.bold)),
          )
        else
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFF00FF)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                special ? 'Enable' : 'Grant',
                style: const TextStyle(color: Color(0xFFFF00FF),
                    fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ]),
    ),
    if (!last) Divider(height: 1, color: AppColors.cyanPrimary.withOpacity(0.1)),
  ]);

  Future<void> _grant(Permission p) async {
    final s = await p.request();
    if (s.isPermanentlyDenied) openAppSettings();
    await _loadPerms();
  }

  Widget _saveBar() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 52,
        child: ElevatedButton(
          onPressed: (!_saving && (_valid['gem'] ?? false)) ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: (_valid['gem'] ?? false)
                ? AppColors.cyanPrimary : Colors.grey.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text('SAVE & APPLY', style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
        ),
      ),
    ),
  );

  Widget _sectionHeader(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(
        color: AppColors.cyanPrimary, fontSize: 11,
        letterSpacing: 2, fontWeight: FontWeight.bold)),
  );

  Widget _box(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.18)),
    ),
    child: child,
  );

  Color _affColor(int l) {
    if (l >= 90) return Colors.pinkAccent;
    if (l >= 70) return AppColors.cyanPrimary;
    return AppColors.warningOrange;
  }

  InputDecoration _dropDeco() => InputDecoration(
    filled: true, fillColor: Colors.black26,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

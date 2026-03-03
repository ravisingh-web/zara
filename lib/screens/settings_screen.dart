// lib/screens/settings_screen.dart
// Z.A.R.A. v7.0 — Settings
// 5 APIs: Gemini + Mem0 + LiveKit + OpenAI + ElevenLabs

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/services/accessibility_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  bool _loading = false;
  bool _saving  = false;
  bool _accessOn = false;
  Map<Permission, PermissionStatus> _perms = {};

  // Controllers
  final _gemCtrl    = TextEditingController();
  final _mem0Ctrl   = TextEditingController();
  final _lkUrlCtrl  = TextEditingController();
  final _lkTokCtrl  = TextEditingController();
  final _oaiCtrl    = TextEditingController();
  final _elCtrl     = TextEditingController();
  final _ownerCtrl  = TextEditingController();
  final _userIdCtrl = TextEditingController();

  // Visibility
  bool _hideGem = true, _hideMem0 = true, _hideLkTok = true,
       _hideOai = true, _hideEl   = true;

  String _model = 'gemini-2.5-flash';
  String _lang  = 'hi-IN';
  int    _aff   = 85;

  // Validation state
  Map<String, String> _msgs   = {};
  Map<String, bool>   _valid  = {};

  static const _langs = ['hi-IN','en-US','en-GB','mr-IN','gu-IN','ta-IN','ur-PK'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_gemCtrl, _mem0Ctrl, _lkUrlCtrl, _lkTokCtrl,
        _oaiCtrl, _elCtrl, _ownerCtrl, _userIdCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _gemCtrl.text    = ApiKeys.geminiKey;
    _mem0Ctrl.text   = ApiKeys.mem0Key;
    _lkUrlCtrl.text  = ApiKeys.livekitUrl;
    _lkTokCtrl.text  = ApiKeys.livekitToken;
    _oaiCtrl.text    = ApiKeys.openaiKey;
    _elCtrl.text     = ApiKeys.elevenKey;
    _ownerCtrl.text  = ApiKeys.ownerName;
    _userIdCtrl.text = ApiKeys.mem0UserId;
    _aff             = ApiKeys.affection;

    final ids = ApiKeys.geminiModels.map((m) => m['id']!).toList();
    _model = ids.contains(ApiKeys.geminiModel) ? ApiKeys.geminiModel : ids.first;
    _lang  = _langs.contains(ApiKeys.lang) ? ApiKeys.lang : 'hi-IN';

    _validate('gem',   _gemCtrl.text);
    _validate('mem0',  _mem0Ctrl.text);
    _validate('lkUrl', _lkUrlCtrl.text);
    _validate('lkTok', _lkTokCtrl.text);
    _validate('oai',   _oaiCtrl.text);
    _validate('el',    _elCtrl.text);

    await _loadPerms();
    try { _accessOn = await AccessibilityService().checkEnabled(); } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadPerms() async {
    final m = <Permission, PermissionStatus>{};
    for (final p in [Permission.microphone, Permission.camera, Permission.location,
      Permission.notification, Permission.manageExternalStorage]) {
      m[p] = await p.status;
    }
    if (mounted) setState(() => _perms = m);
  }

  void _validate(String key, String val) {
    String msg = ''; bool ok = false;
    switch (key) {
      case 'gem':
        if (val.isEmpty)                                              { msg = 'Required — Brain nahi chalega'; ok = false; }
        else if (RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(val)) { msg = '✓ Valid'; ok = true; }
        else                                                          { msg = 'AIza... se shuru hona chahiye'; ok = false; }
        break;
      case 'mem0':
        if (val.isEmpty)  { msg = 'Optional — yaadein nahi rahegi'; ok = false; }
        else              { msg = val.length >= 10 ? '✓ Valid' : 'Too short'; ok = val.length >= 10; }
        break;
      case 'lkUrl':
        if (val.isEmpty)  { msg = 'Optional — real-time voice ke liye'; ok = false; }
        else              { msg = val.startsWith('wss://') || val.startsWith('ws://') ? '✓ Valid' : 'wss:// se shuru karo'; ok = val.startsWith('wss://') || val.startsWith('ws://'); }
        break;
      case 'lkTok':
        if (val.isEmpty)  { msg = 'LiveKit token — room join ke liye'; ok = false; }
        else              { msg = val.length >= 20 ? '✓ Valid' : 'Too short'; ok = val.length >= 20; }
        break;
      case 'oai':
        if (val.isEmpty)  { msg = 'Optional — Whisper STT ke liye'; ok = false; }
        else              { msg = val.startsWith('sk-') ? '✓ Valid' : 'sk- se shuru hona chahiye'; ok = val.startsWith('sk-'); }
        break;
      case 'el':
        if (val.isEmpty)  { msg = 'Required — Voice nahi aayegi'; ok = false; }
        else              { msg = val.length >= 20 ? '✓ Valid' : 'Too short'; ok = val.length >= 20; }
        break;
    }
    _msgs[key] = msg; _valid[key] = ok;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!(_valid['gem'] ?? false)) { _toast('Gemini key required hai', AppColors.errorRed); return; }
    if (!(_valid['el'] ?? false))  { _toast('ElevenLabs key bhi zaroori hai!', AppColors.warningOrange); }

    setState(() => _saving = true);
    try {
      final ok = await ApiKeys.save(
        geminiKey:    _gemCtrl.text,
        mem0Key:      _mem0Ctrl.text,
        livekitUrl:   _lkUrlCtrl.text,
        livekitToken: _lkTokCtrl.text,
        openaiKey:    _oaiCtrl.text,
        elevenKey:    _elCtrl.text,
        geminiModel:  _model,
        lang:         _lang,
        ownerName:    _ownerCtrl.text,
        mem0UserId:   _userIdCtrl.text,
        affection:    _aff,
      );
      if (!mounted) return;
      if (ok) {
        _toast('Saved! Zara ready hai.', AppColors.successGreen);
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
    SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));

  Future<void> _url(String u) async {
    final uri = Uri.parse(u);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

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

  // ── APIs Tab ───────────────────────────────────────────────────────────────
  Widget _apisTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _banner(),
    const SizedBox(height: 16),

    // 1. Gemini
    _apiCard(
      color:    const Color(0xFF4FC3F7),
      icon:     Icons.psychology_rounded,
      title:    '1 · GEMINI',
      subtitle: 'Brain — chat, reasoning, vision',
      link:     'Get Key →',
      linkUrl:  'https://aistudio.google.com/apikey',
      child: _keyField(_gemCtrl, 'AIzaSy...', _hideGem,
          () => setState(() => _hideGem = !_hideGem),
          (v) => _validate('gem', v), _valid['gem'] ?? false, _msgs['gem'] ?? ''),
    ),
    const SizedBox(height: 12),

    // 2. Mem0
    _apiCard(
      color:    const Color(0xFFFF9800),
      icon:     Icons.memory_rounded,
      title:    '2 · MEM0',
      subtitle: 'Long-term memory — Ravi ji ko yaad rakhna',
      link:     'Get Key →',
      linkUrl:  'https://app.mem0.ai/dashboard/api-keys',
      child: _keyField(_mem0Ctrl, 'mem0 API key...', _hideMem0,
          () => setState(() => _hideMem0 = !_hideMem0),
          (v) => _validate('mem0', v), _valid['mem0'] ?? false, _msgs['mem0'] ?? ''),
    ),
    const SizedBox(height: 12),

    // 3. LiveKit
    _apiCard(
      color:    const Color(0xFF9C27B0),
      icon:     Icons.graphic_eq_rounded,
      title:    '3 · LIVEKIT',
      subtitle: 'Real-time voice room — low-latency voice',
      link:     'Dashboard →',
      linkUrl:  'https://cloud.livekit.io',
      child: Column(children: [
        _keyField(_lkUrlCtrl, 'wss://your-project.livekit.cloud', false,
            () {}, (v) => _validate('lkUrl', v),
            _valid['lkUrl'] ?? false, _msgs['lkUrl'] ?? '', obscureToggle: false),
        const SizedBox(height: 8),
        _keyField(_lkTokCtrl, 'LiveKit room token...', _hideLkTok,
            () => setState(() => _hideLkTok = !_hideLkTok),
            (v) => _validate('lkTok', v), _valid['lkTok'] ?? false, _msgs['lkTok'] ?? ''),
      ]),
    ),
    const SizedBox(height: 12),

    // 4. OpenAI
    _apiCard(
      color:    const Color(0xFF4CAF50),
      icon:     Icons.mic_rounded,
      title:    '4 · OPENAI (Whisper STT)',
      subtitle: 'Voice → Text — speech recognition',
      link:     'Get Key →',
      linkUrl:  'https://platform.openai.com/api-keys',
      child: _keyField(_oaiCtrl, 'sk-...', _hideOai,
          () => setState(() => _hideOai = !_hideOai),
          (v) => _validate('oai', v), _valid['oai'] ?? false, _msgs['oai'] ?? ''),
    ),
    const SizedBox(height: 12),

    // 5. ElevenLabs
    _apiCard(
      color:    const Color(0xFF7B2FFF),
      icon:     Icons.record_voice_over_rounded,
      title:    '5 · ELEVENLABS',
      subtitle: 'Voice output — Simran (eleven_v3)',
      link:     'Get Key →',
      linkUrl:  'https://elevenlabs.io/app/subscription',
      child: Column(children: [
        _keyField(_elCtrl, 'ElevenLabs API key...', _hideEl,
            () => setState(() => _hideEl = !_hideEl),
            (v) => _validate('el', v), _valid['el'] ?? false, _msgs['el'] ?? ''),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7B2FFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.lock_rounded, size: 11, color: Color(0xFF7B2FFF)),
            SizedBox(width: 6),
            Text('Voice ID: Simran · Model: eleven_v3',
                style: TextStyle(color: Colors.white54, fontSize: 10)),
          ]),
        ),
      ]),
    ),
    const SizedBox(height: 20),
  ]);

  // ── System Tab ─────────────────────────────────────────────────────────────
  Widget _systemTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _h('🤖  BRAIN MODEL'),
    _box(_modelDropdown()), const SizedBox(height: 14),

    _h('🌐  LANGUAGE'),
    _box(DropdownButtonFormField<String>(
      value: _lang, dropdownColor: AppColors.deepSpaceBlue,
      isExpanded: true, isDense: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _dropDeco(),
      items: _langs.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
      onChanged: (v) { if (v != null) setState(() => _lang = v); },
    )), const SizedBox(height: 14),

    _h('👤  PERSONALIZATION'),
    _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ownerCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: 'Your Name (Ravi ji ka naam)',
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true, fillColor: Colors.black26, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _userIdCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: 'Mem0 User ID (default: zara_ravi)',
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true, fillColor: Colors.black26, isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
      ),
      const SizedBox(height: 14),
      Row(children: [
        const Text('Affection Level', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text('$_aff%', style: TextStyle(color: _affColor(_aff),
            fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      Slider(
        value: _aff.toDouble(), min: 0, max: 100, divisions: 10,
        activeColor: _affColor(_aff), inactiveColor: Colors.white12,
        onChanged: (v) => setState(() => _aff = v.toInt()),
      ),
    ])),
    const SizedBox(height: 20),
  ]);

  // ── Permissions Tab ────────────────────────────────────────────────────────
  Widget _permsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _box(Column(children: [
      _permRow(Icons.accessibility_new, 'Accessibility Service', 'God Mode device control',
          _accessOn, special: true, onTap: () async {
            try { await AccessibilityService().openSettings(); } catch (_) {}
            await Future.delayed(const Duration(seconds: 2));
            try { final e = await AccessibilityService().checkEnabled();
              if (mounted) setState(() => _accessOn = e); } catch (_) {}
          }),
      _permRow(Icons.mic, 'Microphone', 'Voice commands + Whisper STT',
          _perms[Permission.microphone]?.isGranted ?? false,
          onTap: () => _grant(Permission.microphone)),
      _permRow(Icons.folder_open, 'All Files Access', 'God Mode — file control',
          _perms[Permission.manageExternalStorage]?.isGranted ?? false,
          onTap: () => _grant(Permission.manageExternalStorage)),
      _permRow(Icons.camera_alt, 'Camera', 'Vision + Intruder detection',
          _perms[Permission.camera]?.isGranted ?? false,
          onTap: () => _grant(Permission.camera)),
      _permRow(Icons.location_on, 'Location', 'GPS tracking',
          _perms[Permission.location]?.isGranted ?? false,
          onTap: () => _grant(Permission.location)),
      _permRow(Icons.notifications, 'Notifications', 'Alerts',
          _perms[Permission.notification]?.isGranted ?? false,
          onTap: () => _grant(Permission.notification), last: true),
    ])),
    const SizedBox(height: 20),
  ]);

  // ── Banner ─────────────────────────────────────────────────────────────────
  Widget _banner() {
    final g = ApiKeys.geminiKey.isNotEmpty;
    final e = ApiKeys.elevenKey.isNotEmpty;
    final m = ApiKeys.mem0Key.isNotEmpty;
    final o = ApiKeys.openaiKey.isNotEmpty;
    final l = ApiKeys.livekitUrl.isNotEmpty;

    final count = [g, e, m, o, l].where((x) => x).length;
    final c = count == 5 ? AppColors.successGreen
        : count >= 2 ? AppColors.warningOrange : AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: c)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(count == 5 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: c, size: 18),
          const SizedBox(width: 8),
          Text('$count/5 APIs configured', style: TextStyle(
              color: c, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        _apiStatus('Gemini',    g),
        _apiStatus('Mem0',      m),
        _apiStatus('LiveKit',   l),
        _apiStatus('OpenAI',    o),
        _apiStatus('ElevenLabs', e),
      ]),
    );
  }

  Widget _apiStatus(String name, bool ok) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(children: [
      Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12, color: ok ? AppColors.successGreen : Colors.white30),
      const SizedBox(width: 6),
      Text(name, style: TextStyle(fontSize: 10,
          color: ok ? Colors.white70 : Colors.white30)),
    ]),
  );

  Widget _apiCard({
    required Color color, required IconData icon,
    required String title, required String subtitle,
    required String link, required String linkUrl,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold,
              fontSize: 12, letterSpacing: 1)),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ])),
        GestureDetector(onTap: () => _url(linkUrl),
          child: Text(link, style: TextStyle(color: color, fontSize: 10))),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Widget _keyField(TextEditingController ctrl, String hint, bool hide,
      VoidCallback toggle, ValueChanged<String> onChanged,
      bool valid, String msg, {bool obscureToggle = true}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl, obscureText: hide,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: Colors.black38,
          hintText: hint, hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            if (obscureToggle)
              IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility,
                  size: 14, color: Colors.white38), onPressed: toggle),
            IconButton(icon: const Icon(Icons.content_paste, size: 14, color: Colors.white38),
                onPressed: () async {
                  final c = await Clipboard.getData('text/plain');
                  if (c?.text != null) { ctrl.text = c!.text!; onChanged(c.text!); }
                }),
          ]),
        ),
        onChanged: onChanged,
      ),
      const SizedBox(height: 3),
      Row(children: [
        Icon(valid ? Icons.check_circle : Icons.error_outline, size: 10,
            color: valid ? AppColors.successGreen : (msg.contains('Optional') ? Colors.white38 : AppColors.errorRed)),
        const SizedBox(width: 4),
        Expanded(child: Text(msg, style: TextStyle(fontSize: 9,
            color: valid ? AppColors.successGreen : (msg.contains('Optional') ? Colors.white38 : AppColors.errorRed)))),
      ]),
    ]);

  Widget _modelDropdown() {
    final list = ApiKeys.geminiModels;
    if (!list.any((m) => m['id'] == _model)) _model = list.first['id']!;
    return DropdownButtonFormField<String>(
      value: _model, dropdownColor: AppColors.deepSpaceBlue, isExpanded: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _dropDeco(),
      items: list.map((m) => DropdownMenuItem(value: m['id'],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(m['name']!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          Text(m['desc']!, style: const TextStyle(fontSize: 9, color: Colors.white54)),
        ]),
      )).toList(),
      onChanged: (v) { if (v != null) setState(() => _model = v); },
    );
  }

  Widget _permRow(IconData icon, String title, String sub, bool on, {
    required VoidCallback onTap, bool special = false, bool last = false,
  }) => Column(children: [
    Padding(padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (on ? AppColors.successGreen : AppColors.errorRed).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: on ? AppColors.successGreen : AppColors.errorRed)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
        on
          ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.successGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('ON', style: TextStyle(color: AppColors.successGreen,
                  fontSize: 9, fontWeight: FontWeight.bold)))
          : GestureDetector(onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFF00FF)),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(special ? 'Enable' : 'Grant',
                    style: const TextStyle(color: Color(0xFFFF00FF),
                        fontSize: 10, fontWeight: FontWeight.bold)))),
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
            backgroundColor: (_valid['gem'] ?? false) ? AppColors.cyanPrimary : Colors.grey.shade800,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _saving
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : const Text('SAVE', style: TextStyle(color: Colors.black,
                  fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
        ),
      ),
    ),
  );

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(color: AppColors.cyanPrimary,
          fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)));

  Widget _box(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2))),
    child: child,
  );

  Color _affColor(int l) {
    if (l >= 90) return Colors.pinkAccent;
    if (l >= 70) return AppColors.cyanPrimary;
    return AppColors.warningOrange;
  }

  InputDecoration _dropDeco() => InputDecoration(
    filled: true, fillColor: Colors.black26,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8));
}

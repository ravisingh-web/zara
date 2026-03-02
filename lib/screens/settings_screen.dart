// lib/screens/settings_screen.dart
// Z.A.R.A. — System Config v3.0
// ✅ Gemini Only — OpenRouter removed
// ✅ ElevenLabs toggle + 5 voice IDs
// ✅ Gemini TTS voices (fallback)
// ✅ 4 Brain models
// ✅ All Files Access permission

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/services/accessibility_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  bool _loading    = false;
  bool _saving     = false;
  bool _obscureGem = true;
  bool _obscureEl  = true;
  bool _accessibilityEnabled = false;

  Map<Permission, PermissionStatus> _permissions = {};

  final _gemKeyCtrl   = TextEditingController();
  final _elKeyCtrl    = TextEditingController();
  final _ownerCtrl    = TextEditingController();

  String _selectedModel   = '';
  String _selectedVoice   = '';       // ElevenLabs voice ID
  String _selectedLang    = 'hi-IN';
  int    _affection       = 85;
  bool   _elEnabled       = true;

  bool   _isGemValid   = false;
  String _gemValidMsg  = '';
  bool   _isElValid    = false;
  String _elValidMsg   = '';

  static const _langOptions = ['hi-IN', 'en-US', 'en-GB', 'mr-IN', 'gu-IN', 'ta-IN'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _gemKeyCtrl.dispose();
    _elKeyCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    _gemKeyCtrl.text = ApiKeys.gemKey;
    _elKeyCtrl.text  = ApiKeys.elKey;
    _ownerCtrl.text  = ApiKeys.owner;
    _affection       = ApiKeys.aff;
    _elEnabled       = ApiKeys.elEnabled;

    // Model
    final validIds = ApiKeys.gemModels.map((m) => m['id']!).toList();
    _selectedModel = validIds.contains(ApiKeys.model)
        ? ApiKeys.model
        : validIds.first;

    // Voice
    final elIds = ApiKeys.elevenLabsVoices.map((v) => v['id']!).toList();
    _selectedVoice = elIds.contains(ApiKeys.voice)
        ? ApiKeys.voice
        : elIds.first;


    _selectedLang = _langOptions.contains(ApiKeys.lang)
        ? ApiKeys.lang
        : 'hi-IN';

    _validateGem(_gemKeyCtrl.text);
    _validateEl(_elKeyCtrl.text);

    await _checkPermissions();
    try { _accessibilityEnabled = await AccessibilityService().checkEnabled(); }
    catch (_) { _accessibilityEnabled = false; }

    if (mounted) setState(() => _loading = false);
  }

  // ── Permissions ────────────────────────────────────────────────────────────
  Future<void> _checkPermissions() async {
    final Map<Permission, PermissionStatus> statuses = {};
    for (final p in [
      Permission.camera, Permission.location, Permission.storage,
      Permission.microphone, Permission.notification,
      Permission.manageExternalStorage,
    ]) {
      statuses[p] = await p.status;
    }
    if (mounted) setState(() => _permissions = statuses);
  }

  Future<void> _requestPermission(Permission permission) async {
    if (permission == Permission.manageExternalStorage) {
      final s = await Permission.manageExternalStorage.status;
      if (!s.isGranted) {
        final r = await Permission.manageExternalStorage.request();
        if (!r.isGranted && mounted) _showDeniedDialog(permission);
      }
    } else {
      final s = await permission.request();
      if (s.isPermanentlyDenied && mounted) _showDeniedDialog(permission);
    }
    await _checkPermissions();
  }

  void _showDeniedDialog(Permission p) {
    final names = {
      Permission.camera:                'Camera',
      Permission.location:              'Location',
      Permission.storage:               'Storage',
      Permission.microphone:            'Microphone',
      Permission.notification:          'Notifications',
      Permission.manageExternalStorage: 'All Files Access',
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepSpaceBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.4)),
        ),
        title: Text('${names[p] ?? 'Permission'} Denied',
            style: const TextStyle(color: AppColors.cyanPrimary, fontSize: 14)),
        content: Text(
          'Settings -> Apps -> Z.A.R.A. -> Permissions -> Enable ${names[p]}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyanPrimary, foregroundColor: Colors.black),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Validation ─────────────────────────────────────────────────────────────
  void _validateGem(String k) {
    if (k.isEmpty) {
      _isGemValid  = false; _gemValidMsg = 'Gemini key required';
    } else if (RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k)) {
      _isGemValid  = true;  _gemValidMsg = 'Valid Gemini key';
    } else {
      _isGemValid  = false; _gemValidMsg = 'Should start with AIza...';
    }
    if (mounted) setState(() {});
  }

  void _validateEl(String k) {
    if (k.isEmpty) {
      _isElValid  = false; _elValidMsg = 'Optional — leave empty to use Gemini TTS';
    } else if (k.length >= 20) {
      _isElValid  = true;  _elValidMsg = 'Valid ElevenLabs key';
    } else {
      _isElValid  = false; _elValidMsg = 'Key seems too short';
    }
    if (mounted) setState(() {});
  }

  // ── Save ───────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_isGemValid) { _showSnack('Fix Gemini API key first', AppColors.errorRed); return; }
    setState(() => _saving = true);
    try {
      final voiceToSave = _selectedVoice; // ElevenLabs only

      final ok = await ApiKeys.save(
        gemKey:    _gemKeyCtrl.text,
        elKey:     _elKeyCtrl.text,
        elEnabled: _elEnabled,
        model:     _selectedModel,
        voice:     voiceToSave,
        lang:      _selectedLang,
        owner:     _ownerCtrl.text,
        aff:       _affection,
      );
      if (mounted) {
        if (ok) {
          _showSnack('Z.A.R.A. System Saved', AppColors.successGreen);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context);
        } else {
          _showSnack('Save Failed — Check key format', AppColors.errorRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await AccessibilityService().openSettings();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        final e = await AccessibilityService().checkEnabled();
        setState(() => _accessibilityEnabled = e);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Accessibility settings: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpaceBlack,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyanPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('🔑 GEMINI API KEY'),
                  _buildGeminiKeyCard(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('🤖 BRAIN MODEL'),
                  _buildModelDropdown(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('🗣️ VOICE ENGINE'),
                  _buildVoiceSection(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('🌐 LANGUAGE'),
                  _buildLanguageCard(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('🔐 PERMISSIONS'),
                  _buildPermissionsCard(),
                  const SizedBox(height: 20),

                  _buildSectionHeader('👤 PERSONALIZATION'),
                  _buildPersonalizationCard(),
                  const SizedBox(height: 32),

                  _buildSaveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    title: const Text('Z.A.R.A. SYSTEM CONFIG',
        style: TextStyle(fontFamily: 'monospace', fontSize: 13,
            letterSpacing: 2, color: AppColors.cyanPrimary)),
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppColors.cyanPrimary,
    actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 20),
        onPressed: _loadData, tooltip: 'Refresh')],
  );

  Widget _buildStatusBanner() {
    final ok    = ApiKeys.ready;
    final color = ok ? AppColors.successGreen : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withOpacity(0.15), Colors.transparent],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? 'Z.A.R.A. System Ready' : 'Configuration Required',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(ok ? 'Brain: ${ApiKeys.model}  •  Voice: ElevenLabs (Simran)'
              : 'Gemini API key daalo activate karne ke liye',
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ])),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(title, style: const TextStyle(
          color: AppColors.cyanPrimary, fontSize: 11,
          letterSpacing: 2, fontWeight: FontWeight.bold))),
      Container(height: 1, width: 40,
          color: AppColors.cyanPrimary.withOpacity(0.3)),
    ]),
  );

  // ── Gemini Key Card ────────────────────────────────────────────────────────
  Widget _buildGeminiKeyCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Google AI Studio Key',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
          TextButton.icon(
            onPressed: () => _launchUrl('https://aistudio.google.com/apikey'),
            icon: const Icon(Icons.open_in_new, size: 10, color: Color(0xFFFF00FF)),
            label: const Text('Get Key',
                style: TextStyle(color: Color(0xFFFF00FF), fontSize: 10)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
          ),
        ]),
        const SizedBox(height: 6),
        _buildKeyField(
          ctrl:     _gemKeyCtrl,
          hint:     'AIzaSy...',
          obscure:  _obscureGem,
          onToggle: () => setState(() => _obscureGem = !_obscureGem),
          onChanged:_validateGem,
          isValid:  _isGemValid,
          validMsg: _gemValidMsg,
        ),
      ]),
    );
  }

  Widget _buildKeyField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required ValueChanged<String> onChanged,
    required bool isValid,
    required String validMsg,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                size: 14, color: Colors.white38),
            onPressed: onToggle,
          ),
          IconButton(
            icon: const Icon(Icons.content_paste, size: 14, color: Colors.white38),
            onPressed: () async {
              final clip = await Clipboard.getData('text/plain');
              if (clip?.text != null) { ctrl.text = clip!.text!; onChanged(clip.text!); }
            },
          ),
        ]),
      ),
      onChanged: onChanged,
    ),
    const SizedBox(height: 4),
    Row(children: [
      Icon(isValid ? Icons.check_circle : Icons.error_outline,
          size: 11, color: isValid ? AppColors.successGreen : AppColors.errorRed),
      const SizedBox(width: 4),
      Expanded(child: Text(validMsg, style: TextStyle(
          color: isValid ? AppColors.successGreen : AppColors.errorRed, fontSize: 9))),
    ]),
  ]);

  // ── Model Dropdown ─────────────────────────────────────────────────────────
  Widget _buildModelDropdown() {
    final list = ApiKeys.gemModels;
    if (!list.any((m) => m['id'] == _selectedModel)) {
      _selectedModel = list.first['id']!;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Brain Model (4 models)',
            style: TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedModel,
          dropdownColor: AppColors.deepSpaceBlue,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 11),
          decoration: _dropdownDeco(),
          items: list.map((m) => DropdownMenuItem(
            value: m['id'],
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(m['name']!, style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
              Text(m['desc']!, style: const TextStyle(fontSize: 9, color: Colors.white54)),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedModel = v); },
        ),
      ]),
    );
  }

  // ── Voice Section ──────────────────────────────────────────────────────────
  Widget _buildVoiceSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ElevenLabs toggle
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _elEnabled
                  ? const Color(0xFF7B2FFF).withOpacity(0.2)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.surround_sound_rounded,
                size: 16,
                color: _elEnabled ? const Color(0xFF7B2FFF) : Colors.white38),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ElevenLabs Voice',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            Text(
              _elEnabled
                  ? 'ON — Human-like voice (recommended)'
                  : 'OFF — Using Gemini TTS fallback',
              style: TextStyle(
                  color: _elEnabled ? const Color(0xFF7B2FFF) : Colors.white38,
                  fontSize: 9),
            ),
          ])),
          Switch(
            value: _elEnabled,
            activeColor: const Color(0xFF7B2FFF),
            onChanged: (v) => setState(() => _elEnabled = v),
          ),
        ]),

        if (_elEnabled) ...[
          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          // ElevenLabs API Key
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('ElevenLabs API Key',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
            TextButton.icon(
              onPressed: () => _launchUrl('https://elevenlabs.io/app/subscription'),
              icon: const Icon(Icons.open_in_new, size: 10, color: Color(0xFF7B2FFF)),
              label: const Text('Get Key',
                  style: TextStyle(color: Color(0xFF7B2FFF), fontSize: 10)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
            ),
          ]),
          const SizedBox(height: 6),
          _buildKeyField(
            ctrl:     _elKeyCtrl,
            hint:     'ElevenLabs API key...',
            obscure:  _obscureEl,
            onToggle: () => setState(() => _obscureEl = !_obscureEl),
            onChanged:_validateEl,
            isValid:  _isElValid,
            validMsg: _elValidMsg,
          ),
          const SizedBox(height: 12),

          // ElevenLabs Voice Selection
          const Text('Select Voice',
              style: TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: ApiKeys.elevenLabsVoices.any((v) => v['id'] == _selectedVoice)
                ? _selectedVoice
                : ApiKeys.elevenLabsVoices.first['id'],
            dropdownColor: AppColors.deepSpaceBlue,
            isExpanded: true,
            isDense: true,
            style: const TextStyle(color: Colors.white, fontSize: 10),
            decoration: _dropdownDeco(),
            items: ApiKeys.elevenLabsVoices.map((v) => DropdownMenuItem(
              value: v['id'],
              child: Text(v['name']!, style: const TextStyle(fontSize: 10)),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedVoice = v); },
          ),
        ],

      ]),
    );
  }

  Widget _buildLanguageCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardDeco(),
    child: DropdownButtonFormField<String>(
      value: _selectedLang,
      dropdownColor: AppColors.deepSpaceBlue,
      isExpanded: true,
      isDense: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _dropdownDeco(),
      items: _langOptions.map((l) => DropdownMenuItem(
          value: l, child: Text(l, style: const TextStyle(fontSize: 11)))).toList(),
      onChanged: (l) { if (l != null) setState(() => _selectedLang = l); },
    ),
  );

  // ── Permissions Card ────────────────────────────────────────────────────────
  Widget _buildPermissionsCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardDeco(),
    child: Column(children: [
      _permTile(
        icon: Icons.accessibility_new, title: 'Accessibility Service',
        subtitle: 'God Mode — app control',
        granted: _accessibilityEnabled, isSpecial: true,
        onTap: _openAccessibilitySettings,
      ),
      _permTile(
        icon: Icons.mic, title: 'Microphone', subtitle: 'Voice commands (STT)',
        granted: _permissions[Permission.microphone]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.microphone),
      ),
      _permTile(
        icon: Icons.folder_open_rounded, title: 'All Files Access',
        subtitle: 'God Mode — read/write any file',
        granted: _permissions[Permission.manageExternalStorage]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.manageExternalStorage),
      ),
      _permTile(
        icon: Icons.folder, title: 'Storage', subtitle: 'File access',
        granted: _permissions[Permission.storage]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.storage),
      ),
      _permTile(
        icon: Icons.camera_alt, title: 'Camera', subtitle: 'Vision + Intruder photo',
        granted: _permissions[Permission.camera]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.camera),
      ),
      _permTile(
        icon: Icons.location_on, title: 'Location', subtitle: 'Location commands',
        granted: _permissions[Permission.location]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.location),
      ),
      _permTile(
        icon: Icons.notifications, title: 'Notifications', subtitle: 'Z.A.R.A. alerts',
        granted: _permissions[Permission.notification]?.isGranted ?? false,
        onTap: () => _requestPermission(Permission.notification),
        isLast: true,
      ),
    ]),
  );

  Widget _permTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
    bool isSpecial = false,
    bool isLast    = false,
  }) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: granted
                ? AppColors.successGreen.withOpacity(0.15)
                : AppColors.errorRed.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16,
              color: granted ? AppColors.successGreen : AppColors.errorRed),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
        const SizedBox(width: 8),
        if (!granted)
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF00FF), width: 1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(isSpecial ? 'Enable' : 'Grant',
                  style: const TextStyle(color: Color(0xFFFF00FF),
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('ON',
                style: TextStyle(color: AppColors.successGreen,
                    fontSize: 9, fontWeight: FontWeight.bold)),
          ),
      ]),
    ),
    if (!isLast) Divider(height: 1, color: AppColors.cyanPrimary.withOpacity(0.1)),
  ]);

  // ── Personalization ─────────────────────────────────────────────────────────
  Widget _buildPersonalizationCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: _cardDeco(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ownerCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: 'Your Name (Zara calls you this)',
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true,
          fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          isDense: true,
        ),
      ),
      const SizedBox(height: 16),
      Row(children: [
        const Text('Affection Level',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text('$_affection%',
            style: TextStyle(color: _affColor(_affection),
                fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      Slider(
        value: _affection.toDouble(), min: 0, max: 100, divisions: 10,
        activeColor: _affColor(_affection), inactiveColor: Colors.white12,
        onChanged: (v) => setState(() => _affection = v.toInt()),
      ),
      Center(child: Text(_affLabel(_affection),
          style: TextStyle(color: _affColor(_affection).withOpacity(0.7),
              fontSize: 10, letterSpacing: 1))),
    ]),
  );

  Color  _affColor(int l) {
    if (l >= 90) return Colors.pinkAccent;
    if (l >= 70) return AppColors.cyanPrimary;
    if (l >= 50) return Colors.white;
    return AppColors.warningOrange;
  }
  String _affLabel(int l) {
    if (l >= 90) return 'DEEPLY DEVOTED';
    if (l >= 70) return 'LOYAL COMPANION';
    if (l >= 50) return 'PROFESSIONAL';
    if (l >= 30) return 'FORMAL MODE';
    return 'MINIMAL ENGAGEMENT';
  }

  // ── Save Button ─────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    final canSave = !_saving && _isGemValid;
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: canSave ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSave ? AppColors.cyanPrimary : Colors.grey.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: canSave ? 8 : 0,
          shadowColor: AppColors.cyanPrimary.withOpacity(0.4),
        ),
        child: _saving
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : const Text('SAVE SYSTEM ARCHITECTURE',
                style: TextStyle(color: Colors.black,
                    fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
    color: Colors.white.withOpacity(0.04),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
    boxShadow: [BoxShadow(
        color: AppColors.cyanPrimary.withOpacity(0.03), blurRadius: 12, spreadRadius: 1)],
  );

  InputDecoration _dropdownDeco() => InputDecoration(
    filled: true,
    fillColor: Colors.black.withOpacity(0.3),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

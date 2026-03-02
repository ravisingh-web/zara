// lib/screens/settings_screen.dart
// Z.A.R.A. — System Config v5.0
// ✅ Sirf 2 keys: Gemini + ElevenLabs
// ✅ Voice selection REMOVED — Simran hardcoded
// ✅ Model dropdown
// ✅ Permissions

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

  final _gemKeyCtrl = TextEditingController();
  final _elKeyCtrl  = TextEditingController();
  final _ownerCtrl  = TextEditingController();

  String _selectedModel = '';
  String _selectedLang  = 'hi-IN';
  int    _affection     = 85;

  bool   _isGemValid  = false;
  String _gemValidMsg = '';
  bool   _isElValid   = false;
  String _elValidMsg  = '';

  static const _langOptions = ['hi-IN', 'en-US', 'en-GB', 'mr-IN', 'gu-IN', 'ta-IN'];

  @override
  void initState() { super.initState(); _loadData(); }

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

    final validIds = ApiKeys.gemModels.map((m) => m['id']!).toList();
    _selectedModel = validIds.contains(ApiKeys.model) ? ApiKeys.model : validIds.first;
    _selectedLang  = _langOptions.contains(ApiKeys.lang) ? ApiKeys.lang : 'hi-IN';

    _validateGem(_gemKeyCtrl.text);
    _validateEl(_elKeyCtrl.text);
    await _checkPermissions();
    try { _accessibilityEnabled = await AccessibilityService().checkEnabled(); }
    catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkPermissions() async {
    final s = <Permission, PermissionStatus>{};
    for (final p in [Permission.camera, Permission.location, Permission.storage,
      Permission.microphone, Permission.notification, Permission.manageExternalStorage]) {
      s[p] = await p.status;
    }
    if (mounted) setState(() => _permissions = s);
  }

  Future<void> _requestPermission(Permission p) async {
    final s = await p.request();
    if (s.isPermanentlyDenied && mounted) openAppSettings();
    await _checkPermissions();
  }

  void _validateGem(String k) {
    if (k.isEmpty) {
      _isGemValid = false; _gemValidMsg = 'Gemini key required';
    } else if (RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(k)) {
      _isGemValid = true; _gemValidMsg = 'Valid ✓';
    } else {
      _isGemValid = false; _gemValidMsg = 'AIza se shuru hona chahiye';
    }
    if (mounted) setState(() {});
  }

  void _validateEl(String k) {
    if (k.isEmpty) {
      _isElValid = false; _elValidMsg = 'Zaroori hai — voice ke liye';
    } else if (k.length >= 20) {
      _isElValid = true; _elValidMsg = 'Valid ✓';
    } else {
      _isElValid = false; _elValidMsg = 'Key too short';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_isGemValid) { _snack('Gemini key fix karo', AppColors.errorRed); return; }
    setState(() => _saving = true);
    try {
      final ok = await ApiKeys.save(
        gemKey: _gemKeyCtrl.text,
        elKey:  _elKeyCtrl.text,
        model:  _selectedModel,
        lang:   _selectedLang,
        owner:  _ownerCtrl.text,
        aff:    _affection,
      );
      if (mounted) {
        if (ok) {
          _snack('Saved! Zara ready.', AppColors.successGreen);
          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) Navigator.pop(context);
        } else {
          _snack('Save failed — key check karo', AppColors.errorRed);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: c,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<void> _url(String url) async {
    final u = Uri.parse(url);
    if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.deepSpaceBlack,
    appBar: AppBar(
      title: const Text('Z.A.R.A. SETTINGS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 13, letterSpacing: 2, color: AppColors.cyanPrimary)),
      backgroundColor: Colors.transparent, elevation: 0,
      foregroundColor: AppColors.cyanPrimary,
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loadData)],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.cyanPrimary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _banner(),
              const SizedBox(height: 20),
              _h('🔑  GEMINI API KEY'),       _gemCard(),   const SizedBox(height: 14),
              _h('🗣️  ELEVENLABS VOICE KEY'), _elCard(),    const SizedBox(height: 14),
              _h('🤖  BRAIN MODEL'),           _modelCard(), const SizedBox(height: 14),
              _h('🌐  LANGUAGE'),              _langCard(),  const SizedBox(height: 14),
              _h('🔐  PERMISSIONS'),           _permsCard(), const SizedBox(height: 14),
              _h('👤  PERSONALIZATION'),       _personCard(),const SizedBox(height: 28),
              _saveBtn(), const SizedBox(height: 40),
            ]),
          ),
  );

  Widget _banner() {
    final gemOk = ApiKeys.gemKey.isNotEmpty;
    final elOk  = ApiKeys.elKey.isNotEmpty;
    final c = (gemOk && elOk) ? AppColors.successGreen
        : gemOk ? AppColors.warningOrange : AppColors.errorRed;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: c)),
      child: Row(children: [
        Icon(gemOk && elOk ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: c, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(gemOk && elOk ? 'Ready — Voice: Simran (ElevenLabs)'
              : gemOk ? 'ElevenLabs key daalo — voice ke liye'
              : 'Gemini key required',
              style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 2),
          Text('Model: ${ApiKeys.model}', style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ])),
      ]),
    );
  }

  Widget _h(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(color: AppColors.cyanPrimary,
        fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
  );

  Widget _gemCard() => Container(
    padding: const EdgeInsets.all(12), decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Google AI Studio', style: TextStyle(color: Colors.white60, fontSize: 10)),
        GestureDetector(onTap: () => _url('https://aistudio.google.com/apikey'),
          child: const Text('Get Key →', style: TextStyle(color: Color(0xFF4FC3F7), fontSize: 10))),
      ]),
      const SizedBox(height: 6),
      _keyField(_gemKeyCtrl, 'AIzaSy...', _obscureGem,
          () => setState(() => _obscureGem = !_obscureGem),
          _validateGem, _isGemValid, _gemValidMsg),
    ]),
  );

  Widget _elCard() => Container(
    padding: const EdgeInsets.all(12), decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('ElevenLabs API Key', style: TextStyle(color: Colors.white60, fontSize: 10)),
        GestureDetector(onTap: () => _url('https://elevenlabs.io/app/subscription'),
          child: const Text('Get Key →', style: TextStyle(color: Color(0xFF7B2FFF), fontSize: 10))),
      ]),
      const SizedBox(height: 6),
      _keyField(_elKeyCtrl, 'ElevenLabs key...', _obscureEl,
          () => setState(() => _obscureEl = !_obscureEl),
          _validateEl, _isElValid, _elValidMsg),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF7B2FFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.3)),
        ),
        child: const Row(children: [
          Icon(Icons.record_voice_over, size: 12, color: Color(0xFF7B2FFF)),
          SizedBox(width: 8),
          Text('Voice: Simran — fixed', style: TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      ),
    ]),
  );

  Widget _keyField(TextEditingController ctrl, String hint, bool obscure,
      VoidCallback toggle, ValueChanged<String> changed, bool valid, String msg) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl, obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
        decoration: InputDecoration(
          isDense: true, filled: true, fillColor: Colors.black.withOpacity(0.4),
          hintText: hint, hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                size: 14, color: Colors.white38), onPressed: toggle),
            IconButton(icon: const Icon(Icons.content_paste, size: 14, color: Colors.white38),
                onPressed: () async {
                  final c = await Clipboard.getData('text/plain');
                  if (c?.text != null) { ctrl.text = c!.text!; changed(c.text!); }
                }),
          ]),
        ),
        onChanged: changed,
      ),
      const SizedBox(height: 4),
      Row(children: [
        Icon(valid ? Icons.check_circle : Icons.error_outline, size: 11,
            color: valid ? AppColors.successGreen : AppColors.errorRed),
        const SizedBox(width: 4),
        Expanded(child: Text(msg, style: TextStyle(
            color: valid ? AppColors.successGreen : AppColors.errorRed, fontSize: 9))),
      ]),
    ]);

  Widget _modelCard() {
    final list = ApiKeys.gemModels;
    if (!list.any((m) => m['id'] == _selectedModel)) _selectedModel = list.first['id']!;
    return Container(
      padding: const EdgeInsets.all(12), decoration: _card(),
      child: DropdownButtonFormField<String>(
        value: _selectedModel,
        dropdownColor: AppColors.deepSpaceBlue, isExpanded: true,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: _drop(),
        items: list.map((m) => DropdownMenuItem(value: m['id'],
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(m['name']!, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
            Text(m['desc']!, style: const TextStyle(fontSize: 9, color: Colors.white54)),
          ]),
        )).toList(),
        onChanged: (v) { if (v != null) setState(() => _selectedModel = v); },
      ),
    );
  }

  Widget _langCard() => Container(
    padding: const EdgeInsets.all(12), decoration: _card(),
    child: DropdownButtonFormField<String>(
      value: _selectedLang, dropdownColor: AppColors.deepSpaceBlue,
      isExpanded: true, isDense: true,
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: _drop(),
      items: _langOptions.map((l) => DropdownMenuItem(
          value: l, child: Text(l))).toList(),
      onChanged: (l) { if (l != null) setState(() => _selectedLang = l); },
    ),
  );

  Widget _permsCard() => Container(
    padding: const EdgeInsets.all(12), decoration: _card(),
    child: Column(children: [
      _permRow(Icons.accessibility_new, 'Accessibility', 'God Mode',
          _accessibilityEnabled, isSpecial: true,
          onTap: () async {
            try { await AccessibilityService().openSettings(); }
            catch (_) {}
            await Future.delayed(const Duration(seconds: 2));
            try {
              final e = await AccessibilityService().checkEnabled();
              if (mounted) setState(() => _accessibilityEnabled = e);
            } catch (_) {}
          }),
      _permRow(Icons.mic, 'Microphone', 'Voice',
          _permissions[Permission.microphone]?.isGranted ?? false,
          onTap: () => _requestPermission(Permission.microphone)),
      _permRow(Icons.folder_open_rounded, 'All Files', 'God Mode',
          _permissions[Permission.manageExternalStorage]?.isGranted ?? false,
          onTap: () => _requestPermission(Permission.manageExternalStorage)),
      _permRow(Icons.camera_alt, 'Camera', 'Vision',
          _permissions[Permission.camera]?.isGranted ?? false,
          onTap: () => _requestPermission(Permission.camera)),
      _permRow(Icons.location_on, 'Location', 'GPS',
          _permissions[Permission.location]?.isGranted ?? false,
          onTap: () => _requestPermission(Permission.location)),
      _permRow(Icons.notifications, 'Notifications', 'Alerts',
          _permissions[Permission.notification]?.isGranted ?? false,
          onTap: () => _requestPermission(Permission.notification), isLast: true),
    ]),
  );

  Widget _permRow(IconData icon, String title, String sub, bool granted, {
    required VoidCallback onTap, bool isSpecial = false, bool isLast = false,
  }) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (granted ? AppColors.successGreen : AppColors.errorRed).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: granted ? AppColors.successGreen : AppColors.errorRed),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        ])),
        if (!granted)
          GestureDetector(onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFF00FF)),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(isSpecial ? 'Enable' : 'Grant',
                  style: const TextStyle(color: Color(0xFFFF00FF), fontSize: 10, fontWeight: FontWeight.bold)),
            ))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('ON', style: TextStyle(color: AppColors.successGreen,
                fontSize: 9, fontWeight: FontWeight.bold)),
          ),
      ]),
    ),
    if (!isLast) Divider(height: 1, color: AppColors.cyanPrimary.withOpacity(0.1)),
  ]);

  Widget _personCard() => Container(
    padding: const EdgeInsets.all(12), decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _ownerCtrl,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: 'Your Name', labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true, fillColor: Colors.black.withOpacity(0.3),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          isDense: true,
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        const Text('Affection', style: TextStyle(color: Colors.white70, fontSize: 11)),
        const Spacer(),
        Text('$_affection%', style: TextStyle(color: _afc(_affection),
            fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
      Slider(
        value: _affection.toDouble(), min: 0, max: 100, divisions: 10,
        activeColor: _afc(_affection), inactiveColor: Colors.white12,
        onChanged: (v) => setState(() => _affection = v.toInt()),
      ),
    ]),
  );

  Color _afc(int l) {
    if (l >= 90) return Colors.pinkAccent;
    if (l >= 70) return AppColors.cyanPrimary;
    if (l >= 50) return Colors.white;
    return AppColors.warningOrange;
  }

  Widget _saveBtn() => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      onPressed: (!_saving && _isGemValid) ? _save : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isGemValid ? AppColors.cyanPrimary : Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : const Text('SAVE', style: TextStyle(color: Colors.black,
              fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
    ),
  );

  BoxDecoration _card() => BoxDecoration(
    color: Colors.white.withOpacity(0.04),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
  );

  InputDecoration _drop() => InputDecoration(
    filled: true, fillColor: Colors.black.withOpacity(0.3),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

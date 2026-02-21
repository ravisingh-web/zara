// lib/screens/settings_screen.dart
// Z.A.R.A. — Complete Settings Screen
// ✅ Change API Keys Anytime • No Code Editing • Voice Selection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/api_keys.dart';
import '../services/ai_api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> _status = {};
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  
  final _geminiCtrl = TextEditingController();
  final _qwenCtrl = TextEditingController();
  final _llamaCtrl = TextEditingController();
  
  String _voice = ApiKeys.voiceName;
  String _lang = ApiKeys.languageCode;

  final _voices = [
    {'name': 'hi-IN-SwaraNeural', 'label': 'Swara (Female, Hindi)'},
    {'name': 'hi-IN-MadhurNeural', 'label': 'Madhur (Male, Hindi)'},
    {'name': 'en-US-JennyNeural', 'label': 'Jenny (Female, English)'},
    {'name': 'en-US-GuyNeural', 'label': 'Guy (Male, English)'},
    {'name': 'en-GB-SoniaNeural', 'label': 'Sonia (Female, British)'},
    {'name': 'en-US-AriaNeural', 'label': 'Aria (Female, US)'},
    {'name': 'en-US-DavisNeural', 'label': 'Davis (Male, US)'},
  ];

  final _langs = [
    {'code': 'hi-IN', 'label': 'Hindi'},
    {'code': 'en-US', 'label': 'English (US)'},
    {'code': 'en-GB', 'label': 'English (UK)'},
  ];

  @override
  void initState() {
    super.initState();
    _geminiCtrl.text = ApiKeys.gemini;
    _qwenCtrl.text = ApiKeys.qwen;
    _llamaCtrl.text = ApiKeys.llama;
    _voice = ApiKeys.voiceName;
    _lang = ApiKeys.languageCode;
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final s = await AiApiService().checkStatus();
    setState(() { _status = s; _loading = false; });
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _qwenCtrl.dispose();
    _llamaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontFamily: 'RobotoMono')),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.cyanPrimary),
            onPressed: _loadStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyanPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildSection('API Keys'),
                  _buildKeyField(_geminiCtrl, 'Gemini API', 'gemini', _status['gemini'] ?? false, 'https://aistudio.google.com/apikey', 'Voice, Search, Image/PDF Analysis'),
                  const SizedBox(height: 12),
                  _buildKeyField(_qwenCtrl, 'Qwen API', 'qwen', _status['qwen'] ?? false, 'https://dashscope.console.aliyun.com/apiKey', 'Code Generation'),
                  const SizedBox(height: 12),
                  _buildKeyField(_llamaCtrl, 'LLAMA API', 'llama', _status['llama'] ?? false, 'https://console.groq.com/keys', 'Emotional Conversations'),
                  const SizedBox(height: 20),
                  _buildSection('Voice & Language'),
                  _buildVoiceSelector(),
                  const SizedBox(height: 12),
                  _buildLangSelector(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 12),
                  _buildResetButton(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final all = _status['all'] ?? false;
    return Card(
      color: all ? AppColors.successGreen.withOpacity(0.1) : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: all ? AppColors.successGreen : AppColors.warningOrange, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(all ? Icons.check_circle : Icons.warning_amber, color: all ? AppColors.successGreen : AppColors.warningOrange, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(all ? 'All APIs Configured ✓' : 'API Keys Required', style: TextStyle(color: all ? AppColors.successGreen : AppColors.warningOrange, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono')),
                  const SizedBox(height: 4),
                  Text(all ? 'Z.A.R.A. ready!' : 'Add keys in Settings - No code editing!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontFamily: 'RobotoMono')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) => Text(title, style: const TextStyle(color: AppColors.cyanPrimary, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono'));

  Widget _buildKeyField(TextEditingController ctrl, String label, String type, bool valid, String url, String usage) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: valid ? AppColors.successGreen : AppColors.textDim, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono')), const Spacer(), Icon(valid ? Icons.check_circle : Icons.cancel, color: valid ? AppColors.successGreen : AppColors.errorRed, size: 20)]),
            const SizedBox(height: 8),
            Text(usage, style: TextStyle(color: AppColors.textDim, fontSize: 10, fontFamily: 'RobotoMono')),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: _obscure,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'RobotoMono', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Paste API key...',
                hintStyle: TextStyle(color: AppColors.textDim, fontFamily: 'RobotoMono', fontSize: 12),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3))),
                suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.content_paste, size: 18), onPressed: () async { final c = await Clipboard.getData('text/plain'); if (c?.text != null) ctrl.text = c!.text!; }, tooltip: 'Paste'),
                  IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 18), onPressed: () => setState(() => _obscure = !_obscure), tooltip: _obscure ? 'Show' : 'Hide'),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [TextButton(onPressed: () => debugPrint('Open: $url'), child: Text('Get Key →', style: TextStyle(color: AppColors.cyanPrimary, fontSize: 11, fontFamily: 'RobotoMono'))), const Spacer(), Text(valid ? 'Valid ✓' : 'Invalid', style: TextStyle(color: valid ? AppColors.successGreen : AppColors.errorRed, fontSize: 10, fontFamily: 'RobotoMono'))]),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSelector() {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voice Selection', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _voice,
              decoration: InputDecoration(filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3)))),
              items: _voices.map((v) => DropdownMenuItem(value: v['name'], child: Text(v['label']!, style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _voice = v); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangSelector() {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Language', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _lang,
              decoration: InputDecoration(filled: true, fillColor: AppColors.background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.3)))),
              items: _langs.map((l) => DropdownMenuItem(value: l['code'], child: Text(l['label']!, style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 12)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _lang = v); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _save,
        icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Icon(Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Configuration', style: const TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w600, fontSize: 14)),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyanPrimary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _saving ? null : _reset,
        icon: const Icon(Icons.delete_outline),
        label: const Text('Reset All Keys', style: TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w500, fontSize: 13)),
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.errorRed, side: const BorderSide(color: AppColors.errorRed), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: AppColors.infoBlue.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.infoBlue.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.info_outline, color: AppColors.infoBlue, size: 20), const SizedBox(width: 8), Text('Important', style: TextStyle(color: AppColors.infoBlue, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'RobotoMono'))]),
            const SizedBox(height: 12),
            _buildInfoItem('✅ Keys saved locally (SharedPreferences)'),
            _buildInfoItem('✅ Change anytime from this screen'),
            _buildInfoItem('✅ No code editing EVER needed!'),
            _buildInfoItem('✅ Keys persist after app restart'),
            _buildInfoItem('⚠️ Never share API keys'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'RobotoMono')));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiKeys.saveAll(gemini: _geminiCtrl.text, qwen: _qwenCtrl.text, llama: _llamaCtrl.text, voice: _voice, language: _lang);
      await _loadStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Settings saved!'), backgroundColor: AppColors.successGreen, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: AppColors.errorRed, behavior: SnackBarBehavior.floating));
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(backgroundColor: AppColors.surface, title: const Text('Reset Keys?', style: TextStyle(fontFamily: 'RobotoMono')), content: const Text('All API keys will be cleared.', style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12)), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel', style: TextStyle(fontFamily: 'RobotoMono'))), ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white), child: const Text('Reset', style: TextStyle(fontFamily: 'RobotoMono')))]));
    if (confirmed == true) {
      await ApiKeys.clearAll();
      _geminiCtrl.clear();
      _qwenCtrl.clear();
      _llamaCtrl.clear();
      await _loadStatus();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🗑️ Keys reset'), backgroundColor: AppColors.warningOrange, behavior: SnackBarBehavior.floating));
    }
  }
}

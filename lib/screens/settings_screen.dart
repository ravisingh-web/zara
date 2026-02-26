// lib/screens/settings_screen.dart
// Z.A.R.A. — System Configuration Panel
// ✅ Single API Key • OpenRouter/Gemini Toggle • Free Models • Holographic UI

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
  bool _loading = true;
  bool _saving = false;
  bool _accessibilityEnabled = false;
  Map<Permission, PermissionStatus> _permissions = {};

  final _apiKeyCtrl = TextEditingController();
  ApiProvider _selectedProvider = ApiProvider.none;
  String _selectedModel = ApiKeys.defaultModel;

  String _selectedVoice = 'hi-IN-SwaraNeural';
  String _selectedLanguage = 'hi-IN';

  final _ownerNameCtrl = TextEditingController();
  int _affectionLevel = 85;

  bool _isValidKey = false;
  String _validationMessage = '';

  final List<String> _voiceOptions = [
    'hi-IN-SwaraNeural', 'hi-IN-MadhurNeural',
    'en-US-JennyNeural', 'en-US-GuyNeural',
    'en-GB-SoniaNeural', 'mr-IN-AarohiNeural',
  ];

  final List<String> _languageOptions = [
    'hi-IN', 'en-US', 'en-GB', 'mr-IN', 'gu-IN', 'ta-IN', 'te-IN',
  ];
  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    _apiKeyCtrl.text = ApiKeys.apiKey;
    _selectedProvider = ApiKeys.provider;
    _selectedModel = ApiKeys.selectedModel;
    _selectedVoice = ApiKeys.voiceName;
    _selectedLanguage = ApiKeys.languageCode;
    _ownerNameCtrl.text = ApiKeys.ownerName;
    _affectionLevel = ApiKeys.affectionLevel;
    _validateKey(_apiKeyCtrl.text, _selectedProvider);
    await _checkPermissions();
    try {
      _accessibilityEnabled = await AccessibilityService().checkServiceEnabled();
    } catch (_) {
      _accessibilityEnabled = false;
    }
    setState(() => _loading = false);
  }

  Future<void> _checkPermissions() async {
    final List<Permission> permissionList = [
      Permission.camera,
      Permission.location,
      Permission.storage,
      Permission.notification,
    ];
    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissionList) {
      statuses[permission] = await permission.status;
    }
    setState(() => _permissions = statuses);
  }

  void _validateKey(String key, ApiProvider provider) {
    if (key.isEmpty) {
      _isValidKey = false;      _validationMessage = 'API key required';
      return;
    }
    if (provider == ApiProvider.gemini) {
      _isValidKey = RegExp(r'^AIza[0-9A-Za-z-_]{35,}$').hasMatch(key);
      _validationMessage = _isValidKey ? '✓ Valid Gemini key' : '✗ Invalid format (starts with AIza...)';
    } else if (provider == ApiProvider.openRouter) {
      _isValidKey = key.length >= 32 && RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(key);
      _validationMessage = _isValidKey ? '✓ Valid OpenRouter key' : '✗ Key must be 32+ alphanumeric chars';
    } else {
      _isValidKey = false;
      _validationMessage = 'Select a provider first';
    }
  }

  Future<void> _saveConfig() async {
    if (!_isValidKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ $_validationMessage'), backgroundColor: AppColors.errorRed),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiKeys.saveConfig(
        apiKey: _apiKeyCtrl.text,
        provider: _selectedProvider,
        model: _selectedModel,
        voice: _selectedVoice,
        language: _selectedLanguage,
        owner: _ownerNameCtrl.text,
        affection: _affectionLevel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Z.A.R.A. System Updated'), backgroundColor: AppColors.successGreen),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Save Failed: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }
  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    await _checkPermissions();
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await AccessibilityService().openSettings();
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          AccessibilityService().checkServiceEnabled().then((enabled) {
            setState(() => _accessibilityEnabled = enabled);
          });
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Open accessibility settings error: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpaceBlack,
      appBar: AppBar(
        title: const Text('Z.A.R.A. SYSTEM CONFIG', style: TextStyle(fontFamily: 'monospace', fontSize: 14, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.cyanPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.cyanPrimary))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,              children: [
                _buildStatusBanner(),
                const SizedBox(height: 20),
                _buildSectionHeader('🔑 API PROVIDER'),
                _buildProviderToggle(),
                const SizedBox(height: 12),
                _buildApiKeyInput(),
                const SizedBox(height: 16),
                if (_selectedProvider == ApiProvider.openRouter) ...[
                  _buildSectionHeader('🤖 SELECT MODEL (Free)'),
                  _buildModelDropdown(),
                  const SizedBox(height: 16),
                ],
                _buildSectionHeader('🗣️ VOICE & LANGUAGE'),
                _buildVoiceLanguageRow(),
                const SizedBox(height: 20),
                _buildSectionHeader('🔐 SYSTEM PERMISSIONS'),
                _buildPermissionCard(),
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

  Widget _buildStatusBanner() {
    final status = ApiKeys.status;
    final isConfigured = status['configured'] as bool? ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConfigured
            ? [AppColors.successGreen.withOpacity(0.2), Colors.transparent]
            : [AppColors.errorRed.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfigured ? AppColors.successGreen : AppColors.errorRed,
          width: 1,
        ),
      ),
      child: Row(        children: [
          Icon(isConfigured ? Icons.check_circle : Icons.warning_amber,
            color: isConfigured ? AppColors.successGreen : AppColors.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isConfigured ? '✓ System Ready' : '⚠️ Configuration Required',
                  style: TextStyle(color: isConfigured ? AppColors.successGreen : AppColors.errorRed, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(isConfigured
                  ? 'Provider: ${status['provider']} • Model: ${status['model']}'
                  : 'Set API key in Settings to activate Z.A.R.A.',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(
        color: AppColors.cyanPrimary, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildProviderToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          ToggleButtons(
            isSelected: [
              _selectedProvider == ApiProvider.openRouter,
              _selectedProvider == ApiProvider.gemini,
            ],
            onPressed: (index) {
              setState(() {
                _selectedProvider = index == 0 ? ApiProvider.openRouter : ApiProvider.gemini;
                if (_selectedProvider == ApiProvider.openRouter) {
                  _selectedModel = ApiKeys.defaultModel;
                }
                _validateKey(_apiKeyCtrl.text, _selectedProvider);
              });            },
            borderRadius: BorderRadius.circular(8),
            borderColor: AppColors.cyanPrimary.withOpacity(0.3),
            selectedBorderColor: AppColors.cyanPrimary,
            selectedColor: Colors.black,
            fillColor: AppColors.cyanPrimary,
            color: Colors.white70,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OpenRouter (Free)', style: TextStyle(fontSize: 11))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Gemini Direct', style: TextStyle(fontSize: 11))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedProvider == ApiProvider.openRouter
              ? '✓ Free models via OpenRouter.ai — No credit card needed'
              : '✓ Direct Google Gemini API — Requires billing setup',
            style: const TextStyle(color: Colors.white60, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('API Key', style: TextStyle(color: Colors.white70, fontSize: 11)),
              TextButton(
                onPressed: () {
                  if (_selectedProvider == ApiProvider.openRouter) {
                    _launchUrl('https://openrouter.ai/keys');
                  } else {
                    _launchUrl('https://aistudio.google.com/apikey');
                  }
                },
                child: Text('Get Key →', style: TextStyle(color: const Color(0xFFFF00FF), fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(            controller: _apiKeyCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              hintText: 'Paste your ${_selectedProvider == ApiProvider.openRouter ? 'OpenRouter' : 'Gemini'} API key...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste, size: 16),
                onPressed: () async {
                  final clip = await Clipboard.getData('text/plain');
                  if (clip?.text != null) {
                    setState(() {
                      _apiKeyCtrl.text = clip!.text!;
                      _validateKey(_apiKeyCtrl.text, _selectedProvider);
                    });
                  }
                },
              ),
            ),
            onChanged: (value) => _validateKey(value, _selectedProvider),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_isValidKey ? Icons.check_circle : Icons.error_outline,
                size: 14, color: _isValidKey ? AppColors.successGreen : AppColors.errorRed),
              const SizedBox(width: 4),
              Text(_validationMessage, style: TextStyle(color: _isValidKey ? AppColors.successGreen : AppColors.errorRed, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Free Models Available', style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedModel,            dropdownColor: AppColors.deepSpaceBlue,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: ApiKeys.openRouterFreeModels.map((model) {
              return DropdownMenuItem(
                value: model['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model['name']!, style: const TextStyle(fontSize: 11)),
                    Text(model['desc']!, style: const TextStyle(fontSize: 9, color: Colors.white60)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedModel = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceLanguageRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Voice', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedVoice,
                  dropdownColor: AppColors.deepSpaceBlue,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  isDense: true,
                  decoration: _dropdownDecoration(),
                  items: _voiceOptions.map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 10)))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _selectedVoice = v); },
                ),              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Language', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  dropdownColor: AppColors.deepSpaceBlue,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  isDense: true,
                  decoration: _dropdownDecoration(),
                  items: _languageOptions.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontSize: 10)))).toList(),
                  onChanged: (l) { if (l != null) setState(() => _selectedLanguage = l); },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildPermissionTile('Accessibility Service', _accessibilityEnabled, _openAccessibilitySettings, isSpecial: true),
          _buildPermissionTile('Camera', _permissions[Permission.camera]?.isGranted ?? false, () => _requestPermission(Permission.camera)),
          _buildPermissionTile('Location', _permissions[Permission.location]?.isGranted ?? false, () => _requestPermission(Permission.location)),
          _buildPermissionTile('Storage', _permissions[Permission.storage]?.isGranted ?? false, () => _requestPermission(Permission.storage)),
          _buildPermissionTile('Notifications', _permissions[Permission.notification]?.isGranted ?? false, () => _requestPermission(Permission.notification)),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(String title, bool isGranted, VoidCallback onRequest, {bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          if (isSpecial && !isGranted)
            TextButton(
              onPressed: onRequest,
              child: const Text('Enable →', style: TextStyle(color: const Color(0xFFFF00FF), fontSize: 10)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isGranted ? AppColors.successGreen.withOpacity(0.2) : AppColors.errorRed.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(isGranted ? 'Granted' : 'Denied',
                style: TextStyle(color: isGranted ? AppColors.successGreen : AppColors.errorRed, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _buildPersonalizationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          TextField(
            controller: _ownerNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Your Name (Sir)',
              labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Affection Level', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text('$_affectionLevel%', style: TextStyle(color: _getAffectionColor(_affectionLevel), fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _affectionLevel.toDouble(),
            min: 0, max: 100, divisions: 10,            activeColor: _getAffectionColor(_affectionLevel),
            onChanged: (v) => setState(() => _affectionLevel = v.toInt()),
          ),
        ],
      ),
    );
  }

  Color _getAffectionColor(int level) {
    if (level >= 90) return Colors.pink;
    if (level >= 70) return AppColors.cyanPrimary;
    if (level >= 50) return Colors.white;
    return AppColors.warningOrange;
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saving || !_isValidKey ? null : _saveConfig,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isValidKey ? AppColors.cyanPrimary : Colors.grey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _saving
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : const Text('SAVE SYSTEM ARCHITECTURE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

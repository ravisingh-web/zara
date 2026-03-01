// lib/screens/settings_screen.dart
// Z.A.R.A. — System Configuration Panel v2.0
// ✅ RED SCREEN CRASH FIXED • Permission Engine • STT/TTS Config • God-Mode Models

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

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _saving = false;
  bool _accessibilityEnabled = false;
  bool _obscureKey = true;
  Map<Permission, PermissionStatus> _permissions = {};

  late TabController _tabController;

  final _orKeyCtrl = TextEditingController();
  final _gemKeyCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();

  ApiProvider _selectedProvider = ApiProvider.openRouter;
  String _selectedModel = '';
  String _selectedVoice = 'hi-IN-SwaraNeural';
  String _selectedLanguage = 'hi-IN';
  int _affectionLevel = 85;

  bool _isOrKeyValid = false;
  bool _isGemKeyValid = false;
  String _orValidMsg = '';
  String _gemValidMsg = '';

  static const _voiceOptions = [
    'hi-IN-SwaraNeural',
    'hi-IN-MadhurNeural',
    'en-US-JennyNeural',
    'en-US-GuyNeural',
    'en-GB-SoniaNeural',
    'mr-IN-AarohiNeural',
  ];

  static const _langOptions = [
    'hi-IN',
    'en-US',
    'en-GB',
    'mr-IN',
    'gu-IN',
    'ta-IN',
    'te-IN',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedProvider = _tabController.index == 0
              ? ApiProvider.openRouter
              : ApiProvider.gemini;
          _safeSetModel();
        });
      }
    });
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _orKeyCtrl.dispose();
    _gemKeyCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);

    _orKeyCtrl.text = ApiKeys.orKey;
    _gemKeyCtrl.text = ApiKeys.gemKey;
    _selectedProvider = ApiKeys.provider == ApiProvider.none
        ? ApiProvider.openRouter
        : ApiKeys.provider;
    _ownerNameCtrl.text = ApiKeys.owner;
    _affectionLevel = ApiKeys.aff;
    _selectedVoice = _safePickVoice(ApiKeys.voice);
    _selectedLanguage = _safePickLang(ApiKeys.lang);

    _safeSetModel();

    _tabController.index =
        _selectedProvider == ApiProvider.gemini ? 1 : 0;

    _validateOrKey(_orKeyCtrl.text);
    _validateGemKey(_gemKeyCtrl.text);

    await _checkPermissions();
    try {
      _accessibilityEnabled = await AccessibilityService().checkEnabled();
    } catch (_) {
      _accessibilityEnabled = false;
    }

    if (mounted) setState(() => _loading = false);
  }

  void _safeSetModel() {
    final list = _selectedProvider == ApiProvider.openRouter
        ? ApiKeys.orModels
        : ApiKeys.gemModels;

    final savedModel = ApiKeys.model;
    final exists = list.any((m) => m['id'] == savedModel);
    if (exists) {
      _selectedModel = savedModel;
    } else {
      _selectedModel = list.isNotEmpty ? list.first['id']! : '';
    }
  }

  String _safePickVoice(String saved) =>
      _voiceOptions.contains(saved) ? saved : _voiceOptions.first;

  String _safePickLang(String saved) =>
      _langOptions.contains(saved) ? saved : _langOptions.first;

  Future<void> _checkPermissions() async {
    final perms = [
      Permission.camera,
      Permission.location,
      Permission.storage,
      Permission.microphone,
      Permission.notification,
      Permission.manageExternalStorage, // ✅ NEW
    ];
    final Map<Permission, PermissionStatus> statuses = {};
    for (final p in perms) {
      statuses[p] = await p.status;
    }
    if (mounted) setState(() => _permissions = statuses);
  }

  Future<void> _requestPermission(Permission permission) async {
    // ✅ MANAGE_EXTERNAL_STORAGE needs special handling on Android 11+
    if (permission == Permission.manageExternalStorage) {
      final status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted && mounted) {
          _showPermissionDeniedDialog(permission);
        }
      }
      await _checkPermissions();
      return;
    }

    final status = await permission.request();
    if (status.isPermanentlyDenied && mounted) {
      _showPermissionDeniedDialog(permission);
    }
    await _checkPermissions();
  }

  void _showPermissionDeniedDialog(Permission permission) {
    final names = {
      Permission.camera:                'Camera',
      Permission.location:              'Location',
      Permission.storage:               'Storage',
      Permission.microphone:            'Microphone',
      Permission.notification:          'Notifications',
      Permission.manageExternalStorage: 'All Files Access',
    };
    final name = names[permission] ?? 'Permission';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deepSpaceBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cyanPrimary.withOpacity(0.4)),
        ),
        title: Text(
          '⚠️ $name Permission Denied',
          style: const TextStyle(color: AppColors.cyanPrimary, fontSize: 14),
        ),
        content: Text(
          'Z.A.R.A. needs $name access to function at full power.\n\n'
          'Please go to:\nSettings → Apps → Z.A.R.A. → Permissions → Enable $name',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanPrimary,
              foregroundColor: Colors.black,
            ),
            child: const Text('Open Settings', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _validateOrKey(String key) {
    if (key.isEmpty) {
      _isOrKeyValid = false;
      _orValidMsg = 'OpenRouter key required';
    } else if (key.length >= 32 &&
        RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(key)) {
      _isOrKeyValid = true;
      _orValidMsg = '✓ Valid OpenRouter key';
    } else {
      _isOrKeyValid = false;
      _orValidMsg = '✗ Must be 32+ alphanumeric chars';
    }
    if (mounted) setState(() {});
  }

  void _validateGemKey(String key) {
    if (key.isEmpty) {
      _isGemKeyValid = false;
      _gemValidMsg = 'Gemini key required';
    } else if (RegExp(r'^AIza[0-9A-Za-z\-_]{35,}$').hasMatch(key)) {
      _isGemKeyValid = true;
      _gemValidMsg = '✓ Valid Gemini key';
    } else {
      _isGemKeyValid = false;
      _gemValidMsg = '✗ Should start with AIza...';
    }
    if (mounted) setState(() {});
  }

  bool get _currentKeyValid =>
      _selectedProvider == ApiProvider.openRouter ? _isOrKeyValid : _isGemKeyValid;

  Future<void> _saveConfig() async {
    if (!_currentKeyValid) {
      _showSnack('⚠️ Fix API key errors first', AppColors.errorRed);
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await ApiKeys.save(
        orKey:  _orKeyCtrl.text.isNotEmpty  ? _orKeyCtrl.text  : null,
        gemKey: _gemKeyCtrl.text.isNotEmpty ? _gemKeyCtrl.text : null,
        prov:   _selectedProvider,
        model:  _selectedModel,
        voice:  _selectedVoice,
        lang:   _selectedLanguage,
        owner:  _ownerNameCtrl.text,
        aff:    _affectionLevel,
      );

      if (mounted) {
        if (ok) {
          _showSnack('✅ Z.A.R.A. System Architecture Saved', AppColors.successGreen);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context);
        } else {
          _showSnack('❌ Save Failed — Check key format', AppColors.errorRed);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('❌ Error: $e', AppColors.errorRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await AccessibilityService().openSettings();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        final enabled = await AccessibilityService().checkEnabled();
        setState(() => _accessibilityEnabled = enabled);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Accessibility settings error: $e');
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
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cyanPrimary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusBanner(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('🔑 API PROVIDER & KEY'),
                  _buildApiProviderSection(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('🤖 NEURAL MODEL SELECTION'),
                  _buildModelDropdown(),
                  const SizedBox(height: 20),
                  _buildSectionHeader('🗣️ VOICE & LANGUAGE ENGINE'),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Z.A.R.A. SYSTEM CONFIG',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          letterSpacing: 2,
          color: AppColors.cyanPrimary,
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.cyanPrimary,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20),
          onPressed: _loadAllData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildStatusBanner() {
    final status = ApiKeys.status;
    final ok = status['configured'] as bool? ?? false;
    final color = ok ? AppColors.successGreen : AppColors.errorRed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? '✓ Z.A.R.A. System Ready' : '⚠️ Configuration Required',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? 'Provider: ${status['provider']}  •  Model: ${status['model']}'
                      : 'Set API key below to activate Z.A.R.A.',
                  style: const TextStyle(color: Colors.white60, fontSize: 10),
                ),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.cyanPrimary,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            height: 1,
            width: 40,
            color: AppColors.cyanPrimary.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildApiProviderSection() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white54,
              indicator: BoxDecoration(
                color: AppColors.cyanPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '⚡ OpenRouter (Free)'),
                Tab(text: '🔷 Gemini Direct'),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildKeyInput(
                  controller: _orKeyCtrl,
                  hint: 'sk-or-v1-... (OpenRouter key)',
                  isValid: _isOrKeyValid,
                  validMsg: _orValidMsg,
                  onChanged: _validateOrKey,
                  getKeyUrl: 'https://openrouter.ai/keys',
                  label: 'OpenRouter',
                ),
                _buildKeyInput(
                  controller: _gemKeyCtrl,
                  hint: 'AIzaSy... (Google Gemini key)',
                  isValid: _isGemKeyValid,
                  validMsg: _gemValidMsg,
                  onChanged: _validateGemKey,
                  getKeyUrl: 'https://aistudio.google.com/apikey',
                  label: 'Gemini',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInput({
    required TextEditingController controller,
    required String hint,
    required bool isValid,
    required String validMsg,
    required ValueChanged<String> onChanged,
    required String getKeyUrl,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$label API Key',
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
              TextButton.icon(
                onPressed: () => _launchUrl(getKeyUrl),
                icon: const Icon(Icons.open_in_new,
                    size: 10, color: Color(0xFFFF00FF)),
                label: const Text('Get Key',
                    style: TextStyle(color: Color(0xFFFF00FF), fontSize: 10)),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            obscureText: _obscureKey,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                        _obscureKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 14,
                        color: Colors.white38),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_paste,
                        size: 14, color: Colors.white38),
                    onPressed: () async {
                      final clip = await Clipboard.getData('text/plain');
                      if (clip?.text != null) {
                        controller.text = clip!.text!;
                        onChanged(clip.text!);
                      }
                    },
                  ),
                ],
              ),
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.error_outline,
                size: 12,
                color: isValid ? AppColors.successGreen : AppColors.errorRed,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  validMsg,
                  style: TextStyle(
                    color: isValid
                        ? AppColors.successGreen
                        : AppColors.errorRed,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelDropdown() {
    final modelList = _selectedProvider == ApiProvider.openRouter
        ? ApiKeys.orModels
        : ApiKeys.gemModels;

    final validIds = modelList.map((m) => m['id']!).toSet();
    if (!validIds.contains(_selectedModel) && modelList.isNotEmpty) {
      _selectedModel = modelList.first['id']!;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedProvider == ApiProvider.openRouter
                      ? '${ApiKeys.orModels.length} Free Models Available'
                      : '${ApiKeys.gemModels.length} Gemini Models',
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cyanPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedProvider == ApiProvider.openRouter
                      ? 'FREE'
                      : 'PAID',
                  style: const TextStyle(
                      color: AppColors.cyanPrimary,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedModel.isNotEmpty ? _selectedModel : null,
            dropdownColor: AppColors.deepSpaceBlue,
            isExpanded: true,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
            decoration: _dropdownDecoration(),
            items: modelList.map((model) {
              return DropdownMenuItem<String>(
                value: model['id'],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(model['name']!,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                    Text(model['desc']!,
                        style: const TextStyle(
                            fontSize: 9, color: Colors.white54)),
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
                const Text('🎙️ Voice',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedVoice,
                  dropdownColor: AppColors.deepSpaceBlue,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  decoration: _dropdownDecoration(),
                  items: _voiceOptions
                      .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v,
                              style: const TextStyle(fontSize: 10),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedVoice = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌐 Language',
                    style: TextStyle(color: Colors.white60, fontSize: 10)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  dropdownColor: AppColors.deepSpaceBlue,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  decoration: _dropdownDecoration(),
                  items: _langOptions
                      .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(l,
                              style: const TextStyle(fontSize: 10))))
                      .toList(),
                  onChanged: (l) {
                    if (l != null) setState(() => _selectedLanguage = l);
                  },
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
          _buildPermTile(
            icon: Icons.accessibility_new,
            title: 'Accessibility Service',
            subtitle: 'Required for God-Mode app control',
            isGranted: _accessibilityEnabled,
            isSpecial: true,
            onAction: _openAccessibilitySettings,
          ),
          _buildPermTile(
            icon: Icons.mic,
            title: 'Microphone',
            subtitle: 'Required for voice commands (STT)',
            isGranted: _permissions[Permission.microphone]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.microphone),
          ),
          // ✅ NEW: All Files Access (MANAGE_EXTERNAL_STORAGE)
          _buildPermTile(
            icon: Icons.folder_open_rounded,
            title: 'All Files Access',
            subtitle: 'God Mode — read/write any file on storage',
            isGranted: _permissions[Permission.manageExternalStorage]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.manageExternalStorage),
          ),
          _buildPermTile(
            icon: Icons.folder,
            title: 'Storage',
            subtitle: 'Required for file access',
            isGranted: _permissions[Permission.storage]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.storage),
          ),
          _buildPermTile(
            icon: Icons.camera_alt,
            title: 'Camera',
            subtitle: 'Required for vision features',
            isGranted: _permissions[Permission.camera]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.camera),
          ),
          _buildPermTile(
            icon: Icons.location_on,
            title: 'Location',
            subtitle: 'Required for location commands',
            isGranted: _permissions[Permission.location]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.location),
          ),
          _buildPermTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Required for Z.A.R.A. alerts',
            isGranted: _permissions[Permission.notification]?.isGranted ?? false,
            onAction: () => _requestPermission(Permission.notification),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPermTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onAction,
    bool isSpecial = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isGranted
                      ? AppColors.successGreen.withOpacity(0.15)
                      : AppColors.errorRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    size: 16,
                    color: isGranted
                        ? AppColors.successGreen
                        : AppColors.errorRed),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isGranted)
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFFF00FF), width: 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isSpecial ? 'Enable →' : 'Grant →',
                      style: const TextStyle(
                          color: Color(0xFFFF00FF),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('✓ ON',
                      style: TextStyle(
                          color: AppColors.successGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: AppColors.cyanPrimary.withOpacity(0.1)),
      ],
    );
  }

  Widget _buildPersonalizationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ownerNameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              labelText: '👑 Your Name (Z.A.R.A. calls you this)',
              labelStyle:
                  const TextStyle(color: Colors.white60, fontSize: 11),
              filled: true,
              fillColor: Colors.black.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('💞 Affection Level',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Text(
                '$_affectionLevel%',
                style: TextStyle(
                    color: _getAffectionColor(_affectionLevel),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Slider(
            value: _affectionLevel.toDouble(),
            min: 0,
            max: 100,
            divisions: 10,
            activeColor: _getAffectionColor(_affectionLevel),
            inactiveColor: Colors.white12,
            onChanged: (v) =>
                setState(() => _affectionLevel = v.toInt()),
          ),
          Center(
            child: Text(
              _getAffectionLabel(_affectionLevel),
              style: TextStyle(
                  color:
                      _getAffectionColor(_affectionLevel).withOpacity(0.7),
                  fontSize: 10,
                  letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Color _getAffectionColor(int level) {
    if (level >= 90) return Colors.pinkAccent;
    if (level >= 70) return AppColors.cyanPrimary;
    if (level >= 50) return Colors.white;
    return AppColors.warningOrange;
  }

  String _getAffectionLabel(int level) {
    if (level >= 90) return '💕 DEEPLY DEVOTED';
    if (level >= 70) return '💙 LOYAL COMPANION';
    if (level >= 50) return '🤍 PROFESSIONAL';
    if (level >= 30) return '🧊 FORMAL MODE';
    return '⚠️ MINIMAL ENGAGEMENT';
  }

  Widget _buildSaveButton() {
    final canSave = !_saving && _currentKeyValid;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: canSave ? _saveConfig : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canSave ? AppColors.cyanPrimary : Colors.grey.shade800,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: canSave ? 8 : 0,
          shadowColor: AppColors.cyanPrimary.withOpacity(0.4),
        ),
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2),
              )
            : const Text(
                '⚡ SAVE SYSTEM ARCHITECTURE',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.cyanPrimary.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: AppColors.cyanPrimary.withOpacity(0.03),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

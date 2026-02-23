// lib/screens/settings_screen.dart
// Z.A.R.A. — Complete Settings Screen
// ✅ Change API Keys Anytime • No Code Editing • Voice Selection
// ✅ SharedPreferences Persistence • Real-Time Status • Glassmorphic UI

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:zara_ai/core/constants/app_colors.dart';
import 'package:zara_ai/core/constants/app_text_styles.dart';
import 'package:zara_ai/core/constants/api_keys.dart';
import 'package:zara_ai/services/ai_api_service.dart';

/// Settings screen for Z.A.R.A. — manage API keys, voice, and language
/// All changes persist via SharedPreferences — no code editing needed!
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ========== UI State ==========
  
  Map<String, bool> _status = {};
  bool _loading = true;
  bool _saving = false;
  bool _obscureKeys = true;  // Hide API keys by default
  
  // ========== Input Controllers ==========
  
  final _geminiCtrl = TextEditingController();
  final _qwenCtrl = TextEditingController();
  final _llamaCtrl = TextEditingController();
  
  // ========== Voice & Language Selection ==========
  
  String _selectedVoice = ApiKeys.voiceName;
  String _selectedLanguage = ApiKeys.languageCode;
  
  // Available Google Neural Voices
  final List<Map<String, String>> _availableVoices = [
    {'name': 'hi-IN-SwaraNeural', 'label': 'Swara (Female, Hindi)'},
    {'name': 'hi-IN-MadhurNeural', 'label': 'Madhur (Male, Hindi)'},
    {'name': 'en-US-JennyNeural', 'label': 'Jenny (Female, English)'},
    {'name': 'en-US-GuyNeural', 'label': 'Guy (Male, English)'},
    {'name': 'en-GB-SoniaNeural', 'label': 'Sonia (Female, British)'},
    {'name': 'en-US-AriaNeural', 'label': 'Aria (Female, US)'},
    {'name': 'en-US-DavisNeural', 'label': 'Davis (Male, US)'},
    {'name': 'en-AU-NatashaNeural', 'label': 'Natasha (Female, Australian)'},
  ];
  
  // Available Languages
  final List<Map<String, String>> _availableLanguages = [
    {'code': 'hi-IN', 'label': 'Hindi (India)'},
    {'code': 'en-US', 'label': 'English (US)'},
    {'code': 'en-GB', 'label': 'English (UK)'},
    {'code': 'mr-IN', 'label': 'Marathi'},
    {'code': 'gu-IN', 'label': 'Gujarati'},
    {'code': 'ta-IN', 'label': 'Tamil'},
    {'code': 'te-IN', 'label': 'Telugu'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentValues();
    _loadStatus();
  }

  /// Load current API key values from ApiKeys class
  void _loadCurrentValues() {
    setState(() {
      _geminiCtrl.text = ApiKeys.gemini;
      _qwenCtrl.text = ApiKeys.qwen;
      _llamaCtrl.text = ApiKeys.llama;
      _selectedVoice = ApiKeys.voiceName;
      _selectedLanguage = ApiKeys.languageCode;
    });
  }

  /// Load API status from AiApiService
  Future<void> _loadStatus() async {
    final status = await AiApiService().checkStatus();
    setState(() {
      _status = status;
      _loading = false;
    });
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
      
      // AppBar with refresh action
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.cyanPrimary),
            onPressed: () {
              _loadCurrentValues();
              _loadStatus();
            },
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      
      // Main Content
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.cyanPrimary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Overview Card
                  _buildStatusOverviewCard(),
                  const SizedBox(height: 20),
                  
                  // API Keys Section
                  _buildSectionHeader('API Keys Configuration'),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    controller: _geminiCtrl,
                    label: 'Gemini API Key',
                    type: 'gemini',
                    isValid: _status['gemini'] ?? false,
                    getUrl: 'https://aistudio.google.com/apikey',
                    usage: 'Voice TTS/STT, Search, Image/PDF/Video Analysis',
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    controller: _qwenCtrl,
                    label: 'Qwen API Key',
                    type: 'qwen',
                    isValid: _status['qwen'] ?? false,
                    getUrl: 'https://dashscope.console.aliyun.com/apiKey',
                    usage: 'Code Generation (Primary)',
                  ),
                  const SizedBox(height: 12),
                  _buildApiKeyField(
                    controller: _llamaCtrl,
                    label: 'LLAMA API Key',
                    type: 'llama',
                    isValid: _status['llama'] ?? false,
                    getUrl: 'https://console.groq.com/keys',
                    usage: 'Emotional Conversations (Love, Angry, Ziddi)',
                  ),
                  const SizedBox(height: 24),
                  
                  // Voice & Language Section
                  _buildSectionHeader('Voice & Language'),
                  const SizedBox(height: 12),
                  _buildVoiceSelector(),
                  const SizedBox(height: 12),
                  _buildLanguageSelector(),
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  _buildSaveButton(),
                  const SizedBox(height: 12),
                  _buildResetButton(),
                  const SizedBox(height: 24),
                  
                  // Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ========== Status Overview Card ==========
  
  /// Card showing overall API configuration status
  Widget _buildStatusOverviewCard() {
    final allConfigured = _status['all'] ?? false;
    
    return Card(
      color: allConfigured 
          ? AppColors.successGreen.withOpacity(0.1) 
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: allConfigured ? AppColors.successGreen : AppColors.warningOrange,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              allConfigured ? Icons.check_circle : Icons.warning_amber,
              color: allConfigured ? AppColors.successGreen : AppColors.warningOrange,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allConfigured ? 'All APIs Configured ✓' : 'API Keys Required',
                    style: TextStyle(
                      color: allConfigured 
                          ? AppColors.successGreen 
                          : AppColors.warningOrange,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allConfigured 
                        ? 'Z.A.R.A. ready for full AI features!' 
                        : 'Configure APIs to unlock code, voice & emotional chat',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Section Headers ==========
  
  /// Styled section header
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.sciFiTitle.copyWith(
        fontSize: 16,
        letterSpacing: 1.5,
      ),
    );
  }

  // ========== API Key Input Fields ==========
  
  /// Input field for API key with validation, paste, and visibility toggle
  Widget _buildApiKeyField({
    required TextEditingController controller,
    required String label,
    required String type,
    required bool isValid,
    required String getUrl,
    required String usage,
  }) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isValid ? AppColors.successGreen : AppColors.textDim,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + Status Icon
            Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'RobotoMono',
                  ),
                ),
                const Spacer(),
                Icon(
                  isValid ? Icons.check_circle : Icons.cancel,
                  color: isValid ? AppColors.successGreen : AppColors.errorRed,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Usage description
            Text(
              usage,
              style: TextStyle(
                color: AppColors.textDim,
                fontSize: 10,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 12),
            
            // Input field with suffix icons
            TextField(
              controller: controller,
              obscureText: _obscureKeys,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'RobotoMono',
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: 'Paste your API key here...',
                hintStyle: TextStyle(
                  color: AppColors.textDim,
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.cyanPrimary.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.textDim.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.cyanPrimary,
                    width: 1.5,
                  ),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Paste button
                    IconButton(
                      icon: const Icon(Icons.content_paste, size: 18),
                      onPressed: () async {
                        final clipboard = await Clipboard.getData('text/plain');
                        if (clipboard?.text != null) {
                          controller.text = clipboard!.text!;
                        }
                      },
                      tooltip: 'Paste from clipboard',
                    ),
                    // Show/Hide toggle
                    IconButton(
                      icon: Icon(
                        _obscureKeys ? Icons.visibility : Icons.visibility_off,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureKeys = !_obscureKeys;
                        });
                      },
                      tooltip: _obscureKeys ? 'Show key' : 'Hide key',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Get Key link + validation status
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    // TODO: Open URL in browser using url_launcher
                    debugPrint('Opening: $getUrl');
                  },
                  child: Text(
                    'Get API Key →',
                    style: TextStyle(
                      color: AppColors.cyanPrimary,
                      fontSize: 11,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  isValid ? 'Valid ✓' : 'Invalid/Expired',
                  style: TextStyle(
                    color: isValid ? AppColors.successGreen : AppColors.errorRed,
                    fontSize: 10,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== Voice Selector ==========
  
  /// Dropdown for selecting TTS voice
  Widget _buildVoiceSelector() {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.cyanPrimary.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice Selection',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedVoice,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.cyanPrimary.withOpacity(0.3),
                  ),
                ),
              ),
              items: _availableVoices.map((voice) {
                return DropdownMenuItem(
                  value: voice['name'],
                  child: Text(
                    voice['label']!,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedVoice = value;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Current: $_selectedVoice',
              style: TextStyle(
                color: AppColors.textDim,
                fontSize: 10,
                fontFamily: 'RobotoMono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Language Selector ==========
  
  /// Dropdown for selecting language code
  Widget _buildLanguageSelector() {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.cyanPrimary.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'RobotoMono',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: AppColors.cyanPrimary.withOpacity(0.3),
                  ),
                ),
              ),
              items: _availableLanguages.map((lang) {
                return DropdownMenuItem(
                  value: lang['code'],
                  child: Text(
                    lang['label']!,
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ========== Action Buttons ==========
  
  /// Save button with loading state
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _saveSettings,
        icon: _saving 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _saving ? 'Saving...' : 'Save Configuration',
          style: const TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyanPrimary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
  
  /// Reset button with confirmation dialog
  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _saving ? null : _resetKeys,
        icon: const Icon(Icons.delete_outline),
        label: const Text(
          'Reset All API Keys',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.errorRed,
          side: const BorderSide(color: AppColors.errorRed),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ========== Info Card ==========
  
  /// Important notes and security reminders
  Widget _buildInfoCard() {
    return Card(
      color: AppColors.infoBlue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.infoBlue.withOpacity(0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.infoBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Important Notes',
                  style: TextStyle(
                    color: AppColors.infoBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoItem('✅ API keys saved locally (SharedPreferences)'),
            _buildInfoItem('✅ Change keys anytime from this screen'),
            _buildInfoItem('✅ No code editing EVER needed!'),
            _buildInfoItem('✅ Keys persist after app restart'),
            _buildInfoItem('✅ Voice changes apply immediately'),
            const SizedBox(height: 8),
            Text(
              '⚠️ Never share your API keys with anyone',
              style: TextStyle(
                color: AppColors.errorRed,
                fontSize: 11,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Single info item with bullet point
  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontFamily: 'RobotoMono',
        ),
      ),
    );
  }

  // ========== Save & Reset Logic ==========
  
  /// Save all settings to SharedPreferences
  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    
    try {
      // Save API keys
      await ApiKeys.saveApiKey('gemini', _geminiCtrl.text);
      await ApiKeys.saveApiKey('qwen', _qwenCtrl.text);
      await ApiKeys.saveApiKey('llama', _llamaCtrl.text);
      
      // Save voice & language
      await ApiKeys.saveApiKey('voice', _selectedVoice);
      await ApiKeys.saveApiKey('language', _selectedLanguage);
      
      // Refresh status
      await _loadStatus();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Settings saved! API keys updated.'),
            backgroundColor: AppColors.successGreen,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('✅ Settings saved successfully');
      }
      
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving: $e'),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ Save settings error: $e');
      }
    } finally {
      setState(() => _saving = false);
    }
  }
  
  /// Reset all API keys with confirmation
  Future<void> _resetKeys() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.errorRed.withOpacity(0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.errorRed),
            const SizedBox(width: 8),
            const Text(
              'Reset API Keys?',
              style: TextStyle(fontFamily: 'RobotoMono'),
            ),
          ],
        ),
        content: const Text(
          'This will clear all saved API keys. You will need to enter them again to use AI features.',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'RobotoMono'),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Reset',
              style: TextStyle(fontFamily: 'RobotoMono'),
            ),
          ),
        ],
      ),
    );
    
    // If confirmed, clear all keys
    if (confirmed == true) {
      await ApiKeys.clearAll();
      
      // Reset UI
      _loadCurrentValues();
      await _loadStatus();
      
      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ All API keys reset'),
            backgroundColor: AppColors.warningOrange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

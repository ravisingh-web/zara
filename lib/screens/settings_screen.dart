import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zara/core/constants/app_colors.dart';
import 'package:zara/core/constants/api_keys.dart';
import 'package:zara/services/ai_api_service.dart';
import 'package:zara/services/accessibility_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ========== State Management ==========
  Map<String, bool> _apiStatus = {};
  Map<Permission, PermissionStatus> _permissions = {};
  bool _accessibilityEnabled = false;
  bool _loading = true;
  bool _saving = false;

  final _geminiCtrl = TextEditingController();
  final _qwenCtrl = TextEditingController();
  final _llamaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _loading = true);

    // 1. Load API Values
    _geminiCtrl.text = ApiKeys.gemini;
    _qwenCtrl.text = ApiKeys.qwen;
    _llamaCtrl.text = ApiKeys.llama;

    // 2. Check API Health
    _apiStatus = await AiApiService().checkStatus();

    // 3. Check All System Permissions (Real Logic)
    await _checkPermissions();

    setState(() => _loading = false);
  }

  Future<void> _checkPermissions() async {
    final List<Permission> permissionList = [
      Permission.camera,
      Permission.contacts,
      Permission.sms,
      Permission.notification,
      Permission.location,
      Permission.systemAlertWindow, // Overlay
      Permission.manageExternalStorage, // Android 11+ Storage
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissionList) {
      statuses[permission] = await permission.status;
    }

    // ✅ FIXED: isEnabled() was a getter, changed to checkServiceEnabled() function
    final accessEnabled = await AccessibilityService().checkServiceEnabled();

    setState(() {
      _permissions = statuses;
      _accessibilityEnabled = accessEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Z.A.R.A. SYSTEM CONFIG', style: TextStyle(fontFamily: 'monospace', fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.neonCyan),
            onPressed: _loadAllData,
          )
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.neonCyan))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('SYSTEM PERMISSIONS (GOD MODE)'),
                const SizedBox(height: 12),
                _buildPermissionCard(),
                const SizedBox(height: 24),

                _buildSectionHeader('NEURAL API KEYS'),
                const SizedBox(height: 12),
                _buildApiCard('Gemini (Speech/Analysis)', _geminiCtrl, _apiStatus['gemini'] ?? false),
                _buildApiCard('Qwen (Code Generation)', _qwenCtrl, _apiStatus['qwen'] ?? false),
                _buildApiCard('Llama (Emotional Chat)', _llamaCtrl, _apiStatus['llama'] ?? false),

                const SizedBox(height: 32),
                _buildSaveButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  // ========== UI HELPER WIDGETS ==========

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: AppColors.neonCyan, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _buildPermissionTile('Accessibility Service', _accessibilityEnabled, () => AccessibilityService().openSettings()),
          _buildPermissionTile('Camera (Security)', _permissions[Permission.camera]?.isGranted ?? false, () => Permission.camera.request().then((_) => _checkPermissions())),
          _buildPermissionTile('Overlay (Hologram)', _permissions[Permission.systemAlertWindow]?.isGranted ?? false, () => Permission.systemAlertWindow.request().then((_) => _checkPermissions())),
          _buildPermissionTile('All Files Storage', _permissions[Permission.manageExternalStorage]?.isGranted ?? false, () => Permission.manageExternalStorage.request().then((_) => _checkPermissions())),
          _buildPermissionTile('Contacts & SMS', (_permissions[Permission.contacts]?.isGranted ?? false) && (_permissions[Permission.sms]?.isGranted ?? false), () async {
            await [Permission.contacts, Permission.sms].request();
            _checkPermissions();
          }),
          _buildPermissionTile('Location Tracker', _permissions[Permission.location]?.isGranted ?? false, () => Permission.location.request().then((_) => _checkPermissions())),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(String title, bool isGranted, VoidCallback onTap) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: isGranted
        ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
        : ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: const Text('GRANT', style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
    );
  }

  Widget _buildApiCard(String label, TextEditingController ctrl, bool isValid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isValid ? Colors.green.withOpacity(0.3) : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.black,
              hintText: 'Enter Key...',
              hintStyle: const TextStyle(color: Colors.white24),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saving ? null : _saveConfig,
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.neonCyan, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: _saving
          ? const CircularProgressIndicator(color: Colors.black)
          : const Text('SAVE SYSTEM ARCHITECTURE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {                                                                    await ApiKeys.saveApiKey('gemini', _geminiCtrl.text);
      await ApiKeys.saveApiKey('qwen', _qwenCtrl.text);
      await ApiKeys.saveApiKey('llama', _llamaCtrl.text);
      await _loadAllData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Z.A.R.A. System Updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Update Failed: $e')));
    } finally {
      setState(() => _saving = false);
    }
  }
}

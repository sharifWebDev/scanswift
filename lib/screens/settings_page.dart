import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with SingleTickerProviderStateMixin {
  // ── Preference values ──────────────────────────────────────────────────────
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _saveHistory = true;
  String _scanMode = 'Automatic';
  String _language = 'English';
  String _defaultCodeType = 'QR Code';

  // ── Storage stats ──────────────────────────────────────────────────────────
  String _cacheSize = 'Calculating...';
  bool _loadingCache = true;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Prefs keys ─────────────────────────────────────────────────────────────
  static const _kSound = 'soundEnabled';
  static const _kVibration = 'vibrationEnabled';
  static const _kSaveHistory = 'saveHistory';
  static const _kScanMode = 'scanMode';
  static const _kLanguage = 'language';
  static const _kDefaultCode = 'defaultCodeType';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
    _loadSettings();
    _computeCacheSize();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Load all settings from SharedPreferences ───────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _soundEnabled = prefs.getBool(_kSound) ?? true;
      _vibrationEnabled = prefs.getBool(_kVibration) ?? true;
      _saveHistory = prefs.getBool(_kSaveHistory) ?? true;
      _scanMode = prefs.getString(_kScanMode) ?? 'Automatic';
      _language = prefs.getString(_kLanguage) ?? 'English';
      _defaultCodeType = prefs.getString(_kDefaultCode) ?? 'QR Code';
    });
  }

  // ── Persist a single bool value ───────────────────────────────────────────
  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ── Persist a single string value ─────────────────────────────────────────
  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // ── Compute app documents directory size ──────────────────────────────────
  Future<void> _computeCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final size = await _dirSize(dir);
      if (!mounted) return;
      setState(() {
        _cacheSize = _formatBytes(size);
        _loadingCache = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cacheSize = 'N/A';
        _loadingCache = false;
      });
    }
  }

  Future<int> _dirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Clear scan history ────────────────────────────────────────────────────
  Future<void> _clearHistory(Box<ScanModel> box) async {
    final confirmed = await _confirmDialog(
      title: 'Clear History?',
      content: 'This will permanently delete all scan records. This cannot be undone.',
      confirmLabel: 'Clear',
      confirmColor: Colors.red.shade700,
    );
    if (!confirmed) return;
    await box.clear();
    await _computeCacheSize();
    _snack('Scan history cleared', Colors.green.shade700);
  }

  // ── Reset all settings to defaults ───────────────────────────────────────
  Future<void> _resetDefaults() async {
    final confirmed = await _confirmDialog(
      title: 'Reset Settings?',
      content: 'All settings will be restored to their default values.',
      confirmLabel: 'Reset',
      confirmColor: Colors.orange.shade700,
    );
    if (!confirmed) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSound);
    await prefs.remove(_kVibration);
    await prefs.remove(_kSaveHistory);
    await prefs.remove(_kScanMode);
    await prefs.remove(_kLanguage);
    await prefs.remove(_kDefaultCode);
    await _loadSettings();
    _snack('Settings reset to defaults', Colors.orange.shade700);
  }

  // ── Generic confirm dialog ────────────────────────────────────────────────
  Future<bool> _confirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            content: Text(content,
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Snackbar helper ───────────────────────────────────────────────────────
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      elevation: 0,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: ValueListenableBuilder(
          valueListenable: DatabaseService.getHistoryBox().listenable(),
          builder: (context, Box<ScanModel> box, _) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Preferences ─────────────────────────────────────────
                  _buildCard(
                    title: 'Preferences',
                    icon: Icons.tune_rounded,
                    children: [
                      _buildSwitch(
                        icon: Icons.volume_up_rounded,
                        title: 'Sound Effects',
                        subtitle: 'Play beep sound on successful scan',
                        value: _soundEnabled,
                        onChanged: (v) async {
                          setState(() => _soundEnabled = v);
                          await _saveBool(_kSound, v);
                          _snack(
                              v ? 'Sound effects enabled' : 'Sound effects disabled',
                              Colors.deepPurple.shade600);
                        },
                      ),
                      _buildDivider(),
                      _buildSwitch(
                        icon: Icons.vibration_rounded,
                        title: 'Vibration',
                        subtitle: 'Haptic feedback on scan',
                        value: _vibrationEnabled,
                        onChanged: (v) async {
                          setState(() => _vibrationEnabled = v);
                          await _saveBool(_kVibration, v);
                          _snack(
                              v ? 'Vibration enabled' : 'Vibration disabled',
                              Colors.deepPurple.shade600);
                        },
                      ),
                      _buildDivider(),
                      _buildSwitch(
                        icon: Icons.history_rounded,
                        title: 'Save Scan History',
                        subtitle: 'Store scans in local history',
                        value: _saveHistory,
                        onChanged: (v) async {
                          setState(() => _saveHistory = v);
                          await _saveBool(_kSaveHistory, v);
                          _snack(
                              v ? 'History saving enabled' : 'History saving disabled',
                              Colors.deepPurple.shade600);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Scan Settings ────────────────────────────────────────
                  _buildCard(
                    title: 'Scan Settings',
                    icon: Icons.qr_code_scanner_rounded,
                    children: [
                      _buildDropdown(
                        icon: Icons.play_circle_rounded,
                        title: 'Scan Mode',
                        subtitle: 'Scanning trigger behavior',
                        value: _scanMode,
                        items: const ['Automatic', 'Manual', 'Continuous'],
                        onChanged: (v) async {
                          setState(() => _scanMode = v!);
                          await _saveString(_kScanMode, v!);
                          _snack('Scan mode set to $v', Colors.deepPurple.shade600);
                        },
                      ),
                      _buildDivider(),
                      _buildDropdown(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Default Code Type',
                        subtitle: 'Default type for generator',
                        value: _defaultCodeType,
                        items: const ['QR Code', 'Barcode', 'Data Matrix'],
                        onChanged: (v) async {
                          setState(() => _defaultCodeType = v!);
                          await _saveString(_kDefaultCode, v!);
                          _snack('Default code type set to $v',
                              Colors.deepPurple.shade600);
                        },
                      ),
                      _buildDivider(),
                      _buildDropdown(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'App display language',
                        value: _language,
                        items: const ['English', 'Spanish', 'French', 'German', 'Arabic'],
                        onChanged: (v) async {
                          setState(() => _language = v!);
                          await _saveString(_kLanguage, v!);
                          _snack('Language set to $v', Colors.deepPurple.shade600);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Storage ──────────────────────────────────────────────
                  _buildCard(
                    title: 'Storage',
                    icon: Icons.storage_rounded,
                    children: [
                      _buildInfo(
                        icon: Icons.history_rounded,
                        title: 'History Records',
                        subtitle: 'Scans stored on this device',
                        value: '${box.length} item${box.length == 1 ? '' : 's'}',
                        valueColor: Colors.deepPurple.shade700,
                      ),
                      _buildDivider(),
                      _buildInfo(
                        icon: Icons.folder_rounded,
                        title: 'App Storage',
                        subtitle: 'Documents directory size',
                        value: _loadingCache ? '...' : _cacheSize,
                        valueColor: Colors.blue.shade700,
                      ),
                      _buildDivider(),
                      // Clear history action row
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.delete_sweep_rounded,
                              color: Colors.red.shade600, size: 20),
                        ),
                        title: Text('Clear Scan History',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700)),
                        subtitle: Text(
                            box.isEmpty
                                ? 'No records to clear'
                                : 'Remove all ${box.length} record${box.length == 1 ? '' : 's'}',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.grey.shade600)),
                        trailing: Icon(Icons.arrow_forward_ios_rounded,
                            size: 16, color: Colors.grey.shade400),
                        onTap: box.isEmpty ? null : () => _clearHistory(box),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── About ────────────────────────────────────────────────
                  _buildCard(
                    title: 'About',
                    icon: Icons.info_outline_rounded,
                    children: [
                      _buildInfo(
                        icon: Icons.verified_rounded,
                        title: 'App Version',
                        subtitle: 'Current release',
                        value: '1.0.0',
                        valueColor: Colors.green.shade700,
                      ),
                      _buildDivider(),
                      _buildInfo(
                        icon: Icons.build_rounded,
                        title: 'Build Number',
                        subtitle: 'Internal build',
                        value: '+1',
                        valueColor: Colors.grey.shade600,
                      ),
                      _buildDivider(),
                      _buildInfo(
                        icon: Icons.business_center_rounded,
                        title: 'License',
                        subtitle: 'License type',
                        value: 'Enterprise',
                        valueColor: Colors.deepPurple.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Reset Button ─────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _resetDefaults,
                      icon: Icon(Icons.restore_rounded,
                          size: 18, color: Colors.orange.shade700),
                      label: Text(
                        'Reset All Settings to Defaults',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.orange.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.orange.shade50,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.deepPurple.shade800,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_rounded, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Settings',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: false,
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: Colors.deepPurple.shade700),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800)),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(
      height: 1, indent: 56, endIndent: 16, color: Colors.grey.shade100);

  // ── Switch tile ───────────────────────────────────────────────────────────
  Widget _buildSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: value
              ? Colors.deepPurple.shade50
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: value
                ? Colors.deepPurple.shade600
                : Colors.grey.shade500,
            size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey.shade800)),
      subtitle: Text(subtitle,
          style:
              GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple.shade600,
    );
  }

  // ── Dropdown tile ─────────────────────────────────────────────────────────
  Widget _buildDropdown({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.deepPurple.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: Colors.grey.shade800)),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurple.shade100),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              icon: Icon(Icons.expand_more_rounded,
                  size: 18, color: Colors.deepPurple.shade600),
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade700),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Info tile ─────────────────────────────────────────────────────────────
  Widget _buildInfo({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.grey.shade800)),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: valueColor)),
      ]),
    );
  }
}

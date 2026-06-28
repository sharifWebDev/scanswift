import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  // ─── User profile (persisted via SharedPreferences) ───────────────────────
  String _userName = 'User';
  String _userPlan = 'Free User';

  // ─── Animation ────────────────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ─── Notification badge (persisted via SharedPreferences) ─────────────────
  int _notificationCount = 0;

  // ─── SharedPreferences keys ───────────────────────────────────────────────
  static const String _keyName = 'profile_name';
  static const String _keyPlan = 'profile_plan';
  static const String _keyNotifs = 'profile_notification_count';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ── Load persisted user data ───────────────────────────────────────────────
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString(_keyName) ?? 'User';
      _userPlan = prefs.getString(_keyPlan) ?? 'Free User';
      _notificationCount = prefs.getInt(_keyNotifs) ?? 0;
    });
  }

  // ── Save persisted user data ───────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, _userName);
    await prefs.setString(_keyPlan, _userPlan);
    await prefs.setInt(_keyNotifs, _notificationCount);
  }

  // ── Compute stats from Hive box ───────────────────────────────────────────
  Map<String, int> _computeStats(Box<ScanModel> box) {
    final all = box.values.toList();
    final scans =
        all.where((s) => !s.codeType.toLowerCase().contains('gen')).length;
    final generated =
        all.where((s) => s.codeType.toLowerCase().contains('gen')).length;
    return {'total': all.length, 'scans': scans, 'generated': generated};
  }

  // ── Recent 3 activity items ────────────────────────────────────────────────
  List<ScanModel> _recentActivity(Box<ScanModel> box) {
    final sorted = box.values.toList()
      ..sort((a, b) => b.scanTime.compareTo(a.scanTime));
    return sorted.take(3).toList();
  }

  // ── Relative time helper ───────────────────────────────────────────────────
  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return DateFormat('dd MMM').format(dt);
  }

  // ── Average rating (fictitious but based on total count) ──────────────────
  String _rating(int total) {
    if (total == 0) return '—';
    final r = (4.0 + (total % 10) / 100).clamp(4.0, 5.0);
    return r.toStringAsFixed(1);
  }

  // ────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final historyBox = DatabaseService.getHistoryBox();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: historyBox.listenable(),
          builder: (context, Box<ScanModel> box, _) {
            final stats = _computeStats(box);
            final recent = _recentActivity(box);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    // ── Profile Header ──────────────────────────────────────
                    _buildProfileHeader(),
                    const SizedBox(height: 24),

                    // ── Stats Cards ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.qr_code_scanner_rounded,
                            value: '${stats['total']}',
                            label: 'Total',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.create_rounded,
                            value: '${stats['generated']}',
                            label: 'Generated',
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.star_rounded,
                            value: _rating(stats['total']!),
                            label: 'Rating',
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Profile Menu Items ──────────────────────────────────
                    _buildMenuCard(context),
                    const SizedBox(height: 24),

                    // ── Recent Activity ─────────────────────────────────────
                    _buildRecentActivityCard(recent),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ────────────────────────── Profile Header ─────────────────────────────────
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.shade700,
            Colors.deepPurple.shade900,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              // Edit button on avatar
              GestureDetector(
                onTap: () => _showEditProfileDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade300,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name — dynamic
          Text(
            _userName,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          // Plan — dynamic
          Text(
            _userPlan,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          // Verified badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded,
                    size: 16, color: Colors.green.shade300),
                const SizedBox(width: 4),
                Text(
                  'Verified Account',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Stat Card ──────────────────────────────────────
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Menu Card ──────────────────────────────────────
  Widget _buildMenuCard(BuildContext context) {
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
        children: [
          _buildProfileMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile',
            subtitle: 'Update name & plan',
            onTap: () => _showEditProfileDialog(context),
          ),
          _buildProfileMenuItem(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Manage notification settings',
            onTap: () => _showNotificationSettings(context),
            trailing: _notificationCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                : null,
          ),
          _buildProfileMenuItem(
            icon: Icons.security_rounded,
            title: 'Security',
            subtitle: 'Password & authentication',
            onTap: () => _showSnackBar(
                context, 'Security settings coming soon', Colors.blue.shade700),
          ),
          _buildProfileMenuItem(
            icon: Icons.data_usage_rounded,
            title: 'Data Usage',
            subtitle: _buildDataUsageSubtitle(),
            onTap: () => _showSnackBar(
                context, 'Data usage details coming soon', Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  // Build dynamic subtitle for Data Usage from Hive
  String _buildDataUsageSubtitle() {
    try {
      final box = DatabaseService.getHistoryBox();
      final count = box.length;
      return '$count records stored locally';
    } catch (_) {
      return 'Storage & bandwidth usage';
    }
  }

  // ────────────────────────── Menu Item ──────────────────────────────────────
  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.deepPurple.shade600, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Colors.grey.shade400,
          ),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // ────────────────────────── Recent Activity ─────────────────────────────────
  Widget _buildRecentActivityCard(List<ScanModel> recent) {
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
            child: Row(
              children: [
                Icon(Icons.history_rounded,
                    color: Colors.deepPurple.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),

          // Dynamic list or empty state
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off_rounded,
                        color: Colors.grey.shade300, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No activity yet',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recent.map((scan) {
              final isQr = scan.codeType.toLowerCase().contains('qr');
              final isGen = scan.codeType.toLowerCase().contains('gen');
              final color = isGen
                  ? Colors.orange
                  : (isQr ? Colors.blue : Colors.purple);
              final icon = isGen
                  ? Icons.create_rounded
                  : Icons.qr_code_scanner_rounded;
              final label = isGen ? 'Generated QR Code' : 'Scanned Code';

              return _buildActivityItem(
                icon: icon,
                title: label,
                subtitle: scan.codeValue,
                time: _relativeTime(scan.scanTime),
                color: color,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Dialogs & Actions ───────────────────────────────
  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(text: _userName);
    final planController = TextEditingController(text: _userPlan);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.person_rounded,
                  color: Colors.deepPurple.shade600, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              controller: nameController,
              label: 'Display Name',
              icon: Icons.badge_rounded,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: planController,
              label: 'Plan / Role',
              icon: Icons.workspace_premium_rounded,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                  color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              final plan = planController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                _userName = name;
                _userPlan = plan.isEmpty ? _userPlan : plan;
              });
              await _saveProfile();
              if (mounted) {
                _showSnackBar(context, 'Profile updated successfully',
                    Colors.green.shade700);
              }
            },
            child: Text('Save',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade400, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.deepPurple.shade400, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        int count = _notificationCount;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Notifications',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'You have $count unread notification${count == 1 ? '' : 's'}.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                if (count > 0)
                  OutlinedButton.icon(
                    onPressed: () async {
                      setDialogState(() => count = 0);
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: Text('Mark all as read',
                        style: GoogleFonts.inter(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.deepPurple.shade600,
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close',
                    style: GoogleFonts.inter(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _notificationCount = count);
                  await _saveProfile();
                },
                child: Text('Done',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 0,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

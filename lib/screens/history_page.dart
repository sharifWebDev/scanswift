import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';
import 'result_screen.dart';
import '../widgets/ad_banner.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _filterType = 'All';
  final List<String> _filterOptions = ['All', 'QR Code', 'Barcode'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _showConfirmDialog(BuildContext context,
      {required String title, required String content}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.08),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_forever_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
            ),
            title: Text(
              title,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              content,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final historyBox = DatabaseService.getHistoryBox();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ValueListenableBuilder(
                valueListenable: historyBox.listenable(),
                builder: (context, Box<ScanModel> box, _) {
                  final items = _getFilteredItems(box);

                  if (items.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final scan = items[index];
                      final key = box.keys.toList()[index];
                      return _buildHistoryCard(scan, key, box);
                    },
                  );
                },
              ),
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.deepPurple.shade800,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade700
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Scan History',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.grey.shade800,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        ValueListenableBuilder(
          valueListenable: DatabaseService.getHistoryBox().listenable(),
          builder: (context, Box<ScanModel> box, _) {
            if (box.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.delete_sweep_rounded,
                  color: Colors.red.shade700,
                  size: 20,
                ),
                tooltip: 'Clear All History',
                padding: const EdgeInsets.all(8),
                onPressed: () async {
                  bool confirm = await _showConfirmDialog(
                    context,
                    title: 'Clear All History?',
                    content:
                        'Are you sure you want to permanently delete all scan history? This action cannot be undone.',
                  );
                  if (confirm) {
                    await box.clear();
                    _showSnackBar('All history cleared successfully',
                        Colors.green.shade700);
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Search history...',
          hintStyle: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey.shade400,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade400,
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade400,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  padding: const EdgeInsets.all(4),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        ),
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((filter) {
            final isSelected = _filterType == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  filter,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    _filterType = filter;
                  });
                },
                selectedColor: Colors.deepPurple.shade600,
                backgroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.deepPurple.shade600
                        : Colors.grey.shade300,
                    width: 1.2,
                  ),
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<ScanModel> _getFilteredItems(Box<ScanModel> box) {
    final allItems = box.values.toList().reversed.toList();

    return allItems.where((scan) {
      final matchesSearch = _searchQuery.isEmpty ||
          scan.codeValue.toLowerCase().contains(_searchQuery);
      final matchesFilter = _filterType == 'All' ||
          scan.codeType.toLowerCase().contains(_filterType.toLowerCase());
      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildHistoryCard(ScanModel scan, dynamic key, Box<ScanModel> box) {
    final formattedDate =
        DateFormat('dd MMM yyyy • hh:mm a').format(scan.scanTime);
    final isUrl = scan.codeValue.startsWith('http');
    final isQr = scan.codeType.toLowerCase().contains('qr');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResultScreen(
                  codeValue: scan.codeValue,
                  codeType: scan.codeType,
                  fromHistory: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isUrl
                          ? [Colors.blue.shade400, Colors.blue.shade700]
                          : (isQr
                              ? [
                                  Colors.deepPurple.shade400,
                                  Colors.deepPurple.shade700
                                ]
                              : [
                                  Colors.orange.shade400,
                                  Colors.orange.shade700
                                ]),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (isUrl
                                ? Colors.blue
                                : (isQr ? Colors.deepPurple : Colors.orange))
                            .withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isUrl
                        ? Icons.language_rounded
                        : (isQr
                            ? Icons.qr_code_2_rounded
                            : Icons
                                .qr_code_rounded), // Using QR code icon for barcode
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scan.codeValue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formattedDate,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isUrl
                                  ? Colors.blue
                                  : (isQr ? Colors.deepPurple : Colors.orange))
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUrl
                                  ? Icons.public_rounded
                                  : (isQr
                                      ? Icons.qr_code_rounded
                                      : Icons
                                          .qr_code_rounded), // Using QR code icon for barcode
                              size: 10,
                              color: isUrl
                                  ? Colors.blue.shade700
                                  : (isQr
                                      ? Colors.deepPurple.shade700
                                      : Colors.orange.shade700),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              scan.codeType.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                color: isUrl
                                    ? Colors.blue.shade700
                                    : (isQr
                                        ? Colors.deepPurple.shade700
                                        : Colors.orange.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.grey.shade400,
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(8),
                    onPressed: () async {
                      bool confirm = await _showConfirmDialog(
                        context,
                        title: 'Delete Scan?',
                        content:
                            'Are you sure you want to remove this record from history?',
                      );
                      if (confirm) {
                        await box.delete(key);
                        _showSnackBar(
                            'Item deleted successfully', Colors.green.shade700);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_toggle_off_rounded,
              size: 56,
              color: Colors.deepPurple.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No History Found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _filterType != 'All'
                ? 'Try adjusting your search or filters'
                : 'Start scanning to see your history here',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty || _filterType != 'All') ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _filterType = 'All';
                });
              },
              child: Text(
                'Clear Filters',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 0,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

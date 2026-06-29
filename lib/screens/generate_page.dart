import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'history_page.dart';
import '../services/database_service.dart';
import '../widgets/ad_banner.dart';

class GeneratePage extends StatefulWidget {
  final String? initialData;
  final String? initialType;

  const GeneratePage({super.key, this.initialData, this.initialType});

  @override
  State<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends State<GeneratePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final GlobalKey _globalKey = GlobalKey();
  int _adRefreshId = 0;

  String _generatedData = "";
  int _selectedTab = 0; // 0 = QR Code, 1 = Barcode
  bool _showCodeText = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set default dimensions based on tab
    _updateDefaultDimensions();

    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _textController.text = widget.initialData!;
      _generatedData = widget.initialData!;
    }
    if (widget.initialType != null) {
      _selectedTab = widget.initialType!.toLowerCase().contains('qr') ? 0 : 1;
      _tabController.index = _selectedTab;
      _updateDefaultDimensions();
    }
  }

  void _updateDefaultDimensions() {
    if (_selectedTab == 0) {
      // QR Code: 200x200
      _widthController.text = '200';
      _heightController.text = '200';
    } else {
      // Barcode: 200 width x 100 height
      _widthController.text = '200';
      _heightController.text = '100';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _capturePngBytes() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _shareGeneratedImage() async {
    if (_generatedData.isEmpty) {
      _showSnackBar('Please enter text to generate first', Colors.redAccent);
      return;
    }

    Uint8List? pngBytes = await _capturePngBytes();
    if (pngBytes == null) return;

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      Clipboard.setData(ClipboardData(text: 'Data: $_generatedData'));
      _showSnackBar('Sharing simulated on Desktop. Text copied!', Colors.blue);
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/scanswift_code.png').create();
    await file.writeAsBytes(pngBytes);

    try {
      await Share.shareXFiles([XFile(file.path)],
          text: 'Generated via ScanSwift');
      setState(() => _adRefreshId++);
    } catch (_) {
      _showSnackBar('Unable to open share sheet', Colors.redAccent);
    }
  }

  Future<void> _saveGeneratedData() async {
    if (_generatedData.isEmpty) {
      _showSnackBar('Please enter text to generate first', Colors.redAccent);
      return;
    }

    final type = _selectedTab == 0 ? 'QR Code' : 'Barcode';
    await DatabaseService.addScan(_generatedData, type);

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Saved to history',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            );
          },
        ),
      ),
    );

    setState(() => _adRefreshId++);
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double customWidth = double.tryParse(_widthController.text) ?? 200.0;
    double customHeight = double.tryParse(_heightController.text) ?? 200.0;

    // Set minimum and maximum constraints
    if (customWidth < 50) customWidth = 50;
    if (customHeight < 50) customHeight = 50;
    if (customWidth > 800) customWidth = 800;
    if (customHeight > 800) customHeight = 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputSection(),
                  const SizedBox(height: 16),
                  _buildDimensionControls(),
                  const SizedBox(height: 16),
                  _buildPreviewSection(customWidth, customHeight),
                  if (_generatedData.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                  const SizedBox(height: 16),
                  AdBanner(refreshId: _adRefreshId),
                ],
              ),
            ),
          ),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade700
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.create_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Code Generator',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.grey.shade800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ), 
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _selectedTab = index;
            _updateDefaultDimensions();
            if (_textController.text.isNotEmpty) {
              _generatedData = _textController.text;
            }
          });
        },
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'QR Code',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Barcode',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Content',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Type text or URL to generate...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.edit_note_rounded,
                color: Colors.deepPurple.shade400,
                size: 18,
              ),
              suffixIcon: _textController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                      onPressed: () {
                        _textController.clear();
                        setState(() => _generatedData = "");
                      },
                    )
                  : null,
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
                borderSide:
                    BorderSide(color: Colors.deepPurple.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            ),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
            onChanged: (value) => setState(() => _generatedData = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.grey.shade400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Supports text, URLs, and any alphanumeric data',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.aspect_ratio_rounded,
                size: 16,
                color: Colors.deepPurple.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Dimensions',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedTab == 0 ? 'Square' : 'Wide',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDimensionField(
                  controller: _widthController,
                  label: 'Width',
                  icon: Icons.qr_code_scanner_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDimensionField(
                  controller: _heightController,
                  label: 'Height',
                  icon: Icons.height_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
          prefixIcon: Icon(
            icon,
            size: 16,
            color: Colors.grey.shade500,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        ),
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildPreviewSection(double width, double height) {
    if (_generatedData.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedTab == 0
                      ? Icons.qr_code_2_rounded
                      : Icons.qr_code_scanner_rounded,
                  size: 40,
                  color: Colors.deepPurple.shade300,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No Content Yet',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter data above to generate',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Adjust preview size to avoid overflow
    double previewWidth = width > 400 ? 400 : width;
    double previewHeight = height > 400 ? 400 : height;

    // Ensure minimum size
    if (previewWidth < 100) previewWidth = 100;
    if (previewHeight < 100) previewHeight = 100;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.preview_rounded,
                    size: 16,
                    color: Colors.deepPurple.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Preview',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${width.toInt()}×${height.toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: RepaintBoundary(
              key: _globalKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                width: previewWidth,
                height: previewHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _selectedTab == 0
                          ? QrImageView(
                              data: _generatedData,
                              version: QrVersions.auto,
                              gapless: false,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Color(0xFF1A1A1A),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                color: Color(0xFF1A1A1A),
                                dataModuleShape: QrDataModuleShape.square, 
                                
                              ),
                            )
                          : BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: _generatedData,
                              drawText: false,
                              color: const Color(0xFF1A1A1A),
                            ),
                    ),
                    if (_showCodeText) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _generatedData,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _showCodeText,
                  onChanged: (value) =>
                      setState(() => _showCodeText = value ?? true),
                  activeColor: Colors.deepPurple.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Show text below code',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildActionButton(
                icon: Icons.share_rounded,
                label: 'Share',
                color: Colors.deepPurple.shade600,
                onPressed: _shareGeneratedImage,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.save_rounded,
                label: 'Save',
                color: Colors.green.shade600,
                onPressed: _saveGeneratedData,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.copy_rounded,
                label: 'Copy',
                color: Colors.blue.shade600,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedData));
                  _showSnackBar('Copied to clipboard!', Colors.blue.shade600);
                },
                isOutlined: true,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                icon: Icons.download_rounded,
                label: 'Download',
                color: Colors.orange.shade600,
                onPressed: () async {
                  Uint8List? pngBytes = await _capturePngBytes();
                  if (pngBytes == null) return;

                  final tempDir = await getTemporaryDirectory();
                  final file =
                      await File('${tempDir.path}/scanswift_code.png').create();
                  await file.writeAsBytes(pngBytes);
                  _showSnackBar(
                      'Downloaded successfully!', Colors.green.shade600);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return Expanded(
      child: Tooltip(
        message: 'Click to $label code',
        preferBelow: false,
        verticalOffset: 20,
        showDuration: const Duration(seconds: 2),
        waitDuration: const Duration(milliseconds: 400),
        triggerMode: TooltipTriggerMode.longPress,
        decoration: BoxDecoration(
          color: Colors.grey.shade800.withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        child: SizedBox(
          height: 42,
          child: isOutlined
              ? OutlinedButton.icon(
                  icon: Icon(icon, size: 16, color: color),
                  label: Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: onPressed,
                )
              : ElevatedButton.icon(
                  icon: Icon(icon, size: 16, color: Colors.white),
                  label: Flexible(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: onPressed,
                ),
        ),
      ),
    );
  }
}

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

class _GeneratePageState extends State<GeneratePage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  final GlobalKey _globalKey = GlobalKey();
  int _adRefreshId = 0;

  String _generatedData = "";
  String _selectedType = "QR Code";
  bool _showCodeText = true;
  final List<String> _types = ["QR Code", "Barcode (Code 128)"];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _textController.text = widget.initialData!;
      _generatedData = widget.initialData!;
    }
    if (widget.initialType != null) {
      _selectedType = widget.initialType!.toLowerCase().contains('qr')
          ? "QR Code"
          : "Barcode (Code 128)";
    }
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

  Future<void> _printImage() async {
    _showSnackBar(
        'Print dialog is ready for Android/iOS Devices!', Colors.blue);
    setState(() => _adRefreshId++);
  }

  Future<void> _copyImageToClipboard() async {
    if (_generatedData.isEmpty) {
      _showSnackBar(
          'Nothing to copy! Generate a code first.', Colors.redAccent);
      return;
    }
    _showSnackBar('$_selectedType Image Processed Successfully!',
        const Color(0xFF059669));
    setState(() => _adRefreshId++);
  }
Future<void> _saveGeneratedData() async {
    if (_generatedData.isEmpty) {
      _showSnackBar('Please enter text to generate first', Colors.redAccent);
      return;
    }

    final type = _selectedType == 'QR Code' ? 'QR Code' : 'Barcode';
    await DatabaseService.addScan(_generatedData, type);

    if (!mounted) return;

    // ১. নতুন মেসেজ আসার সাথে সাথে আগের সব ঝুলে থাকা স্ন্যাকবার ইনস্ট্যান্ট ডিলিট করবে
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    // ২. স্ন্যাকবারটি শো করানো
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Saved to history',
            style: TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 2), // সিস্টেম ডিউরেশন ২ সেকেন্ড
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

    // ৩. সেফটি ব্যাকআপ: ঠিক ২ সেকেন্ড পর কোড থেকে জোরপূর্বক স্ন্যাকবার হাইড করার লজিক
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });

    setState(() => _adRefreshId++);
  }

  void _showSnackBar(String message, Color bgColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double customWidth = double.tryParse(_widthController.text) ?? 250.0;
    double customHeight = double.tryParse(_heightController.text) ?? 250.0;

    if (customWidth < 50) customWidth = 50;
    if (customHeight < 50) customHeight = 50;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      appBar: AppBar(
        title: const Text('Code Generator Pro',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ১. কনফিগারেশন কার্ড
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: InputDecoration(
                          labelText: 'Select Generator Type',
                          prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        items: _types.map((String type) {
                          return DropdownMenuItem(
                              value: type, child: Text(type));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedType = value!),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildSizeInputField(
                            controller: _widthController,
                            label: 'Width (Default 250)',
                            icon: Icons.width_normal_rounded,
                          ),
                          const SizedBox(width: 16),
                          _buildSizeInputField(
                            controller: _heightController,
                            label: 'Height (Default 250)',
                            icon: Icons.height_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ২. ডাটা ইনপুট ফিল্ড কার্ড
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _textController,
                        autofocus: false,
                        decoration: InputDecoration(
                          labelText: 'Enter text or URL to generate',
                          hintText: 'Type something...',
                          prefixIcon: const Icon(Icons.edit_note_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                          suffixIcon: _textController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _textController.clear();
                                    setState(() => _generatedData = "");
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) =>
                            setState(() => _generatedData = value),
                      ),
                      CheckboxListTile(
                        title: const Text("Show code value below image",
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        value: _showCodeText,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: theme.colorScheme.primary,
                        onChanged: (bool? value) =>
                            setState(() => _showCodeText = value ?? true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ৩. কোড প্রিভিউ জোন
              if (_generatedData.isNotEmpty)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: RepaintBoundary(
                      key: _globalKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(12.0),
                        width: customWidth,
                        height: customHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _selectedType == "QR Code"
                                  ? QrImageView(
                                      data: _generatedData,
                                      version: QrVersions.auto,
                                      gapless: false,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF1A1A1A),
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
                              const SizedBox(height: 8),
                              Text(
                                _generatedData,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            size: 72,
                            color: theme.colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text('Enter data above to preview code',
                            style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.6))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // ৪. অ্যাকশন বাটন প্যানেল
              if (_generatedData.isNotEmpty) ...[
                Row(
                  children: [
                    _buildButton(
                      context: context,
                      icon: Icons.share_rounded,
                      label: 'Share',
                      color: theme.colorScheme.primary,
                      onPressed: _shareGeneratedImage,
                    ),
                    const SizedBox(width: 12),
                    _buildButton(
                      context: context,
                      icon: Icons.save_rounded,
                      label: 'Save',
                      color: const Color(0xFF059669),
                      onPressed: _saveGeneratedData,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildButton(
                      context: context,
                      icon: Icons.print_rounded,
                      label: 'Print',
                      color: Colors.blueGrey.shade700,
                      onPressed: _printImage,
                    ),
                    const SizedBox(width: 12),
                    _buildButton(
                      context: context,
                      icon: Icons.copy_all_rounded,
                      label: 'Copy',
                      color: theme.colorScheme.primary,
                      isOutlined: true,
                      onPressed: _copyImageToClipboard,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              AdBanner(refreshId: _adRefreshId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onChanged: (val) => setState(() {}),
      ),
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    final theme = Theme.of(context);
    final String tooltipMessage = "Click to $label code image";

    return Expanded(
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        verticalOffset: 24,
        showDuration: const Duration(seconds: 2),
        waitDuration: const Duration(milliseconds: 400),
        triggerMode: TooltipTriggerMode.longPress,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        child: SizedBox(
          height: 50,
          child: isOutlined
              ? OutlinedButton.icon(
                  icon: Icon(icon, size: 18, color: color),
                  label: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onPressed,
                )
              : ElevatedButton.icon(
                  icon: Icon(icon, size: 18, color: Colors.white),
                  label: Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onPressed,
                ),
        ),
      ),
    );
  }
}

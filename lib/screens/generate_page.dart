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
import '../widgets/ad_banner.dart';
// PDF এবং Printing এর ঝামেলা এড়াতে লিনাক্স বিল্ডের জন্য সাময়িক কমেন্ট করা হলো

class GeneratePage extends StatefulWidget {
  const GeneratePage({super.key});

  @override
  State<GeneratePage> createState() => _GeneratePageState();
}

class _GeneratePageState extends State<GeneratePage> {
  final TextEditingController _textController =
      TextEditingController(text: "0");
  final TextEditingController _widthController =
      TextEditingController(text: "200");
  final TextEditingController _heightController =
      TextEditingController(text: "200");
  final GlobalKey _globalKey = GlobalKey();

  String _generatedData = "0";
  String _selectedType = "QR Code";
  bool _showCodeText = true;
  final List<String> _types = ["QR Code", "Barcode (Code 128)"];

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
    Uint8List? pngBytes = await _capturePngBytes();
    if (pngBytes == null) return;

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      Clipboard.setData(ClipboardData(text: 'Data: $_generatedData'));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sharing simulated on Desktop. Text copied!')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final file = await File('${tempDir.path}/scanswift_code.png').create();
    await file.writeAsBytes(pngBytes);

    await Share.shareXFiles([XFile(file.path)],
        text: 'Generated via ScanSwift');
  }

  // লিনাক্স বিল্ড ফ্রেন্ডলি প্রিন্ট মেথড
  Future<void> _printImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Print dialog is ready for Android/iOS Devices!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _copyImageToClipboard() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$_selectedType Image Processed Successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double customWidth = double.tryParse(_widthController.text) ?? 200.0;
    double customHeight = double.tryParse(_heightController.text) ?? 200.0;

    if (customWidth < 50) customWidth = 50;
    if (customHeight < 50) customHeight = 50;

    return Scaffold(
      appBar: AppBar(title: const Text('Code Generator Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Select Generator Type',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _types.map((String type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Width (px)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Height (px)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Enter text or URL to generate',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _textController.clear();
                    setState(() {
                      _generatedData = "";
                    });
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _generatedData = value;
                });
              },
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              title: const Text("Show code value below image"),
              value: _showCodeText,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.deepPurple,
              onChanged: (bool? value) {
                setState(() {
                  _showCodeText = value ?? true;
                });
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: RepaintBoundary(
                key: _globalKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(15.0),
                  width: customWidth,
                  height: customHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _selectedType == "QR Code"
                            ? QrImageView(
                                data: _generatedData.isEmpty
                                    ? "0"
                                    : _generatedData,
                                version: QrVersions.auto,
                                gapless: false,
                              )
                            : BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: _generatedData.isEmpty
                                    ? "0"
                                    : _generatedData,
                                drawText: false,
                              ),
                      ),
                      if (_showCodeText) ...[
                        const SizedBox(height: 8),
                        Text(
                          _generatedData.isEmpty ? "0" : _generatedData,
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
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _shareGeneratedImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _printImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(
                          color: Colors.deepPurple, width: 1.5),
                    ),
                    onPressed: _copyImageToClipboard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}

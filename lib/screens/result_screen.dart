import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'generate_page.dart';
import '../widgets/ad_banner.dart';

class ResultScreen extends StatefulWidget {
  final String codeValue;
  final String codeType;
  final bool fromHistory;

  const ResultScreen({
    super.key,
    required this.codeValue,
    required this.codeType,
    this.fromHistory = false,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _adRefreshId = 0;

  Future<void> _shareContent() async {
    await Share.share(widget.codeValue);
    setState(() => _adRefreshId++);
  }

  Future<void> _openLink(BuildContext context) async {
    final Uri url = Uri.parse(widget.codeValue);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not open in browser (Plain Text).')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isUrl = widget.codeValue.startsWith('http://') ||
        widget.codeValue.startsWith('https://');

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          children: [
                            // Display barcode/QR image
                            SizedBox(
                              width: 260,
                              height: 260,
                              child: Center(
                                child:
                                    widget.codeType.toLowerCase().contains('qr')
                                        ? QrImageView(
                                            data: widget.codeValue,
                                            version: QrVersions.auto)
                                        : BarcodeWidget(
                                            barcode: Barcode.code128(),
                                            data: widget.codeValue,
                                            drawText: false,
                                          ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              widget.codeValue,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Chip(label: Text(widget.codeType.toUpperCase())),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Chip(label: Text(widget.codeType.toUpperCase())),
                            const SizedBox(height: 15),
                            SelectableText(
                              widget.codeValue,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (isUrl)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('Open URL Link'),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () => _openLink(context),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.share),
                            label: const Text('Share Content'),
                            style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15)),
                            onPressed: () => _shareContent(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (widget.fromHistory)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => GeneratePage(
                                        initialData: widget.codeValue,
                                        initialType: widget.codeType),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AdBanner(refreshId: _adRefreshId),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ad_banner.dart';

class ResultScreen extends StatelessWidget {
  final String codeValue;
  final String codeType;

  const ResultScreen(
      {super.key, required this.codeValue, required this.codeType});

  Future<void> _openLink(BuildContext context) async {
    final Uri url = Uri.parse(codeValue);
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
    bool isUrl =
        codeValue.startsWith('http://') || codeValue.startsWith('https://');

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
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Chip(label: Text(codeType.toUpperCase())),
                            const SizedBox(height: 15),
                            SelectableText(
                              codeValue,
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
                    OutlinedButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Share Content'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: () => Share.share(codeValue),
                    ),
                  ],
                ),
              ),
            ),
            const AdBanner(),
          ],
        ),
      ),
    );
  }
}

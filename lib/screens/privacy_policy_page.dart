import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  static const String privacyUrl =
      'https://www.example.com/privacy-policy'; // TODO: replace with real URL

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  bool _launched = false;

  Future<void> _launchPolicy() async {
    final uri = Uri.parse(PrivacyPolicyPage.privacyUrl);
    if (!await launchUrl(uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration())) {
      // fall back to external browser
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void initState() {
    super.initState();
    // Open in-app browser on first push for a professional UX.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_launched) {
        _launched = true;
        await _launchPolicy();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _launchPolicy,
            tooltip: 'Open Privacy Policy',
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.privacy_tip_rounded,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Privacy Policy for Ads',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tap the button below to view the full privacy policy related to advertising and data usage.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.link_rounded),
                label: const Text('View Privacy Policy'),
                onPressed: _launchPolicy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'generate_page.dart';
import '../widgets/ad_banner.dart';
import '../services/ad_service.dart';

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
  final GlobalKey _qrKey = GlobalKey();

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Shows interstitial then pops the screen.
  void _popWithInterstitial() {
    if (_isMobile) {
      AdService.showInterstitialAd(onAdClosed: () {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _shareContent() async {
    if (!mounted) return;
    await AdService.performWithRewardedAdCheck(
      context: context,
      action: AdService.actionShare,
      onAllowed: () async {
        await Share.share(widget.codeValue);
        if (mounted) setState(() => _adRefreshId++);
      },
    );
  }

  Future<void> _copyToClipboard() async {
    if (!mounted) return;
    await AdService.performWithRewardedAdCheck(
      context: context,
      action: AdService.actionCopy,
      onAllowed: () {
        Clipboard.setData(ClipboardData(text: widget.codeValue));
        _showSnackBar('Copied text to clipboard!', const Color(0xFF059669),
            Icons.check_circle_rounded);
      },
    );
  }

  Future<void> _copyQrImage() async {
    try {
      RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/qr_code.png').create();
      await file.writeAsBytes(pngBytes);

      final XFile xFile = XFile(file.path);

      if (!mounted) return;
      await AdService.performWithRewardedAdCheck(
        context: context,
        action: AdService.actionShare,
        onAllowed: () async {
          await Share.shareXFiles([xFile], text: 'My QR/Barcode Image');
          if (mounted) setState(() => _adRefreshId++);
        },
      );
    } catch (e) {
      _showSnackBar('Failed to copy image.', Colors.redAccent,
          Icons.error_outline_rounded);
    }
  }

  void _showSnackBar(String message, Color bgColor, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openLink(BuildContext context) async {
    final Uri url = Uri.parse(widget.codeValue);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Plain Text detected. Opening in browser failed.',
          Colors.redAccent, Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isUrl = widget.codeValue.startsWith('http://') ||
        widget.codeValue.startsWith('https://');
    final isQr = widget.codeType.toLowerCase().contains('qr');
    final theme = Theme.of(context);

    return PopScope(
      // Intercept back button to show interstitial first
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _popWithInterstitial();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        appBar: AppBar(
          title: const Text('Scan Result',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _popWithInterstitial,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // Main Premium Card
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow
                                    .withOpacity(0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                // Code Type Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    widget.codeType.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // QR / Barcode preview with RepaintBoundary
                                RepaintBoundary(
                                  key: _qrKey,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.grey.shade100,
                                          width: 2),
                                    ),
                                    child: SizedBox(
                                      width: 200,
                                      child: Center(
                                        child: isQr
                                            ? QrImageView(
                                                data: widget.codeValue,
                                                version: QrVersions.auto,
                                                eyeStyle: const QrEyeStyle(
                                                  eyeShape:
                                                      QrEyeShape.square,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                              )
                                            : BarcodeWidget(
                                                barcode: Barcode.code128(),
                                                data: widget.codeValue,
                                                width: 200,
                                                height: 80,
                                                drawText: false,
                                                color:
                                                    const Color(0xFF1A1A1A),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Selectable Value Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceVariant
                                        .withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SelectableText(
                                    widget.codeValue,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Row 1: Copy Text & Copy/Share Image
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                icon: Icons.copy_rounded,
                                label: 'Copy Text',
                                onTap: _copyToClipboard,
                                isPrimary: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                context: context,
                                icon: Icons.image_rounded,
                                label: 'Copy Image',
                                onTap: _copyQrImage,
                                isPrimary: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Row 2: Share Content
                        _buildActionButton(
                          context: context,
                          icon: Icons.share_rounded,
                          label: 'Share Content',
                          onTap: _shareContent,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 16),

                        // Primary Actions (Open URL / Edit)
                        if (isUrl) ...[
                          _buildActionButton(
                            context: context,
                            icon: Icons.language_rounded,
                            label: 'Open URL Link',
                            onTap: () => _openLink(context),
                            isPrimary: true,
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (widget.fromHistory)
                          _buildActionButton(
                            context: context,
                            icon: Icons.edit_note_rounded,
                            label: 'Edit Code',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GeneratePage(
                                      initialData: widget.codeValue,
                                      initialType: widget.codeType),
                                ),
                              );
                            },
                            isPrimary: !isUrl,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Banner Ad Placement
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: AdBanner(refreshId: _adRefreshId),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isPrimary
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.8)
                ],
              )
            : null,
      ),
      child: ElevatedButton.icon(
        icon: Icon(icon,
            color: isPrimary ? Colors.white : theme.colorScheme.primary,
            size: 20),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.white : theme.colorScheme.primary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPrimary ? Colors.transparent : theme.colorScheme.surface,
          foregroundColor:
              isPrimary ? Colors.white : theme.colorScheme.primary,
          elevation: isPrimary ? 2 : 0,
          shadowColor: isPrimary
              ? theme.colorScheme.primary.withOpacity(0.3)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(
                    color:
                        theme.colorScheme.outlineVariant.withOpacity(0.6)),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../services/database_service.dart';
import '../widgets/ad_banner.dart';
import 'result_screen.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoStart: false,
  );

  bool _isScanning = true;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String _scanStatus = 'Ready to scan';
  int _scanCount = 0;
  Timer? _scanTimeout;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _fadeAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _recentScans = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeScanner();
    _requestPermissions();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _initializeScanner() async {
    try {
      await cameraController.start();
      if (mounted) {
        setState(() {
          _scanStatus = 'Camera ready';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scanStatus = 'Camera error';
        });
        _showSnackBar('Failed to start camera', Colors.red.shade700);
      }
    }
  }

  Future<void> _requestPermissions() async {
    // Camera permissions are handled by mobile_scanner package
    // This is just a safety check
    try {
      await cameraController.start();
    } catch (e) {
      _showSnackBar('Camera permission required', Colors.orange.shade700);
    }
  }

  @override
  void dispose() {
    cameraController.dispose();
    _audioPlayer.dispose();
    _animationController.dispose();
    _scanTimeout?.cancel();
    super.dispose();
  }

  Future<void> _handleScanSuccess(String value, String type) async {
    if (_isProcessing || !_isScanning) return;

    setState(() {
      _isScanning = false;
      _isProcessing = true;
      _scanStatus = 'Processing...';
    });

    _scanTimeout?.cancel();

    // Play success sound
    await _playSuccessSound();

    // Haptic feedback
    await _triggerHapticFeedback();

    // Save to database
    await DatabaseService.addScan(value, type);

    // Update statistics
    setState(() {
      _scanCount++;
      _scanStatus = 'Scanned successfully!';
      _recentScans.insert(0, value);
      if (_recentScans.length > 5) _recentScans.removeLast();
    });

    // Show success animation
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      _navigateToResult(value, type);
    }
  }

  Future<void> _playSuccessSound() async {
    try {
      // Play a beep sound - using system sound or custom
      await _audioPlayer.play(AssetSource('sounds/scan_success.mp3'));
    } catch (e) {
      // Fallback to system sound if asset not available
      await SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _triggerHapticFeedback() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Vibration.vibrate(duration: 50);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 50);
      } else {
        // Fallback for web/desktop
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Fallback haptic feedback
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _toggleTorch() async {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    await cameraController.toggleTorch();
  }

  Future<void> _switchCamera() async {
    await cameraController.switchCamera();
  }

  void _navigateToResult(String value, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          codeValue: value,
          codeType: type,
          fromHistory: false,
        ),
      ),
    ).then((_) {
      setState(() {
        _isScanning = true;
        _scanStatus = 'Ready to scan';
      });
    });
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Scanner View
                Container(
                  color: Colors.black,
                  child: MobileScanner(
                    controller: cameraController,
                    onDetect: (capture) async {
                      if (!_isScanning || _isProcessing) return;

                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty &&
                          barcodes.first.rawValue != null) {
                        final String rawValue = barcodes.first.rawValue!;
                        final String type = barcodes.first.format.name;
                        await _handleScanSuccess(rawValue, type);
                      }
                    },
                  ),
                ),

                // Scanner Overlay
                _buildScannerOverlay(),

                // Scan Status
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: _buildScanStatus(),
                ),
              ],
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
      foregroundColor: Colors.white,
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
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'ScanSwift Scanner',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      centerTitle: false,
      // backgroundColor: Colors.transparent,
      actions: [
        // Torch Button
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.yellow.shade400 : Colors.white,
              size: 20,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Toggle Torch',
            padding: const EdgeInsets.all(8),
          ),
        ),
        // Switch Camera Button
        Container(
          margin: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.cameraswitch_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _switchCamera,
            tooltip: 'Switch Camera',
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.8),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Corner markers
                        _buildCornerMarker(Alignment.topLeft, -1, -1),
                        _buildCornerMarker(Alignment.topRight, 1, -1),
                        _buildCornerMarker(Alignment.bottomLeft, -1, 1),
                        _buildCornerMarker(Alignment.bottomRight, 1, 1),

                        // Scan line animation
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _scanLineAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: _scanLineAnimation.value * 260 + 10,
                                left: 20,
                                right: 20,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.deepPurple.shade300,
                                        Colors.deepPurple.shade600,
                                        Colors.deepPurple.shade300,
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple
                                              .withOpacity(0.6),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Place QR code within the frame',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerMarker(Alignment alignment, double x, double y) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        child: CustomPaint(
          painter: CornerMarkerPainter(x: x, y: y),
          size: const Size(30, 30),
        ),
      ),
    );
  }

  Widget _buildScanStatus() {
    final statusContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isProcessing
              ? Colors.deepPurple.shade400
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.shade400,
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isProcessing
                  ? Colors.deepPurple.shade400
                  : _isScanning
                      ? Colors.green.shade400
                      : Colors.red.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _scanStatus,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          if (_isProcessing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );

    return statusContent;
  }
}

// Custom painter for corner markers
class CornerMarkerPainter extends CustomPainter {
  final double x;
  final double y;

  CornerMarkerPainter({required this.x, required this.y});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Top-left corner
    if (x == -1 && y == -1) {
      path.moveTo(0, 12);
      path.lineTo(0, 0);
      path.lineTo(12, 0);
    }
    // Top-right corner
    else if (x == 1 && y == -1) {
      path.moveTo(size.width - 12, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, 12);
    }
    // Bottom-left corner
    else if (x == -1 && y == 1) {
      path.moveTo(0, size.height - 12);
      path.lineTo(0, size.height);
      path.lineTo(12, size.height);
    }
    // Bottom-right corner
    else if (x == 1 && y == 1) {
      path.moveTo(size.width - 12, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - 12);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CornerMarkerPainter oldDelegate) {
    return oldDelegate.x != x || oldDelegate.y != y;
  }
}

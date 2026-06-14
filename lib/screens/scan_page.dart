import 'package:flutter/foundation.dart'; // kIsWeb ব্যবহারের জন্য
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform; // ওএস প্ল্যাটফর্ম চেক করার জন্য
import 'dart:async';
import '../services/database_service.dart';
import '../services/ad_service.dart';
import '../widgets/ad_banner.dart';
import 'result_screen.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isScanning = true;
  Timer? _scanTimeout;

  @override
  void initState() {
    super.initState();
    // AdService already initialized in main for supported platforms.
    // Start the camera immediately for fastest possible first-detection.
    cameraController.start().catchError((_) {});
    // Safety: ensure we don't stay waiting forever — prefer quick response.
    _scanTimeout = Timer(const Duration(seconds: 1), () {
      // If still scanning after 1s, keep the camera running but allow UI to
      // remain responsive. We don't force navigation here because we need
      // a valid barcode value to navigate.
      if (mounted && _isScanning) {
        // No-op for now; keeping timer to mark intention for 1s quick-scan.
      }
    });
  }

  @override
  void dispose() {
    cameraController.dispose(); // মেমোরি লিক রোধ করতে ডিসপোজ
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScanSwift Scanner'),
        actions: [
          // মোবাইল স্ক্যানার v5.x এর লেটেস্ট ভ্যালু লিসেনাবল টর্চ মেকানিজম
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: cameraController,
            builder: (context, state, child) {
              final TorchState torchState = state.torchState;
              return IconButton(
                icon: Icon(
                  torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color:
                      torchState == TorchState.on ? Colors.yellow : Colors.grey,
                ),
                onPressed: () => cameraController.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_rear),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // মূল কিউআর/বারকোড ক্যামেরা স্ক্যানার ভিউ
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) async {
                    if (!_isScanning) return; // একবার স্ক্যান হলে লক করে দেবে

                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty &&
                        barcodes.first.rawValue != null) {
                      setState(() {
                        _isScanning = false;
                      });

                      // Cancel any outstanding timeout once we get a code.
                      _scanTimeout?.cancel();

                      final String rawValue = barcodes.first.rawValue!;
                      final String type = barcodes.first.format.name;

                      // লোকাল ডাটাবেসে স্ক্যান হিস্ট্রি সেভ
                      await DatabaseService.addScan(rawValue, type);

                      // For fastest user experience, navigate immediately to the
                      // result page on first detection (quick-scan flow).
                      _navigateToResult(rawValue, type);
                    }
                  },
                ),
                // ক্যামেরার উপর একটি সুন্দর প্রফেশনাল স্ক্যানার গাইডলাইন বক্স ওভারলে
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepPurple, width: 4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reusable banner widget (no-ops on unsupported platforms)
          const AdBanner(),
        ],
      ),
    );
  }

  // রেজাল্ট স্ক্রিনে যাওয়ার এবং ব্যাক আসার পর পুনরায় স্ক্যানার চালু করার মেথড
  void _navigateToResult(String value, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(codeValue: value, codeType: type),
      ),
    ).then((_) {
      // রেজাল্ট পেজ থেকে ব্যাক বাটনে চাপ দিলে স্ক্যানার আবার সচল হবে
      setState(() {
        _isScanning = true;
      });
    });
  }
}

import 'package:flutter/foundation.dart'; // kIsWeb ব্যবহারের জন্য
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform; // ওএস প্ল্যাটফর্ম চেক করার জন্য
import '../services/database_service.dart';
import '../services/ad_service.dart';
import 'result_screen.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController cameraController = MobileScannerController();
  BannerAd? _bannerAd;
  bool _isScanning = true;
  bool _isAdSupported = false;

  @override
  void initState() {
    super.initState();

    // AdMob শুধুমাত্র Android এবং iOS সাপোর্ট করে।
    // লিনাক্স ডেস্কটপে রান করলে যেন ক্র্যাশ না করে তাই এই চেকগার্ড।
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isAdSupported = true;
      _bannerAd = AdService.createBannerAd();
    }
  }

  @override
  void dispose() {
    cameraController.dispose(); // মেমোরি লিক রোধ করতে ডিসপোজ
    _bannerAd?.dispose();
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

                      final String rawValue = barcodes.first.rawValue!;
                      final String type = barcodes.first.format.name;

                      // লোকাল ডাটাবেসে স্ক্যান হিস্ট্রি সেভ
                      await DatabaseService.addScan(rawValue, type);

                      // অ্যান্ড্রোয়েড হলে ইন্টারস্টিশিয়াল অ্যাড দেখাবে, লিনাক্স হলে সরাসরি নেভিগেট করবে
                      if (_isAdSupported) {
                        AdService.showInterstitialAd(() {
                          _navigateToResult(rawValue, type);
                        });
                      } else {
                        _navigateToResult(rawValue, type);
                      }
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
          // ব্যানার অ্যাড সেকশন (শুধুমাত্র মোবাইল ডিভাইসের জন্য দৃশ্যমান হবে)
          if (_isAdSupported && _bannerAd != null)
            Container(
              alignment: Alignment.center,
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
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

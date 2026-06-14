import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// Reusable banner ad widget. Safely no-ops on unsupported platforms (web/desktop).
class AdBanner extends StatefulWidget {
  final Object? refreshId;

  const AdBanner({super.key, this.refreshId});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isAdSupported = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _isAdSupported = true;
      _bannerAd = AdService.createBannerAd();
    }
  }

  @override
  void didUpdateWidget(covariant AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent signals a refresh by changing `refreshId`, recreate the ad.
    if (widget.refreshId != oldWidget.refreshId && _isAdSupported) {
      _bannerAd?.dispose();
      _bannerAd = AdService.createBannerAd();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdSupported || _bannerAd == null) return const SizedBox.shrink();

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

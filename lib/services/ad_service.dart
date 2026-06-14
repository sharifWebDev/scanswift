import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';

class AdService {
  static bool _isInitialized = false;

  // এগুলো গুগল প্লে-স্টোরের রিয়েল আইডি দেওয়ার জন্য রেডি করা টেস্ট আইডি
  static String get bannerAdUnitId => 'ca-app-pub-3940256099942544/6300978111';
  static String get interstitialAdUnitId =>
      'ca-app-pub-3940256099942544/1033173712';

  static Future<void> init() async {
    if (!_isInitialized) {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
  }

  static BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  static void showInterstitialAd(VoidCallback onAdClosed) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              onAdClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              onAdClosed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          onAdClosed();
        },
      ),
    );
  }
}

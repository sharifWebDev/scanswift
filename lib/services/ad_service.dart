import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

class AdService {
  static bool _isInitialized = false;

  // এগুলো গুগল প্লে-স্টোরের রিয়েল আইডি দেওয়ার জন্য রেডি করা টেস্ট আইডি
  static String get bannerAdUnitId => 'ca-app-pub-3940256099942544/6300978111';
  static String get interstitialAdUnitId =>
      'ca-app-pub-3940256099942544/1033173712';
  // Rewarded test id
  static String get rewardedAdUnitId =>
      'ca-app-pub-3940256099942544/5224354917';

  // In production replace these getters with config-backed real IDs.
  // Optionally return test ids when in debug mode.
  static String _useBannerId(String id) =>
      kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : id;
  static String _useInterstitialId(String id) =>
      kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : id;
  static String _useRewardedId(String id) =>
      kDebugMode ? 'ca-app-pub-3940256099942544/5224354917' : id;

  static Future<void> init() async {
    if (!_isInitialized) {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
  }

  static BannerAd createBannerAd(
      {VoidCallback? onAdLoaded, VoidCallback? onAdFailedToLoad}) {
    return BannerAd(
      adUnitId: _useBannerId(bannerAdUnitId),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          try {
            onAdLoaded?.call();
          } catch (_) {}
        },
        onAdFailedToLoad: (ad, error) {
          try {
            onAdFailedToLoad?.call();
          } catch (_) {}
          // Dispose failed ad to avoid leaks
          ad.dispose();
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {
          ad.dispose();
        },
      ),
    )..load();
  }

  // Simple interstitial helper that preloads and shows. Keeps one cached interstitial.
  static InterstitialAd? _interstitial;

  static void preloadInterstitial() {
    if (_interstitial != null) return;
    InterstitialAd.load(
      adUnitId: _useInterstitialId(interstitialAdUnitId),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitial?.setImmersiveMode(true);
          _interstitial?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitial = null;
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
        },
      ),
    );
  }

  static void showInterstitialAd(VoidCallback onAdClosed) {
    if (_interstitial != null) {
      _interstitial?.show();
      // onAdClosed will be called from FullScreenContentCallback when dismissed
      // Provide a fallback in case ad fails to show
      Future.delayed(const Duration(seconds: 5), onAdClosed);
    } else {
      // Load and show immediately if nothing is cached
      InterstitialAd.load(
        adUnitId: _useInterstitialId(interstitialAdUnitId),
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

  // Rewarded Ad helper
  static RewardedAd? _rewardedAd;

  static void preloadRewardedAd() {
    if (_rewardedAd != null) return;
    RewardedAd.load(
      adUnitId: _useRewardedId(rewardedAdUnitId),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
            },
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  static void showRewardedAd(
      {required VoidCallback onUserEarnedReward,
      required VoidCallback onAdClosed}) {
    if (_rewardedAd != null) {
      _rewardedAd?.show(onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      });
      Future.delayed(const Duration(seconds: 5), onAdClosed);
    } else {
      RewardedAd.load(
        adUnitId: _useRewardedId(rewardedAdUnitId),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
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
            ad.show(onUserEarnedReward: (ad, reward) {
              onUserEarnedReward();
            });
          },
          onAdFailedToLoad: (error) {
            onAdClosed();
          },
        ),
      );
    }
  }
}

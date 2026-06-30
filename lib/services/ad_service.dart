import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central AdMob service. Handles Banner, Interstitial and Rewarded ads.
/// Also tracks daily usage counts for the Rewarded ad gates.
class AdService {
  AdService._();

  static bool _isInitialized = false;

  // ─── Ad Unit IDs ────────────────────────────────────────────────────────────
  // In debug mode we always use Google's official test IDs.
  // In production replace the _prod* constants with your real AdMob unit IDs.
  static const String _prodBannerId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodInterstitialId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _prodRewardedId =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  static const String _testBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerId : _prodBannerId;
  static String get interstitialAdUnitId =>
      kDebugMode ? _testInterstitialId : _prodInterstitialId;
  static String get rewardedAdUnitId =>
      kDebugMode ? _testRewardedId : _prodRewardedId;

  // ─── Daily usage limit keys ─────────────────────────────────────────────────
  static const String _keyDatePrefix = 'ad_limit_date_';
  static const String _keyCountPrefix = 'ad_limit_count_';

  // Action names used as keys
  static const String actionGenerate = 'generate';
  static const String actionCopy = 'copy';
  static const String actionShare = 'share';
  static const String actionScan = 'scan';

  // Daily limits per action
  static const int limitGenerate = 20;
  static const int limitCopy = 20;
  static const int limitShare = 5;
  static const int limitScan = 100;

  static int _limitFor(String action) {
    switch (action) {
      case actionGenerate:
        return limitGenerate;
      case actionCopy:
        return limitCopy;
      case actionShare:
        return limitShare;
      case actionScan:
        return limitScan;
      default:
        return 9999;
    }
  }

  // ─── SDK Init ────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (!_isInitialized) {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    }
  }

  // ─── Daily Count Helpers ────────────────────────────────────────────────────

  /// Returns today's date string in yyyy-MM-dd format.
  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the current daily count for [action] (resets if a new day).
  static Future<int> getDailyCount(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '$_keyDatePrefix$action';
    final countKey = '$_keyCountPrefix$action';
    final savedDate = prefs.getString(dateKey) ?? '';
    if (savedDate != _today()) {
      // New day → reset
      await prefs.setString(dateKey, _today());
      await prefs.setInt(countKey, 0);
      return 0;
    }
    return prefs.getInt(countKey) ?? 0;
  }

  /// Increments the daily count for [action] and returns the new value.
  static Future<int> incrementDailyCount(String action) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = '$_keyDatePrefix$action';
    final countKey = '$_keyCountPrefix$action';
    // Ensure date is set for today
    if ((prefs.getString(dateKey) ?? '') != _today()) {
      await prefs.setString(dateKey, _today());
      await prefs.setInt(countKey, 0);
    }
    final current = prefs.getInt(countKey) ?? 0;
    final newVal = current + 1;
    await prefs.setInt(countKey, newVal);
    return newVal;
  }

  /// Returns true if the user has exceeded the daily limit for [action].
  static Future<bool> isLimitExceeded(String action) async {
    final count = await getDailyCount(action);
    return count >= _limitFor(action);
  }

  /// Checks if [action] limit is exceeded.
  /// - If NOT exceeded: increments count and calls [onAllowed] immediately.
  /// - If exceeded: shows a consent dialog. If user agrees, shows rewarded ad.
  ///   On reward earned + ad closed: increments count and calls [onAllowed].
  ///   On cancel or ad failure: calls [onAllowed] is NOT called; user sees nothing.
  static Future<void> performWithRewardedAdCheck({
    required BuildContext context,
    required String action,
    required VoidCallback onAllowed,
    String? customDialogTitle,
    String? customDialogMessage,
  }) async {
    final exceeded = await isLimitExceeded(action);
    if (!exceeded) {
      await incrementDailyCount(action);
      onAllowed();
      return;
    }

    // Limit exceeded → show consent dialog
    if (!context.mounted) return;
    final agreed = await _showRewardedConsentDialog(
      context,
      action: action,
      title: customDialogTitle,
      message: customDialogMessage,
    );
    if (!agreed || !context.mounted) return;

    bool rewardEarned = false;
    showRewardedAd(
      onUserEarnedReward: () => rewardEarned = true,
      onAdClosed: () async {
        if (rewardEarned) {
          await incrementDailyCount(action);
          onAllowed();
        }
      },
    );
  }

  // ─── Consent Dialog ─────────────────────────────────────────────────────────
  static Future<bool> _showRewardedConsentDialog(
    BuildContext context, {
    required String action,
    String? title,
    String? message,
  }) async {
    final limitMap = {
      actionGenerate: limitGenerate,
      actionCopy: limitCopy,
      actionShare: limitShare,
      actionScan: limitScan,
    };
    final limit = limitMap[action] ?? 0;
    final actionLabel = {
      actionGenerate: 'generate codes',
      actionCopy: 'copy',
      actionShare: 'share',
      actionScan: 'scan',
    }[action] ?? action;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.video_library_rounded,
                  color: Colors.amber.shade700, size: 28),
            ),
            title: Text(
              title ?? 'Daily Limit Reached',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            ),
            content: Text(
              message ??
                  'You\'ve used your free daily allowance of $limit $actionLabel.\n\nWatch a short video ad to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: Colors.grey.shade700, height: 1.5),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 18),
                label: const Text('Watch Ad',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─── Banner Ad ──────────────────────────────────────────────────────────────
  static BannerAd createBannerAd(
      {VoidCallback? onAdLoaded, VoidCallback? onAdFailedToLoad}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
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
          ad.dispose();
        },
        onAdOpened: (ad) {},
        onAdClosed: (ad) {
          ad.dispose();
        },
      ),
    )..load();
  }

  // ─── Interstitial Ad ────────────────────────────────────────────────────────
  static InterstitialAd? _interstitial;
  static bool _interstitialLoading = false;

  static void preloadInterstitial() {
    if (_interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialLoading = false;
          _interstitial!.setImmersiveMode(true);
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _interstitialLoading = false;
        },
      ),
    );
  }

  /// Shows interstitial if cached; otherwise loads+shows on demand.
  /// [onAdClosed] is guaranteed to be called once (either after dismiss or on failure).
  static void showInterstitialAd({VoidCallback? onAdClosed}) {
    void _showAd(InterstitialAd ad) {
      bool _called = false;
      void safeClose() {
        if (!_called) {
          _called = true;
          onAdClosed?.call();
          preloadInterstitial(); // pre-cache next ad
        }
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          _interstitial = null;
          safeClose();
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          a.dispose();
          _interstitial = null;
          safeClose();
        },
      );
      ad.show();
    }

    if (_interstitial != null) {
      final ad = _interstitial!;
      _interstitial = null;
      _showAd(ad);
    } else {
      _interstitialLoading = true;
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialLoading = false;
            _showAd(ad);
          },
          onAdFailedToLoad: (error) {
            _interstitialLoading = false;
            onAdClosed?.call();
          },
        ),
      );
    }
  }

  // ─── Rewarded Ad ────────────────────────────────────────────────────────────
  static RewardedAd? _rewardedAd;
  static bool _rewardedLoading = false;

  static void preloadRewardedAd() {
    if (_rewardedAd != null || _rewardedLoading) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _rewardedLoading = false;
        },
      ),
    );
  }

  static void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    required VoidCallback onAdClosed,
  }) {
    void _showAd(RewardedAd ad) {
      bool _called = false;
      void safeClose() {
        if (!_called) {
          _called = true;
          onAdClosed();
          preloadRewardedAd(); // pre-cache next ad
        }
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          _rewardedAd = null;
          safeClose();
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          a.dispose();
          _rewardedAd = null;
          safeClose();
        },
      );
      ad.show(onUserEarnedReward: (a, reward) => onUserEarnedReward());
    }

    if (_rewardedAd != null) {
      final ad = _rewardedAd!;
      _rewardedAd = null;
      _showAd(ad);
    } else {
      _rewardedLoading = true;
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedLoading = false;
            _showAd(ad);
          },
          onAdFailedToLoad: (error) {
            _rewardedLoading = false;
            onAdClosed();
          },
        ),
      );
    }
  }
}

import 'dart:io' show Platform; // প্ল্যাটফর্ম চেক করার জন্য
import 'package:flutter/foundation.dart' show kIsWeb; // ওয়েব চেক করার জন্য
import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'services/ad_service.dart';
import 'screens/home_screen.dart';

void main() async {
  // ফ্লাটার ইঞ্জিন এবং নেটিভ চ্যানেলের মধ্যে যোগাযোগ নিশ্চিত করার জন্য
  WidgetsFlutterBinding.ensureInitialized();

  // লোকাল ডাটাবেস (Hive) ইনিশিয়ালাইজেশন (সব প্ল্যাটফর্মেই কাজ করবে)
  await DatabaseService.init();

  // প্ল্যাটফর্ম গার্ড: অ্যাডমোব শুধুমাত্র মোবাইল (Android/iOS) সাপোর্ট করে।
  // লিনাক্স ডেস্কটপ বা ওয়েবে যেন MissingPluginException না আসে, তাই এই চেক।
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await AdService.init();
    // Preload full-screen ads for a smoother user experience
    AdService.preloadInterstitial();
    AdService.preloadRewardedAd();
  }

  runApp(const ScanSwiftApp());
}

class ScanSwiftApp extends StatelessWidget {
  const ScanSwiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanSwift',
      debugShowCheckedModeBanner: false,

      // লাইট থিম (Material 3 ভিত্তিক প্রফেশনাল পার্পল কালার স্কিম)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),

      // ডার্ক থিম (সিস্টেম ডার্ক মোড অন থাকলে স্বয়ংক্রিয়ভাবে একটিভ হবে)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),

      home: const HomeScreen(),
    );
  }
}

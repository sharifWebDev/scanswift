import 'package:flutter/material.dart';
import 'scan_page.dart';
import 'history_page.dart';
import 'generate_page.dart';
import '../widgets/ad_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  // Changing this value forces the AdBanner to refresh its ad.
  int _adRefreshId = 0;

  final List<Widget> _pages = [
    const ScanPage(),
    const HistoryPage(),
    const GeneratePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          AdBanner(refreshId: _adRefreshId),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
            // Refresh banner when user switches tabs (keeps ad activity reasonable)
            _adRefreshId++;
          });
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.create), label: 'Generate'),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';
import 'result_screen.dart';
import '../widgets/ad_banner.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  // মডার্ন মেটেরিয়াল ৩ ডিলিট康ফার্মেশন ডায়ালগ
  Future<bool> _showConfirmDialog(BuildContext context,
      {required String title, required String content}) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            icon: Icon(Icons.delete_forever_rounded,
                color: theme.colorScheme.error, size: 32),
            title: Text(
              title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            content: Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            actionsAlignment: MainAxisAlignment.spaceEvenly,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delete',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyBox = DatabaseService.getHistoryBox();

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.2),
      appBar: AppBar(
        title: const Text('Scan History',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          ValueListenableBuilder(
            valueListenable: historyBox.listenable(),
            builder: (context, Box<ScanModel> box, _) {
              if (box.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(Icons.delete_sweep_rounded,
                    color: theme.colorScheme.error, size: 26),
                tooltip: 'Clear All History',
                onPressed: () async {
                  bool confirm = await _showConfirmDialog(
                    context,
                    title: 'Clear All History?',
                    content:
                        'Are you sure you want to permanently delete all scan history?',
                  );
                  if (confirm) {
                    await historyBox.clear();
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: historyBox.listenable(),
              builder: (context, Box<ScanModel> box, _) {
                if (box.values.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withOpacity(0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.history_toggle_off_rounded,
                              size: 64, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'History is clean and empty!',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                final keysList = box.keys.toList().reversed.toList();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: keysList.length,
                  itemBuilder: (context, index) {
                    final dynamic currentKey = keysList[index];
                    final scan = box.get(currentKey);

                    if (scan == null) return const SizedBox.shrink();

                    final formattedDate = DateFormat('dd MMM yyyy • hh:mm a')
                        .format(scan.scanTime);
                    final isUrl = scan.codeValue.startsWith('http');
                    final isQr = scan.codeType.toLowerCase().contains('qr');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        // এখানে ভুলটি ফিক্স করা হয়েছে: BorderSide বদলে Border.all ব্যবহার করা হয়েছে
                        border: Border.all(
                          color:
                              theme.colorScheme.outlineVariant.withOpacity(0.4),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ResultScreen(
                                  codeValue: scan.codeValue,
                                  codeType: scan.codeType,
                                  fromHistory: true,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                // ১. লিডিং আইকন স্টাইল
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isUrl
                                        ? Colors.blue.withOpacity(0.1)
                                        : theme.colorScheme.primaryContainer
                                            .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    isUrl
                                        ? Icons.language_rounded
                                        : (isQr
                                            ? Icons.qr_code_2_rounded
                                            : Icons.barcode_reader),
                                    color: isUrl
                                        ? Colors.blue.shade800
                                        : theme.colorScheme.primary,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // ২. ডাটা এবং টেক্সট কন্টেন্ট জোন
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        scan.codeValue,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme.onSurfaceVariant
                                              .withOpacity(0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      // কোড টাইপ ব্যাজ
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colorScheme.surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          scan.codeType.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ৩. ট্রেইলিং ডিলিট বাটন
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: theme.colorScheme.error
                                          .withOpacity(0.8)),
                                  tooltip: 'Delete Item',
                                  onPressed: () async {
                                    bool confirm = await _showConfirmDialog(
                                      context,
                                      title: 'Delete Scan?',
                                      content:
                                          'Are you sure you want to remove this record from history?',
                                    );
                                    if (confirm) {
                                      await box.delete(currentKey);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          AdBanner(),
        ],
      ),
    );
  }
}

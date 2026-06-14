import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/scan_model.dart';
import 'result_screen.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
              DatabaseService.getHistoryBox().clear();
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: DatabaseService.getHistoryBox().listenable(),
        builder: (context, Box<ScanModel> box, _) {
          if (box.values.isEmpty) {
            return const Center(child: Text('History is clean and empty!'));
          }

          final historyList = box.values.toList().reversed.toList();

          return ListView.builder(
            itemCount: historyList.length,
            itemBuilder: (context, index) {
              final scan = historyList[index];
              final formattedDate =
                  DateFormat('dd MMM yyyy, hh:mm a').format(scan.scanTime);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    scan.codeValue.startsWith('http')
                        ? Icons.link
                        : Icons.text_fields,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(scan.codeValue,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$formattedDate • ${scan.codeType}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(
                          codeValue: scan.codeValue, codeType: scan.codeType),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

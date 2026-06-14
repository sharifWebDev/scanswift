import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan_model.dart';

class DatabaseService {
  static const String _boxName = 'scan_history';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(ScanModelAdapter());
    await Hive.openBox<ScanModel>(_boxName);
  }

  static Box<ScanModel> getHistoryBox() {
    return Hive.box<ScanModel>(_boxName);
  }

  static Future<void> addScan(String value, String type) async {
    final box = getHistoryBox();
    final newScan = ScanModel(
      codeValue: value,
      codeType: type,
      scanTime: DateTime.now(),
    );
    await box.add(newScan);
  }
}

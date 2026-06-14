import 'package:hive/hive.dart';

part 'scan_model.g.dart';

@HiveType(typeId: 0)
class ScanModel extends HiveObject {
  @HiveField(0)
  final String codeValue;

  @HiveField(1)
  final String codeType;

  @HiveField(2)
  final DateTime scanTime;

  ScanModel({
    required this.codeValue,
    required this.codeType,
    required this.scanTime,
  });
}

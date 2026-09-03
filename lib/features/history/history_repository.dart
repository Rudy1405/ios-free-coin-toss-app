import 'package:hive/hive.dart';

class FlipRecord {
  const FlipRecord({required this.result, required this.timestamp});

  final String result;
  final DateTime timestamp;

  String encode() => '${timestamp.millisecondsSinceEpoch}|$result';

  static FlipRecord decode(String raw) {
    final parts = raw.split('|');
    return FlipRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
      result: parts[1],
    );
  }
}

class HistoryRepository {
  static const _boxName = 'flip_history';
  static const _maxEntries = 5;

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> saveFlip(String result) async {
    final record = FlipRecord(result: result, timestamp: DateTime.now());
    await _box.add(record.encode());

    while (_box.length > _maxEntries) {
      await _box.deleteAt(0);
    }
  }

  List<FlipRecord> getLastFive() {
    return _box.values.map(FlipRecord.decode).toList().reversed.toList();
  }
}

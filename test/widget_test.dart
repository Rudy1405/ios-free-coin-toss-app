import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cara_o_cruz/features/coin/coin_screen.dart';
import 'package:cara_o_cruz/features/history/history_provider.dart';
import 'package:cara_o_cruz/features/history/history_repository.dart';

class FakeHistoryRepository extends HistoryRepository {
  final List<String> _entries = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> saveFlip(String result) async {
    _entries.add('${DateTime.now().millisecondsSinceEpoch}|$result');
    if (_entries.length > 5) _entries.removeAt(0);
  }

  @override
  List<FlipRecord> getLastFive() {
    return _entries.map(FlipRecord.decode).toList().reversed.toList();
  }
}

void main() {
  testWidgets('CoinScreen builds without errors', (WidgetTester tester) async {
    final fakeRepo = FakeHistoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const CupertinoApp(home: CoinScreen()),
      ),
    );

    expect(find.byType(CoinScreen), findsOneWidget);
  });
}

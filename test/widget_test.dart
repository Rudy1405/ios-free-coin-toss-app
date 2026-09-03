import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cara_o_cruz/features/coin/coin_screen.dart';
import 'package:cara_o_cruz/features/history/history_provider.dart';
import 'package:cara_o_cruz/features/history/history_repository.dart';
import 'package:cara_o_cruz/l10n/app_localizations.dart';

class FakeHistoryRepository extends HistoryRepository {
  FakeHistoryRepository({List<String> seed = const []})
      : _entries = List.of(seed);

  final List<String> _entries;

  @override
  Future<void> init() async {}

  @override
  Future<void> saveFlip(String result) async {
    _entries.add('${DateTime.now().millisecondsSinceEpoch}|$result');
    if (_entries.length > 10) _entries.removeAt(0);
  }

  @override
  List<FlipRecord> getRecentFlips() {
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
        child: const CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CoinScreen(),
        ),
      ),
    );

    expect(find.byType(CoinScreen), findsOneWidget);
  });

  testWidgets(
    'history row holds all 10 entries and scrolls horizontally',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final seed = List.generate(10, (i) {
        final result = i.isEven ? 'cara' : 'cruz';
        final timestamp = now.subtract(Duration(minutes: i));
        return '${timestamp.millisecondsSinceEpoch}|$result';
      });
      final fakeRepo = FakeHistoryRepository(seed: seed);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const CupertinoApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CoinScreen(),
          ),
        ),
      );

      final scrollFinder = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(scrollFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dragging shouldn't throw or overflow now that there are 10 chips.
      await tester.drag(scrollFinder, const Offset(-200, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

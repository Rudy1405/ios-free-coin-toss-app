import 'package:flutter_test/flutter_test.dart';
import 'package:cara_o_cruz/features/coin/coin_rng_service.dart';
import 'package:cara_o_cruz/features/coin/coin_state.dart';

void main() {
  group('CoinRngService', () {
    late CoinRngService service;

    setUp(() {
      service = CoinRngService();
    });

    test('distribution: 1000 flips land between 40-60% for each side', () {
      var caraCount = 0;
      for (var i = 0; i < 1000; i++) {
        if (service.flip() == FlipResult.cara) caraCount++;
      }
      final caraPercent = caraCount / 1000;
      expect(caraPercent, greaterThanOrEqualTo(0.40));
      expect(caraPercent, lessThanOrEqualTo(0.60));
    });

    test('getInitialFace returns a valid FlipResult', () {
      final face = service.getInitialFace();
      expect(face, isA<FlipResult>());
      expect(FlipResult.values.contains(face), isTrue);
    });

    test(
      'getInitialFace distribution: 1000 calls land between 40-60% for each side',
      () {
        var caraCount = 0;
        for (var i = 0; i < 1000; i++) {
          if (service.getInitialFace() == FlipResult.cara) caraCount++;
        }
        final caraPercent = caraCount / 1000;
        expect(caraPercent, greaterThanOrEqualTo(0.40));
        expect(caraPercent, lessThanOrEqualTo(0.60));
      },
    );
  });

  group('CoinStateNotifier', () {
    test('stores result before animation callback fires', () {
      final notifier = CoinStateNotifier();

      expect(notifier.state.status, CoinStatus.idle);
      expect(notifier.pendingResult, isNull);

      notifier.startFlip();

      // Result is determined immediately on startFlip, before resolveFlip
      expect(notifier.state.status, CoinStatus.flipping);
      expect(notifier.pendingResult, isNotNull);
      expect(
        FlipResult.values.contains(notifier.pendingResult),
        isTrue,
      );

      // Simulate animation completion
      final determined = notifier.pendingResult;
      notifier.resolveFlip();

      expect(notifier.state.status, CoinStatus.result);
      expect(notifier.state.lastResult, determined);
      expect(notifier.pendingResult, isNull);
    });
  });
}

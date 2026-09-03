import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:cara_o_cruz/features/coin/coin_animation_controller.dart';

void main() {
  group('CoinAnimationController', () {
    test('lands on the frame matching the already-fixed result', () async {
      final controller = CoinAnimationController(
        framePaths: List.generate(4, (i) => 'frame_$i'),
        frameDuration: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);
      final completer = Completer<CoinFace>();
      controller.onComplete = completer.complete;

      controller.play(CoinFace.cruz, fullRotations: 1);

      final result = await completer.future.timeout(const Duration(seconds: 3));
      expect(result, CoinFace.cruz);
      expect(controller.currentFrameIndex, 2); // midpoint of 4 frames = cruz
    });

    test('extendSpin is a no-op while idle', () {
      final controller = CoinAnimationController(framePaths: ['a', 'b']);
      addTearDown(controller.dispose);
      expect(controller.extendSpin(), isFalse);
    });

    test('extendSpin is capped at maxBonusRotations', () {
      final controller = CoinAnimationController(
        framePaths: List.generate(2, (i) => 'frame_$i'),
        frameDuration: const Duration(milliseconds: 5),
      );
      addTearDown(controller.dispose);
      controller.play(CoinFace.cara, fullRotations: 1);

      // Runs synchronously, before any timer tick can fire, so this counts
      // purely how many extensions the cap allows.
      var acceptedCount = 0;
      for (var i = 0; i < CoinAnimationController.maxBonusRotations + 3; i++) {
        if (controller.extendSpin()) acceptedCount++;
      }
      expect(acceptedCount, CoinAnimationController.maxBonusRotations);
    });

    test(
      'extendSpin measurably delays completion without changing the result',
      () async {
        Future<Duration> timeToComplete({required bool extend}) async {
          final controller = CoinAnimationController(
            framePaths: List.generate(6, (i) => 'frame_$i'),
            frameDuration: const Duration(milliseconds: 5),
          );
          final completer = Completer<CoinFace>();
          controller.onComplete = completer.complete;
          final stopwatch = Stopwatch()..start();

          controller.play(CoinFace.cara, fullRotations: 1);
          if (extend) controller.extendSpin();

          final result =
              await completer.future.timeout(const Duration(seconds: 3));
          stopwatch.stop();
          expect(result, CoinFace.cara);
          controller.dispose();
          return stopwatch.elapsed;
        }

        final base = await timeToComplete(extend: false);
        final extended = await timeToComplete(extend: true);

        expect(
          extended.inMilliseconds,
          greaterThan((base.inMilliseconds * 1.3).round()),
        );
      },
    );
  });
}

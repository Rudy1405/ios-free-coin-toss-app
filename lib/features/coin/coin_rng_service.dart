import 'dart:math';

enum FlipResult { cara, cruz }

class CoinRngService {
  final Random _random = Random.secure();

  FlipResult flip() {
    return _random.nextBool() ? FlipResult.cara : FlipResult.cruz;
  }

  FlipResult getInitialFace() {
    return _random.nextBool() ? FlipResult.cara : FlipResult.cruz;
  }
}

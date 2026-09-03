import 'dart:async';

enum CoinFace { cara, cruz }

enum AnimationState { idle, playing }

class CoinAnimationController {
  CoinAnimationController({
    required this.framePaths,
    this.frameDuration = const Duration(milliseconds: 16),
  }) : assert(framePaths.isNotEmpty);

  final List<String> framePaths;

  /// Duration per frame — defaults to ~60fps (16ms).
  final Duration frameDuration;

  /// Extra full rotations a single spin can accumulate from repeated
  /// taps/swipes while already flipping (see `extendSpin`). Caps how long
  /// button-mashing can keep the coin in the air.
  static const int maxBonusRotations = 6;

  int _currentFrameIndex = 0;
  int get currentFrameIndex => _currentFrameIndex;
  String get currentFramePath => framePaths[_currentFrameIndex];

  AnimationState _state = AnimationState.idle;
  AnimationState get state => _state;

  CoinFace? _landedFace;
  CoinFace? get landedFace => _landedFace;

  Timer? _timer;
  int _elapsed = 0;
  int _totalFrames = 0;
  int _bonusRotationsUsed = 0;

  void Function(int frameIndex)? onFrameChanged;
  void Function(CoinFace result)? onComplete;

  void play(CoinFace result, {int fullRotations = 3}) {
    if (_state == AnimationState.playing) return;

    _state = AnimationState.playing;
    _landedFace = null;
    _bonusRotationsUsed = 0;

    _totalFrames = framePaths.length * fullRotations;

    final midpoint = framePaths.length ~/ 2;
    final landingFrame = result == CoinFace.cara ? 0 : midpoint;

    _elapsed = 0;
    _currentFrameIndex = 0;

    _timer = Timer.periodic(frameDuration, (timer) {
      _elapsed++;
      _currentFrameIndex = _elapsed % framePaths.length;
      onFrameChanged?.call(_currentFrameIndex);

      if (_elapsed >= _totalFrames) {
        _currentFrameIndex = landingFrame;
        _state = AnimationState.idle;
        _landedFace = result;
        timer.cancel();
        _timer = null;
        onFrameChanged?.call(_currentFrameIndex);
        onComplete?.call(result);
      }
    });
  }

  /// Prolongs an in-flight spin by one more full rotation instead of
  /// starting a new one — repeated taps/swipes while `playing` land here.
  /// The already-running `Timer` just keeps ticking against a pushed-out
  /// target, so this costs one integer bump: no new RNG draw, no new
  /// `Timer`, the landing frame/result set by `play` never changes. Returns
  /// whether the tap actually extended the spin (false while idle or once
  /// `maxBonusRotations` is used up), so callers can skip feedback for
  /// taps that had no effect.
  bool extendSpin() {
    if (_state != AnimationState.playing) return false;
    if (_bonusRotationsUsed >= maxBonusRotations) return false;
    _bonusRotationsUsed++;
    _totalFrames += framePaths.length;
    return true;
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentFrameIndex = 0;
    _state = AnimationState.idle;
    _landedFace = null;
    _elapsed = 0;
    _totalFrames = 0;
    _bonusRotationsUsed = 0;
    onFrameChanged?.call(_currentFrameIndex);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

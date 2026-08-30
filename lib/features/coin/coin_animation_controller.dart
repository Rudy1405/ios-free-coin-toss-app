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

  int _currentFrameIndex = 0;
  int get currentFrameIndex => _currentFrameIndex;
  String get currentFramePath => framePaths[_currentFrameIndex];

  AnimationState _state = AnimationState.idle;
  AnimationState get state => _state;

  CoinFace? _landedFace;
  CoinFace? get landedFace => _landedFace;

  Timer? _timer;

  void Function(int frameIndex)? onFrameChanged;
  void Function(CoinFace result)? onComplete;

  void play(CoinFace result, {int fullRotations = 3}) {
    if (_state == AnimationState.playing) return;

    _state = AnimationState.playing;
    _landedFace = null;

    final totalFrames = framePaths.length * fullRotations;

    final midpoint = framePaths.length ~/ 2;
    final landingFrame = result == CoinFace.cara ? 0 : midpoint;

    var elapsed = 0;
    _currentFrameIndex = 0;

    _timer = Timer.periodic(frameDuration, (timer) {
      elapsed++;
      _currentFrameIndex = elapsed % framePaths.length;
      onFrameChanged?.call(_currentFrameIndex);

      if (elapsed >= totalFrames) {
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

  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentFrameIndex = 0;
    _state = AnimationState.idle;
    _landedFace = null;
    onFrameChanged?.call(_currentFrameIndex);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

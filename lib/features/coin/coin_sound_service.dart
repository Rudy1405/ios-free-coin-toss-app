import 'package:audioplayers/audioplayers.dart';

/// Two one-shot SFX synced to the existing flip lifecycle hooks: the
/// "whoosh" fires the instant the flip starts (coin_screen.dart's
/// `_handleFlip`), the "drop" fires on `CoinAnimationController.onComplete`
/// — the same instant the landing haptic and bounce already trigger.
/// Two separate players (rather than one reused instance) so a fast re-flip
/// can start a new whoosh while the previous drop is still ringing out
/// without cutting either off.
class CoinSoundService {
  CoinSoundService()
      : _flipPlayer = AudioPlayer(playerId: 'coin_flip_whoosh'),
        _dropPlayer = AudioPlayer(playerId: 'coin_flip_drop') {
    _flipPlayer.setReleaseMode(ReleaseMode.stop);
    _dropPlayer.setReleaseMode(ReleaseMode.stop);
  }

  static const _flipAsset = 'coin_sounds/coin_flip.mp3';
  static const _dropAsset = 'coin_sounds/coin_drop.mp3';

  // coin_drop.mp3 has silence baked into its start before the actual
  // clink transient — skip straight to it on playback instead of trimming
  // the asset (no ffmpeg/audio editor on this machine) or nudging the
  // onComplete trigger (that instant is shared with the landing haptic and
  // bounce, and shouldn't drift). Tune by ear: raise if the clink still
  // lags the landing, lower if it now cuts in early.
  static const _dropLeadInGap = Duration(milliseconds: 950);

  final AudioPlayer _flipPlayer;
  final AudioPlayer _dropPlayer;

  Future<void> playFlip() async {
    await _flipPlayer.stop();
    await _flipPlayer.play(AssetSource(_flipAsset));
  }

  Future<void> playLand() async {
    await _dropPlayer.stop();
    await _dropPlayer.play(
      AssetSource(_dropAsset),
      position: _dropLeadInGap,
    );
  }

  void dispose() {
    _flipPlayer.dispose();
    _dropPlayer.dispose();
  }
}

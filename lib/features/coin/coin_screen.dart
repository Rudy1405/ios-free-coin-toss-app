import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/glass_icon_button.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../history/history_provider.dart';
import '../history/history_repository.dart';
import '../menu/menu_panel.dart';
import 'coin_animation_controller.dart';
import 'coin_rng_service.dart';
import 'coin_state.dart';

// Must match `_frameCount` in generate_placeholders.dart — this app can't
// import that standalone script, so the count is duplicated here on purpose.
const _flipFrameCount = 36;
final _framePaths = List.generate(
  _flipFrameCount,
  (i) => 'assets/coin/flip_sequence/frame_${i.toString().padLeft(2, '0')}.png',
);

const _caraAssetPath = 'assets/coin/cara/cara.png';
const _cruzAssetPath = 'assets/coin/cruz/cruz.png';

CoinFace _toCoinFace(FlipResult result) {
  return result == FlipResult.cara ? CoinFace.cara : CoinFace.cruz;
}

class CoinScreen extends ConsumerStatefulWidget {
  const CoinScreen({super.key});

  @override
  ConsumerState<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends ConsumerState<CoinScreen>
    with TickerProviderStateMixin {
  late final CoinAnimationController _animController;
  late final FlipResult _initialFace;
  late final AnimationController _landingController;
  late final Animation<double> _landingScale;

  // Crossfade between the low-detail spinning frames and the high-detail
  // static face art, so the swap between them never happens as a hard cut.
  // value: 1 = fully showing the static face, 0 = fully showing the
  // spinning frame. Reverses (static -> frame) when a flip starts, forwards
  // (frame -> static) when it lands. Kept separate from the frame sequencer
  // (Timer.periodic) for the same testability reason as `_landingController`.
  late final AnimationController _crossfadeController;
  late final Animation<double> _staticOpacity;

  String _frameAssetPath = _framePaths.first;
  String _staticAssetPath = _caraAssetPath;

  @override
  void initState() {
    super.initState();
    _initialFace = CoinRngService().getInitialFace();
    _staticAssetPath =
        _initialFace == FlipResult.cara ? _caraAssetPath : _cruzAssetPath;

    // H4: rebote leve al aterrizar — overshoot de escala y vuelta al reposo,
    // separado del sequencer de frames (Timer.periodic) para no tocar su
    // testabilidad sin árbol de widgets.
    _landingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _landingScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_landingController);

    _crossfadeController = AnimationController(
      vsync: this,
      value: 1.0, // idle: fully showing the static face
      duration: const Duration(milliseconds: 220), // frame -> static (land)
      reverseDuration: const Duration(milliseconds: 140), // static -> frame
    );
    _staticOpacity = CurvedAnimation(
      parent: _crossfadeController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController = CoinAnimationController(framePaths: _framePaths);

    _animController.onFrameChanged = (_) {
      setState(() {
        _frameAssetPath = _animController.currentFramePath;
      });
    };

    _animController.onComplete = (result) {
      HapticFeedback.selectionClick(); // H2: haptic al revelar el resultado
      setState(() {
        _staticAssetPath =
            result == CoinFace.cara ? _caraAssetPath : _cruzAssetPath;
      });
      _crossfadeController.forward(from: 0);
      _landingController.forward(from: 0);
      ref.read(coinStateProvider.notifier).resolveFlip();
    };
  }

  @override
  void dispose() {
    _animController.dispose();
    _landingController.dispose();
    _crossfadeController.dispose();
    super.dispose();
  }

  void _handleFlip() {
    final status = ref.read(coinStateProvider).status;
    if (status != CoinStatus.idle && status != CoinStatus.result) return;

    final notifier = ref.read(coinStateProvider.notifier);
    notifier.startFlip();

    final pending = notifier.pendingResult;
    if (pending != null) {
      _crossfadeController.reverse(from: 1);
      _animController.play(_toCoinFace(pending));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinState = ref.watch(coinStateProvider);
    final history = ref.watch(historyProvider);
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final coinSize = math
        .min(screenSize.width * 0.6, screenSize.height * 0.4)
        .clamp(120.0, 400.0);
    // 1: la paleta activa sigue a la cara resuelta — P1 (oro) para cara,
    // P2 (plata azulada) para cruz. Ver public_rag/app_look_feel.md.
    final palette = CoinPalette.forResult(coinState.lastResult);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.backgroundTop, palette.backgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _handleFlip,
                            onVerticalDragEnd: (details) {
                              if (details.velocity.pixelsPerSecond.dy < -100) {
                                _handleFlip();
                              }
                            },
                            child: AnimatedBuilder(
                              animation: _landingScale,
                              builder: (context, child) => Transform.scale(
                                scale: _landingScale.value,
                                child: child,
                              ),
                              child: SizedBox(
                                width: coinSize,
                                height: coinSize,
                                child: AnimatedBuilder(
                                  animation: _staticOpacity,
                                  builder: (context, child) {
                                    final staticOpacity = _staticOpacity.value;
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Opacity(
                                          opacity: 1 - staticOpacity,
                                          child: Image.asset(
                                            _frameAssetPath,
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                        Opacity(
                                          opacity: staticOpacity,
                                          child: Image.asset(
                                            _staticAssetPath,
                                            fit: BoxFit.contain,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (coinState.status == CoinStatus.result &&
                              coinState.lastResult != null)
                            _GlassLabel(
                              text: coinState.lastResult == FlipResult.cara
                                  ? l10n.heads
                                  : l10n.tails,
                              palette: palette,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (history.isNotEmpty) _HistoryRow(records: history),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GlassIconButton(
                    icon: CupertinoIcons.line_horizontal_3,
                    palette: palette,
                    semanticLabel: l10n.menuButtonSemanticLabel,
                    onPressed: () => openMenuPanel(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.text, required this.palette});

  final String text;
  final CoinPalette palette;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CupertinoColors.white.withValues(alpha: 0.14),
                CupertinoColors.white.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.glassBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.records});

  final List<FlipRecord> records;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CupertinoColors.white.withValues(alpha: 0.10),
                  CupertinoColors.white.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: records.map((r) => _HistoryChip(record: r)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.record});

  final FlipRecord record;

  @override
  Widget build(BuildContext context) {
    final isCara = record.result == 'cara';
    final palette = isCara ? CoinPalette.cara : CoinPalette.cruz;
    final l10n = AppLocalizations.of(context)!;
    final label = isCara ? l10n.heads : l10n.tails;
    final time = DateFormat.Hm().format(record.timestamp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.glassTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.glassBorder, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
              color: CupertinoColors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: CupertinoColors.systemGrey2.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../history/history_provider.dart';
import '../history/history_repository.dart';
import 'coin_animation_controller.dart';
import 'coin_rng_service.dart';
import 'coin_state.dart';

const _framePaths = [
  'assets/coin/flip_sequence/frame_00.png',
  'assets/coin/flip_sequence/frame_01.png',
  'assets/coin/flip_sequence/frame_02.png',
  'assets/coin/flip_sequence/frame_03.png',
  'assets/coin/flip_sequence/frame_04.png',
  'assets/coin/flip_sequence/frame_05.png',
  'assets/coin/flip_sequence/frame_06.png',
  'assets/coin/flip_sequence/frame_07.png',
  'assets/coin/flip_sequence/frame_08.png',
  'assets/coin/flip_sequence/frame_09.png',
  'assets/coin/flip_sequence/frame_10.png',
  'assets/coin/flip_sequence/frame_11.png',
];

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
    with SingleTickerProviderStateMixin {
  late final CoinAnimationController _animController;
  late final FlipResult _initialFace;
  late final AnimationController _landingController;
  late final Animation<double> _landingScale;
  String _displayedAsset = _caraAssetPath;

  @override
  void initState() {
    super.initState();
    _initialFace = CoinRngService().getInitialFace();
    _displayedAsset = _initialFace == FlipResult.cara
        ? _caraAssetPath
        : _cruzAssetPath;

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

    _animController = CoinAnimationController(
      framePaths: _framePaths,
      caraAssetPath: _caraAssetPath,
      cruzAssetPath: _cruzAssetPath,
    );

    _animController.onFrameChanged = (_) {
      setState(() {
        _displayedAsset = _animController.currentAssetPath;
      });
    };

    _animController.onComplete = (_) {
      HapticFeedback.selectionClick(); // H2: haptic al revelar el resultado
      _landingController.forward(from: 0);
      ref.read(coinStateProvider.notifier).resolveFlip();
    };
  }

  @override
  void dispose() {
    _animController.dispose();
    _landingController.dispose();
    super.dispose();
  }

  void _handleFlip() {
    final status = ref.read(coinStateProvider).status;
    if (status != CoinStatus.idle && status != CoinStatus.result) return;

    final notifier = ref.read(coinStateProvider.notifier);
    notifier.startFlip();

    final pending = notifier.pendingResult;
    if (pending != null) {
      _animController.play(_toCoinFace(pending));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinState = ref.watch(coinStateProvider);
    final history = ref.watch(historyProvider);
    final screenSize = MediaQuery.of(context).size;
    final coinSize = math
        .min(screenSize.width * 0.6, screenSize.height * 0.4)
        .clamp(120.0, 400.0);
    // 1: la paleta activa sigue a la cara resuelta — P1 (oro) para cara,
    // P2 (plata azulada) para cruz. Ver public_rag/app_look_feel.md.
    final palette = CoinPalette.forResult(coinState.lastResult);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
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
                          child: Image.asset(
                            _displayedAsset,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (coinState.status == CoinStatus.result &&
                        coinState.lastResult != null)
                      _GlassLabel(
                        text: coinState.lastResult == FlipResult.cara
                            ? 'CARA'
                            : 'CRUZ',
                        palette: palette,
                      ),
                  ],
                ),
              ),
            ),
            if (history.isNotEmpty)
              _HistoryRow(records: history),
          ],
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
    final label = isCara ? 'CARA' : 'CRUZ';
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

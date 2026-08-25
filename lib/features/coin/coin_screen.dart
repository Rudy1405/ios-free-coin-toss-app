import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

class _CoinScreenState extends ConsumerState<CoinScreen> {
  late final CoinAnimationController _animController;
  late final FlipResult _initialFace;
  String _displayedAsset = _caraAssetPath;

  @override
  void initState() {
    super.initState();
    _initialFace = CoinRngService().getInitialFace();
    _displayedAsset = _initialFace == FlipResult.cara
        ? _caraAssetPath
        : _cruzAssetPath;

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
      ref.read(coinStateProvider.notifier).resolveFlip();
    };
  }

  @override
  void dispose() {
    _animController.dispose();
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
                    const SizedBox(height: 32),
                    if (coinState.status == CoinStatus.result &&
                        coinState.lastResult != null)
                      _GlassLabel(
                        text: coinState.lastResult == FlipResult.cara
                            ? 'CARA'
                            : 'CRUZ',
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
  const _GlassLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
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
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.25),
              ),
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
    final label = record.result == 'cara' ? 'CARA' : 'CRUZ';
    final time = DateFormat.Hm().format(record.timestamp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );
  }
}

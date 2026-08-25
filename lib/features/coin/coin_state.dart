import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_provider.dart';
import 'coin_rng_service.dart';

enum CoinStatus { idle, flipping, result }

class CoinState {
  const CoinState({this.status = CoinStatus.idle, this.lastResult});

  final CoinStatus status;
  final FlipResult? lastResult;

  CoinState copyWith({CoinStatus? status, FlipResult? lastResult}) {
    return CoinState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class CoinStateNotifier extends StateNotifier<CoinState> {
  CoinStateNotifier({
    CoinRngService? rngService,
    this.historyNotifier,
  })  : _rngService = rngService ?? CoinRngService(),
        super(const CoinState());

  final CoinRngService _rngService;
  final HistoryNotifier? historyNotifier;
  FlipResult? _pendingResult;

  FlipResult? get pendingResult => _pendingResult;

  void startFlip() {
    if (state.status == CoinStatus.flipping) return;
    _pendingResult = _rngService.flip();
    state = state.copyWith(status: CoinStatus.flipping);
  }

  void resolveFlip() {
    if (state.status != CoinStatus.flipping || _pendingResult == null) return;
    final result = _pendingResult!;
    state = CoinState(status: CoinStatus.result, lastResult: result);
    _pendingResult = null;

    final resultStr = result == FlipResult.cara ? 'cara' : 'cruz';
    historyNotifier?.recordFlip(resultStr);
  }

  void reset() {
    _pendingResult = null;
    state = const CoinState();
  }
}

final coinStateProvider =
    StateNotifierProvider<CoinStateNotifier, CoinState>((ref) {
  final history = ref.watch(historyProvider.notifier);
  return CoinStateNotifier(historyNotifier: history);
});

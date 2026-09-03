import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<FlipRecord>>((ref) {
  return HistoryNotifier(ref.watch(historyRepositoryProvider));
});

class HistoryNotifier extends StateNotifier<List<FlipRecord>> {
  HistoryNotifier(this._repo) : super(_repo.getLastFive());

  final HistoryRepository _repo;

  Future<void> recordFlip(String result) async {
    await _repo.saveFlip(result);
    state = _repo.getLastFive();
  }
}

import 'package:home_widget/home_widget.dart';

import '../coin/coin_rng_service.dart';
import '../history/history_repository.dart';

class CoinWidgetService {
  CoinWidgetService({required this.historyRepo});

  final HistoryRepository historyRepo;

  static const _appGroupId = 'group.com.caracruz.widget';
  static const _iOSWidgetName = 'CaraOCruzWidget';
  static const _resultKey = 'last_flip_result';

  Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  Future<String> triggerFlip() async {
    final rng = CoinRngService();
    final result = rng.flip();
    final resultStr = result == FlipResult.cara ? 'cara' : 'cruz';

    await historyRepo.saveFlip(resultStr);
    await HomeWidget.saveWidgetData<String>(_resultKey, resultStr);
    await HomeWidget.updateWidget(iOSName: _iOSWidgetName);

    return resultStr;
  }
}

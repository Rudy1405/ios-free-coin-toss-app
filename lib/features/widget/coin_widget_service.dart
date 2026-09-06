import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../coin/coin_rng_service.dart';

const _androidProviderName = 'CoinWidgetProvider';
const _resultKey = 'widget_flip_result';

/// Registra [coinWidgetFlipCallback] para que el widget de Android "tiro
/// rápido" pueda correr código Dart real al tocarse (ver CLAUDE.md). Solo
/// tiene efecto en Android -- `home_widget` no tiene una extensión de
/// widget nativa en Web/Windows/iOS para esta app, así que invocar el canal
/// ahí tiraría una `MissingPluginException`.
Future<void> initializeCoinWidget() async {
  if (kIsWeb || !Platform.isAndroid) return;
  await HomeWidget.registerInteractivityCallback(coinWidgetFlipCallback);
}

/// Corre en el `FlutterEngine` headless que arranca `CoinFlipTapReceiver`
/// (Kotlin) al tocar el widget. El estado de carga ya lo pintó ese receiver
/// de forma instantánea y nativa -- acá solo hace falta sortear el
/// resultado con [CoinRngService] (la misma lógica que usa la app, ver
/// `coin_rng_service_test.dart`) y esperar lo que falte para completar
/// ~1s reales desde el toque (`tappedAtMillis`, agregado por el receiver a
/// la URI), para que el flip se sienta parejo sin importar cuánto tardó el
/// engine en arrancar. A propósito no toca `HistoryRepository`/Hive: el
/// tiro del widget es independiente del historial de la app.
@pragma('vm:entry-point')
Future<void> coinWidgetFlipCallback(Uri? uri) async {
  const targetDelay = Duration(milliseconds: 1000);

  final tappedAtMillis = int.tryParse(
    uri?.queryParameters['tappedAtMillis'] ?? '',
  );
  final elapsed = tappedAtMillis == null
      ? Duration.zero
      : Duration(
          milliseconds: DateTime.now().millisecondsSinceEpoch - tappedAtMillis,
        );
  final remaining = targetDelay - elapsed;
  if (remaining > Duration.zero) {
    await Future.delayed(remaining);
  }

  final result = CoinRngService().flip();
  await HomeWidget.saveWidgetData<String>(
    _resultKey,
    result == FlipResult.cara ? 'cara' : 'cruz',
  );
  await HomeWidget.updateWidget(androidName: _androidProviderName);
}

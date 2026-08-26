import 'package:flutter/cupertino.dart';

import '../features/coin/coin_rng_service.dart';

abstract class AppTheme {
  static const darkBackground = Color(0xFF1C1C1E);
  static const lightBackground = Color(0xFFF2F2F7);

  static CupertinoThemeData get dark => const CupertinoThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
      );

  static CupertinoThemeData get light => const CupertinoThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
      );
}

/// Acento visual asociado a la cara de la moneda que está en pantalla.
///
/// `cara` ("Oro y Grafito") y `cruz` ("Plata Azulada") son las dos paletas
/// documentadas en `public_rag/app_look_feel.md` — cualquier cambio de tono
/// acá debe reflejarse también ahí y en `generate_placeholders.dart`, que
/// mantiene sus propios valores RGB porque corre fuera del SDK de Flutter.
class CoinPalette {
  const CoinPalette({
    required this.accent,
    required this.accentHighlight,
    required this.backgroundTop,
    required this.backgroundBottom,
  });

  final Color accent;
  final Color accentHighlight;

  /// Fondo Cupertino oscuro con degradado vertical (más claro arriba, más
  /// oscuro abajo), teñido según la cara activa.
  final Color backgroundTop;
  final Color backgroundBottom;

  Color get glassTint => accent.withValues(alpha: 0.18);
  Color get glassBorder => accent.withValues(alpha: 0.45);

  static const cara = CoinPalette(
    accent: Color(0xFFD6AD60),
    accentHighlight: Color(0xFFF0D698),
    backgroundTop: Color(0xFF19191D),
    backgroundBottom: Color(0xFF101012),
  );

  static const cruz = CoinPalette(
    accent: Color(0xFF8FA3C2),
    accentHighlight: Color(0xFFC7D2E0),
    backgroundTop: Color(0xFF1C1A30),
    backgroundBottom: Color(0xFF0B0B12),
  );

  static CoinPalette forResult(FlipResult? result) =>
      result == FlipResult.cruz ? cruz : cara;
}

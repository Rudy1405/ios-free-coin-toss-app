import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'theme.dart';

/// Botón circular con el material E2 (vidrio con relieve) — ver
/// `public_rag/app_look_feel.md`. Reutilizado por el botón hamburguesa
/// (`CoinScreen`) y el botón de atrás (`AboutScreen`): mismo tamaño (44×44pt,
/// cumple H3 para estos dos controles puntuales) y misma receta de vidrio
/// que `_GlassLabel`/`_HistoryRow`, solo que circular.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    required this.palette,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;
  final CoinPalette palette;

  static const double size = 44;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(size / 2),
            onPressed: onPressed,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.white.withValues(alpha: 0.14),
                    CupertinoColors.white.withValues(alpha: 0.04),
                  ],
                ),
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
              child: Icon(icon, color: CupertinoColors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

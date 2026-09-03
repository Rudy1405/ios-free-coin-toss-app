import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../about/about_screen.dart';
import '../coin/coin_state.dart';

/// Abre el panel de menú como una ruta transparente que se desliza desde el
/// borde izquierdo, con scrim animado automático (`barrierColor` +
/// `barrierDismissible`) — tocar fuera del panel o el botón/gesto de atrás
/// del sistema lo cierran sin código extra (comportamiento por defecto de
/// `Navigator`).
Future<void> openMenuPanel(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: 'menu-barrier',
      barrierColor: CupertinoColors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const _MenuPanel(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    ),
  );
}

class _MenuPanel extends ConsumerWidget {
  const _MenuPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette =
        CoinPalette.forResult(ref.watch(coinStateProvider).lastResult);
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth * 0.78).clamp(240.0, 320.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: panelWidth,
        height: double.infinity,
        child: ClipRRect(
          borderRadius:
              const BorderRadius.horizontal(right: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    CupertinoColors.white.withValues(alpha: 0.12),
                    CupertinoColors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border(
                  right: BorderSide(color: palette.glassBorder, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(8, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      _AboutMenuButton(
                        palette: palette,
                        label: l10n.aboutMenuItem,
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutMenuButton extends StatelessWidget {
  const _AboutMenuButton({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final CoinPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(16),
          onPressed: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  CupertinoColors.white.withValues(alpha: 0.14),
                  CupertinoColors.white.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.info_circle,
                    color: palette.accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

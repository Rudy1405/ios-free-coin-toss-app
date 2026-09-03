import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass_icon_button.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../coin/coin_state.dart';

/// Pantalla "Acerca de" — se empuja con `CupertinoPageRoute`, lo que ya
/// habilita gratis el swipe-back de iOS y el botón/gesto de atrás del
/// sistema en Android (`Navigator` los resuelve como un pop por defecto,
/// sin código adicional). El botón de atrás visible es solo un atajo táctil
/// más, no reemplaza esos gestos.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette =
        CoinPalette.forResult(ref.watch(coinStateProvider).lastResult);
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.transparent,
      child: DecoratedBox(
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 96)),
                        const SizedBox(height: 28),
                        Text(
                          l10n.aboutBody,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            letterSpacing: -0.2,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: GlassIconButton(
                    icon: CupertinoIcons.back,
                    palette: palette,
                    semanticLabel: l10n.backButtonSemanticLabel,
                    onPressed: () => Navigator.of(context).maybePop(),
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

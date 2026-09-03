import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme.dart';
import 'features/coin/coin_screen.dart';
import 'features/history/history_provider.dart';
import 'features/history/history_repository.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final historyRepo = HistoryRepository();
  await historyRepo.init();

  runApp(
    ProviderScope(
      overrides: [
        historyRepositoryProvider.overrideWithValue(historyRepo),
      ],
      child: const CaraOCruzApp(),
    ),
  );
}

class CaraOCruzApp extends StatelessWidget {
  const CaraOCruzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // Sigue el idioma del sistema operativo; si no está soportado, cae a
      // `supportedLocales.first` (es, forzado por `preferred-supported-locales`
      // en l10n.yaml — ver CLAUDE.md).
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const CoinScreen(),
    );
  }
}

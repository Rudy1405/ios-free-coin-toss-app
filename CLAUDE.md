# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

App Flutter "Cara o Cruz" (heads/tails). Paquete Dart `cara_o_cruz`, org `com.caracruz`. UI en español (locale `es`), tema oscuro Cupertino (iOS-like). Reconstruida siguiendo la guía `../claude_deploy.md` (repo padre `toss_coin/`).

Flujo: tap o swipe-up sobre la moneda → el resultado se sortea de inmediato con `Random.secure()` → se reproduce una animación de sprites (12 frames, ~24fps) que simula el giro → la moneda cae en el frame que corresponde al resultado ya decidido → aparece una etiqueta glassmorphism ("CARA"/"CRUZ") → el resultado se persiste en Hive y se muestra en una fila de historial (últimos 5, más reciente primero).

## Comandos

El SDK de Flutter está instalado localmente en `%USERPROFILE%\flutter_sdk\flutter`, **no** en el PATH global de la máquina (solo en el user PATH). En una sesión de shell nueva, si `flutter`/`dart` no se reconocen, anteponer:

```powershell
$env:Path += ";$env:USERPROFILE\flutter_sdk\flutter\bin"
```

```bash
flutter pub get                         # instalar dependencias
dart run generate_placeholders.dart     # (re)generar los 14 PNG placeholder si assets/coin/ está vacío
flutter analyze                         # debe dar 0 issues
flutter test                            # corre todos los tests
flutter test test/coin_rng_service_test.dart   # un solo archivo de test
flutter test --plain-name "distribution"       # un solo test por nombre
flutter run -d chrome --web-port=8765   # correr en navegador (no requiere Developer Mode de Windows)
flutter run -d windows                  # requiere Developer Mode de Windows activado (ver Gotchas)
```

## Arquitectura

```
lib/
├── main.dart                      # init Hive → crea HistoryRepository → ProviderScope(overrides: [historyRepositoryProvider]) → CupertinoApp
├── core/theme.dart                # AppTheme.dark / .light (CupertinoThemeData)
└── features/
    ├── coin/
    │   ├── coin_rng_service.dart          # FlipResult{cara,cruz}; Random.secure()
    │   ├── coin_animation_controller.dart # sprite sequencer basado en Timer.periodic
    │   ├── coin_state.dart                # CoinStateNotifier (Riverpod)
    │   └── coin_screen.dart               # UI: gesto, imagen animada, glass label, history row
    ├── history/
    │   ├── history_repository.dart        # Hive Box<String>, máx 5 registros FIFO
    │   └── history_provider.dart          # historyRepositoryProvider + historyProvider
    └── widget/coin_widget_service.dart    # bridge a home_widget (iOS home-screen widget), stub sin extensión nativa
```

Flujo de estado entre capas, de arriba a abajo:

1. **`CoinScreen._handleFlip()`** llama a `CoinStateNotifier.startFlip()`, que sortea el resultado *inmediatamente* (vía `CoinRngService`) y lo guarda en `pendingResult` — el estado pasa a `flipping` antes de que la animación empiece a correr.
2. `CoinScreen` toma ese `pendingResult` y arranca `CoinAnimationController.play(result)`, que hace *tick* cada 42ms (`Timer.periodic`, no `AnimationController`/`TickerProvider` — así se puede testear sin árbol de widgets) durante `frames.length * fullRotations` pasos, y aterriza en el frame que corresponde al resultado ya fijado.
3. Al terminar, `onComplete` dispara `CoinStateNotifier.resolveFlip()`, que pasa el estado a `result` y llama a `HistoryNotifier.recordFlip()`.
4. `HistoryNotifier` persiste en `HistoryRepository` (Hive) y refresca su estado (`List<FlipRecord>`, ya invertido para mostrar el más reciente primero), que `CoinScreen` observa vía `ref.watch(historyProvider)`.

**Por qué el resultado se decide antes de animar:** evita que la animación "mienta" — el frame final siempre corresponde al resultado ya sorteado, nunca al revés.

**Inyección de `HistoryRepository`:** se registra como `Provider` que lanza `UnimplementedError` por defecto y se sobreescribe en `main.dart` con la instancia real de Hive. Los tests (`widget_test.dart`) inyectan un `FakeHistoryRepository` de la misma forma, sin tocar Hive.

## Look & feel

@public_rag/app_look_feel.md

## Build Android / iOS

El proyecto ya tiene ambas carpetas de plataforma (`android/`, `ios/`) generadas por `flutter create` y configuradas — `flutter analyze`/`flutter test`/`flutter pub get` pasan limpio, y `flutter build apk --debug` en esta máquina falla únicamente por falta del SDK (ver Gotchas), no por nada del proyecto. No hay nada bloqueado del lado del código; lo que falta es toolchain y, para publicar, credenciales que no corresponde generar acá.

- **Application ID / Bundle ID** ya seteados desde el scaffold inicial: `com.caracruz.cara_o_cruz` (Android, en `android/app/build.gradle.kts`) y `com.caracruz.caraOCruz` (iOS, en `ios/Runner.xcodeproj/project.pbxproj`). Nombre visible en ambas plataformas: "Cara o Cruz" (`android:label` en `AndroidManifest.xml`, `CFBundleDisplayName` en `Info.plist`).
- **Sin permisos runtime**: la app solo usa Hive (almacenamiento local), no pide `INTERNET` ni nada más allá de lo que Flutter agrega automáticamente a los manifests de debug/profile para hot reload.
- **Android, para correr ahora**: instalar Android Studio (trae el SDK) o `flutter config --android-sdk <ruta>` si ya está instalado en otro lado, después `flutter build apk --debug`. También requiere "Modo de programador" de Windows activado (ver Gotchas) para el paso de symlinks — no hace falta para hacer *build*, sí para `flutter run -d <android-device>` en esta máquina.
- **Android, para publicar en Play Store**: `android/app/build.gradle.kts` firma el build `release` con el keystore de **debug** ("para que `flutter run --release` funcione") — sirve para probar localmente pero no para subir a la Play Store. Antes de un release real hace falta un keystore de verdad + `android/key.properties` (gitignorado, no commitear) apuntado desde `signingConfigs`.
- **iOS, no compilable desde Windows** (`flutter build ios` ni siquiera existe como subcomando acá — requiere macOS/Xcode). En una Mac: `flutter pub get` + abrir `ios/Runner.xcworkspace` (o `flutter build ios`) resuelve dependencias de plugins automáticamente (CocoaPods o Swift Package Manager según la versión de Flutter — no hay `ios/Podfile` commiteado a propósito, se genera solo en el primer build). Falta setear el **Development Team** en Xcode (signing) con una cuenta de Apple Developer — no hay ninguno seteado en el proyecto, es specific de cada desarrollador/cuenta.
- **`coin_widget_service.dart` es un stub**: el widget de home screen de iOS (`home_widget` package) todavía no tiene su Widget Extension target real agregado en Xcode — no bloquea compilar la app principal, pero el widget no va a aparecer hasta que se agregue esa extensión (trabajo que requiere Xcode, no se puede hacer desde acá).
- **Íconos de app**: siguen siendo el ícono default de Flutter en ambas plataformas — no se generó uno custom con la nueva identidad visual (ver `public_rag/app_look_feel.md`) porque no se pidió explícitamente; queda pendiente si se quiere antes de publicar.

## Gotchas del entorno (Windows)

- Compilar/correr para **Windows desktop o Android** requiere symlinks, lo que a su vez requiere "Modo de programador" activado en Windows (Configuración → Para desarrolladores). No se puede activar por script sin privilegios de administrador (clave en `HKLM`). **Web** (`flutter run -d chrome`) y `flutter analyze`/`flutter test` no lo necesitan.
- Falta Android SDK/Android Studio en esta máquina (`flutter doctor` lo marca faltante) — build Android real está bloqueado hasta instalarlo. iOS no es compilable desde Windows (requiere macOS/Xcode).
- `coin_screen.dart` calcula el tamaño de la moneda como `min(width*0.6, height*0.4).clamp(120, 400)` — **no** uses solo `screenWidth * 0.6` (como en el spec original), causa `RenderFlex overflow` en viewports anchos y bajos (ventanas de escritorio/navegador en landscape); se verificó y corrigió este bug durante la implementación inicial.
- `generate_placeholders.dart` escribe PNGs a mano (sin paquete `image`) para no depender de nada fuera del SDK de Dart — mantiene esa restricción si se modifica.

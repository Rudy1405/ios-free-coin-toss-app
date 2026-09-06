# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es

App Flutter "Cara o Cruz" (heads/tails). Paquete Dart `cara_o_cruz`, org `com.caracruz`. UI localizada según el idioma del sistema operativo (ver "Localización" más abajo; fallback a español), tema oscuro Cupertino (iOS-like). Reconstruida siguiendo la guía `../claude_deploy.md` (repo padre `toss_coin/`).

Flujo: tap o swipe-up sobre la moneda → el resultado se sortea de inmediato con `Random.secure()` → la cara estática (arte real, ver `assets_ref/coins/`) se desvanece hacia la secuencia de giro (36 frames de arte real, ~60fps, con motion blur creciente hacia las poses de canto — ver "Assets de la moneda" en `public_rag/app_look_feel.md`) → la moneda cae en el frame que corresponde al resultado ya decidido y se desvanece de vuelta hacia la cara estática correspondiente → aparece una etiqueta glassmorphism con el resultado localizado ("CARA"/"CRUZ" en español, "HEADS"/"TAILS" en inglés) → el resultado se persiste en Hive y se muestra en una fila de historial con scroll horizontal (últimos 10, más reciente primero).

Además, un botón hamburguesa en la esquina superior izquierda abre un panel lateral con un único ítem, "Acerca de" (localizado), que lleva a una pantalla informativa estática — ver "Navegación — menú y Acerca de" más abajo.

## Comandos

El SDK de Flutter está instalado localmente en `%USERPROFILE%\flutter_sdk\flutter`, **no** en el PATH global de la máquina (solo en el user PATH). En una sesión de shell nueva, si `flutter`/`dart` no se reconocen, anteponer:

```powershell
$env:Path += ";$env:USERPROFILE\flutter_sdk\flutter\bin"
```

```bash
flutter pub get                         # instalar dependencias; también regenera lib/l10n/app_localizations*.dart (generate: true + l10n.yaml)
flutter gen-l10n                        # regenerar solo las clases de localización (p.ej. tras editar un .arb), sin bajar dependencias
dart run generate_placeholders.dart     # NO correr salvo que se quiera volver a placeholders procedurales -- flip_sequence/ ya es arte real, ver Gotchas
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
├── core/
│   ├── theme.dart                 # AppTheme.dark / .light (CupertinoThemeData), CoinPalette
│   └── glass_icon_button.dart     # botón circular E2 reutilizado por el hamburguesa y el de atrás
├── l10n/
│   ├── app_es.arb                 # strings fuente (template-arb-file en l10n.yaml), es = fallback
│   ├── app_en.arb                 # traducciones al inglés
│   └── app_localizations*.dart    # generados por `flutter gen-l10n`/`flutter pub get` — gitignored, NO editar a mano
└── features/
    ├── coin/
    │   ├── coin_rng_service.dart          # FlipResult{cara,cruz}; Random.secure()
    │   ├── coin_animation_controller.dart # sprite sequencer basado en Timer.periodic
    │   ├── coin_state.dart                # CoinStateNotifier (Riverpod)
    │   └── coin_screen.dart               # UI: gesto, imagen animada, glass label, history row, botón hamburguesa
    ├── history/
    │   ├── history_repository.dart        # Hive Box<String>, máx 10 registros FIFO
    │   └── history_provider.dart          # historyRepositoryProvider + historyProvider
    ├── menu/menu_panel.dart       # openMenuPanel() + panel lateral (único ítem: "Acerca de")
    ├── about/about_screen.dart    # pantalla "Acerca de": emoji 🪙 + texto centrado + botón de atrás
    └── widget/coin_widget_service.dart    # callback de home_widget para el widget de Android; ver "Widget de Android"
```

Flujo de estado entre capas, de arriba a abajo:

1. **`CoinScreen._handleFlip()`** llama a `CoinStateNotifier.startFlip()`, que sortea el resultado *inmediatamente* (vía `CoinRngService`) y lo guarda en `pendingResult` — el estado pasa a `flipping` antes de que la animación empiece a correr.
2. `CoinScreen` toma ese `pendingResult` y arranca `CoinAnimationController.play(result)`, que hace *tick* cada 16ms (`Timer.periodic`, no `AnimationController`/`TickerProvider` — así se puede testear sin árbol de widgets) durante `frames.length * fullRotations` pasos, y aterriza en el frame que corresponde al resultado ya fijado.
3. Al terminar, `onComplete` dispara `CoinStateNotifier.resolveFlip()`, que pasa el estado a `result` y llama a `HistoryNotifier.recordFlip()`.
4. `HistoryNotifier` persiste en `HistoryRepository` (Hive) y refresca su estado (`List<FlipRecord>`, ya invertido para mostrar el más reciente primero), que `CoinScreen` observa vía `ref.watch(historyProvider)`.

**Por qué el resultado se decide antes de animar:** evita que la animación "mienta" — el frame final siempre corresponde al resultado ya sorteado, nunca al revés.

**Multi-tap/multi-swipe durante el giro:** `CoinScreen._handleFlip()` detecta `status == flipping` y, en vez de ignorar el gesto o llamar a `startFlip()` de nuevo, llama a `CoinAnimationController.extendSpin()` — suma una rotación completa más al `Timer.periodic` ya corriendo (mismo timer, sin cancelarlo/recrearlo) en vez de arrancar un giro nuevo. El resultado sorteado en el primer tap **no cambia**: recalcularlo en cada tap permitiría re-tirar la moneda a fuerza de tapear rápido, lo cual rompe la garantía de "una sola tirada justa" que es el propósito de la app (ver el punto anterior). `extendSpin()` está acotado por `maxBonusRotations` (6) para que un usuario tapeando sin parar no deje la moneda girando indefinidamente, y no repite el sonido de "whoosh" en cada tap extra (reiniciar un clip de ~1s cada pocos milisegundos suena a corte, no a moneda girando) — en su lugar dispara un `HapticFeedback.lightImpact()` liviano solo cuando el tap efectivamente extendió el giro (no cuando ya se llegó al tope).

**Crossfade cara-estática ↔ frames de giro:** `CoinScreen` dibuja dos `Image.asset` superpuestas (Stack) — una para la cara estática (arte real) y otra para el frame de giro actual — y cruza su opacidad con un `AnimationController` propio (`_crossfadeController`, 140ms al arrancar el giro, 220ms al aterrizar), separado del sequencer de frames por la misma razón de testabilidad que el rebote de aterrizaje (`_landingController`). Esto evita el corte brusco entre la cara estática y el primer/último frame del `flip_sequence` (ambos son arte real, pero renderizados por separado).

**Inyección de `HistoryRepository`:** se registra como `Provider` que lanza `UnimplementedError` por defecto y se sobreescribe en `main.dart` con la instancia real de Hive. Los tests (`widget_test.dart`) inyectan un `FakeHistoryRepository` de la misma forma, sin tocar Hive.

## Widget de Android (tiro rápido)

Widget de home screen (`android/app/src/main/kotlin/com/caracruz/cara_o_cruz/`)
para tirar la moneda sin abrir la app: mientras "carga" muestra el mismo
`flip_sequence` de 36 frames (arte real) que usa `CoinAnimationController`
en la app, en chiquito (56dp), vía un `ViewFlipper` nativo — no una
reimplementación de `CoinAnimationController`, es directamente el mismo
arte duplicado como recurso Android (ver punto 2). A propósito **no** usa
`HistoryRepository`/Hive — es un tiro independiente, no aparece en el
historial de la app.

Corre código Dart real (no es una reimplementación nativa del RNG) vía
`registerInteractivityCallback` del paquete `home_widget`, que arranca un
`FlutterEngine` headless al tocar el widget:

1. `CoinWidgetProvider.kt` (`AppWidgetProvider`) arma el `RemoteViews` de
   idle/resultado (`res/layout/coin_widget.xml`) a partir de
   `widget_flip_result` (guardado por Dart vía `HomeWidget.saveWidgetData`).
   El estado de loading **nunca** pasa por acá, vive en un layout aparte
   (`res/layout/coin_widget_loading.xml`, ver punto 2). El estado de
   resultado muestra el arte real (`cara.png`/`cruz.png`, duplicado en
   `res/drawable-nodpi/coin_widget_{cara,cruz}.png` porque un `RemoteViews`
   no puede leer el asset bundle de Flutter) junto al texto "CARA"/"CRUZ".
2. El toque no apunta al `HomeWidgetBackgroundReceiver` del plugin sino a
   `CoinFlipTapReceiver.kt`, un `BroadcastReceiver` propio y chico: pinta el
   loading al instante (sin esperar a Flutter, para que el widget nunca se
   sienta trabado) inflando `coin_widget_loading.xml` — un `ViewFlipper`
   (`android:autoStart="true"`, `flipInterval="30"`) con 36 `ImageView`
   hijos, uno por frame de `flip_sequence/`, duplicados a mano como
   `res/drawable-nodpi/coin_widget_flip_00..35.png` (mismo motivo que
   `cara.png`/`cruz.png`: `RemoteViews` no lee el asset bundle de Flutter).
   `ViewFlipper` es de los pocos widgets "vivos" que Android permite dentro
   de un `AppWidget` — el host anima los hijos solo, sin que el proceso de
   la app seguir corriendo. Layout separado a propósito de
   `coin_widget.xml`: al pasar a idle/resultado se infla un `RemoteViews`
   totalmente nuevo, así el `ViewFlipper` nunca queda escondido pero
   corriendo de fondo. Después de pintar el loading, le agrega
   `tappedAtMillis` a la URI del intent y recién ahí reenvía el trabajo a
   `HomeWidgetBackgroundService` (mismo mecanismo interno del plugin) para
   que arranque el engine headless.
3. `coinWidgetFlipCallback` (`lib/features/widget/coin_widget_service.dart`)
   corre en ese engine: sortea con `CoinRngService` (la misma clase que usa
   la app) y espera lo que falte para completar ~1s reales desde
   `tappedAtMillis` antes de guardar el resultado y llamar a
   `HomeWidget.updateWidget()` — así el flip se siente parejo sin importar
   cuánto tardó el engine en arrancar (típicamente unos cientos de ms en
   caliente; si tarda más de 1s, el resultado aparece apenas está listo, sin
   sumar espera extra).
4. `initializeCoinWidget()` registra esa callback en `main()`, detrás de un
   guard `if (!kIsWeb && Platform.isAndroid)` — el canal de `home_widget`
   para esto no tiene implementación en Web/Windows/iOS y tirar sin el guard
   rompería `flutter run -d chrome`/`-d windows`.

**Paleta:** los dos `drawable/coin_widget_bg_{cara,cruz}.xml` duplican a
mano los hex de `CoinPalette` (`lib/core/theme.dart`) porque el widget
nativo no puede importar Dart — mismo patrón que `generate_placeholders.dart`.
Si se retoca un hex de paleta, replicar acá también.

## Navegación — menú y Acerca de

- **`openMenuPanel(context)`** (`features/menu/menu_panel.dart`) empuja una `PageRouteBuilder` transparente y no-opaca que desliza el panel desde el borde izquierdo (`SlideTransition`, `Offset(-1,0) → Offset.zero`, 260ms). No es un `Drawer` de Material — se construye a mano porque `CoinScreen` usa `CupertinoPageScaffold`, que no trae uno.
- **Cerrar el panel es gratis**: `barrierDismissible: true` + `barrierColor` hacen que Flutter inserte un `ModalBarrier` a pantalla completa *debajo* del panel — como el panel solo pinta/hit-testea su franja izquierda (`Align(alignment: centerLeft)`), tocar a la derecha del panel golpea el barrier y cierra la ruta sin gesture detector propio. El botón/gesto de atrás del sistema hace lo mismo por el comportamiento default de `Navigator` (pop del tope de la pila) — no hace falta `PopScope` ni manejo manual.
- **`AboutScreen`** (`features/about/about_screen.dart`) se empuja con `CupertinoPageRoute` normal desde el botón del panel (que primero hace `pop()` del panel y luego `push()` de la pantalla). Por ser `CupertinoPageRoute`, el swipe-back de iOS y el botón/gesto de atrás de Android ya quedan habilitados — el botón de atrás visible en la esquina (`GlassIconButton` con `CupertinoIcons.back`) es solo un atajo más, llama a `Navigator.of(context).maybePop()`.
- Tanto el panel como `AboutScreen` leen `ref.watch(coinStateProvider).lastResult` y usan `CoinPalette.forResult(...)` — heredan la paleta condicional activa (P1/P2) en vez de un color fijo, igual que `CoinScreen`.

## Localización

El texto de la UI sigue el idioma del sistema operativo vía el mecanismo estándar de Flutter (`flutter gen-l10n`, paquete `AppLocalizations` generado — sin `flutter_gen`/synthetic package, esa opción fue removida en la versión de Flutter de esta máquina, así que los archivos generados quedan directamente en `lib/l10n/`, no en `.dart_tool/`).

- **Fuente de verdad**: `lib/l10n/app_es.arb` (template, es = idioma original de la app) y `lib/l10n/app_en.arb`. Cada string nuevo va como clave en inglés (p. ej. `heads`/`tails`, `menuButtonSemanticLabel`, `aboutMenuItem`, `backButtonSemanticLabel`, `aboutBody`) con su traducción por archivo `.arb`.
- **`l10n.yaml`** fija `preferred-supported-locales: ["es"]` para que `AppLocalizations.supportedLocales` quede `[es, en]` (no alfabético) — el resolutor de locale de Flutter usa el primer elemento de esa lista como fallback cuando el idioma del SO no está soportado, así que sin este flag el fallback sería inglés por orden alfabético de los `.arb`, no español.
- **`main.dart`** pasa `AppLocalizations.supportedLocales`/`.localizationsDelegates` a `CupertinoApp` sin fijar `locale:` — así Flutter resuelve el locale activo desde el SO en cada arranque.
- **Uso en widgets**: `AppLocalizations.of(context)!.heads` / `.tails` (ver `coin_screen.dart`, `_GlassLabel` y `_HistoryChip`). El `!` es seguro porque el delegate siempre está registrado en `main.dart` y en `test/widget_test.dart`.
- **Los `.dart` generados (`app_localizations*.dart`) están gitignorados** — se regeneran solos en `flutter pub get` (gracias a `generate: true` en `pubspec.yaml`) o con `flutter gen-l10n`. Si `flutter analyze`/`flutter test` fallan con "target of URI doesn't exist" para `l10n/app_localizations.dart`, correr `flutter pub get` primero.
- **Para agregar un idioma**: crear `lib/l10n/app_<code>.arb` con las mismas claves que `app_es.arb`, correr `flutter gen-l10n`, listo — no hace falta tocar `main.dart`.
- Los identificadores internos `FlipResult.cara`/`.cruz` y el string `'cara'`/`'cruz'` persistido en Hive (`FlipRecord.result`, ver `history_repository.dart`) **no** están localizados a propósito — son claves internas, no texto de UI; traducirlos rompería el historial ya guardado.

## Look & feel

@public_rag/app_look_feel.md

## Build Android / iOS

El proyecto ya tiene ambas carpetas de plataforma (`android/`, `ios/`) generadas por `flutter create` y configuradas — `flutter analyze`/`flutter test`/`flutter pub get` pasan limpio. En esta máquina, Android SDK **y** Android Studio están instalados (`C:\Users\rudy1\AppData\Local\Android\Sdk`, platform android-37.0, licencias ya aceptadas) y `flutter build apk --debug` **compila sin errores** — lo verifiqué corriéndolo de verdad al agregar el widget de Android (ver sección de arriba). No hay nada bloqueado del lado del código; lo que falta para probar en vivo y para publicar se detalla abajo.

- **Application ID / Bundle ID** ya seteados desde el scaffold inicial: `com.caracruz.cara_o_cruz` (Android, en `android/app/build.gradle.kts`) y `com.caracruz.caraOCruz` (iOS, en `ios/Runner.xcodeproj/project.pbxproj`). Nombre visible en ambas plataformas: "Cara o Cruz" (`android:label` en `AndroidManifest.xml`, `CFBundleDisplayName` en `Info.plist`).
- **Sin permisos runtime**: la app solo usa Hive (almacenamiento local), no pide `INTERNET` ni nada más allá de lo que Flutter agrega automáticamente a los manifests de debug/profile para hot reload.
- **Android, para instalar y probar en un dispositivo/emulador real** (no solo compilar): `flutter build apk --debug` ya anda; instalar el APK resultante (`build/app/outputs/flutter-apk/app-debug.apk`) o usar `flutter run -d <device>` sigue necesitando algo con qué correrlo:
  - **Dispositivo físico** por USB con depuración habilitada, o
  - **Emulador**: existe un AVD `medium_phone`, pero es una imagen `x86_64` y esta máquina no tiene instalado el *Android Emulator hypervisor driver* (lo confirmé intentando arrancarlo: falla con "x86_64 emulation currently requires hardware acceleration!") — hace falta instalar ese driver (o habilitar Hyper-V/WHPX) desde Android Studio (SDK Manager → herramientas) o crear un AVD `arm64` si el host no soporta virtualización.
  - `flutter run -d android`/`-d windows` (no `build apk`) además requiere "Modo de programador" de Windows activado (ver Gotchas) para el paso de symlinks.
- **Android, para publicar en Play Store**: `android/app/build.gradle.kts` firma el build `release` con el keystore de **debug** ("para que `flutter run --release` funcione") — sirve para probar localmente pero no para subir a la Play Store. Antes de un release real hace falta un keystore de verdad + `android/key.properties` (gitignorado, no commitear) apuntado desde `signingConfigs`.
- **iOS, no compilable desde Windows** (`flutter build ios` ni siquiera existe como subcomando acá — requiere macOS/Xcode). En una Mac: `flutter pub get` + abrir `ios/Runner.xcworkspace` (o `flutter build ios`) resuelve dependencias de plugins automáticamente (CocoaPods o Swift Package Manager según la versión de Flutter — no hay `ios/Podfile` commiteado a propósito, se genera solo en el primer build). Falta setear el **Development Team** en Xcode (signing) con una cuenta de Apple Developer — no hay ninguno seteado en el proyecto, es specific de cada desarrollador/cuenta.
- **El widget de home screen de Android ya está implementado** (ver "Widget de Android" en Arquitectura) y usa `coin_widget_service.dart`. El de **iOS sigue sin construir**: `home_widget` necesita un Widget Extension target real agregado en Xcode, que no existe en este repo — no bloquea compilar la app principal, pero no va a aparecer un widget en iOS hasta que se agregue esa extensión (trabajo que requiere Xcode, no se puede hacer desde acá).
- **Íconos de app**: siguen siendo el ícono default de Flutter en ambas plataformas — no se generó uno custom con la nueva identidad visual (ver `public_rag/app_look_feel.md`) porque no se pidió explícitamente; queda pendiente si se quiere antes de publicar.

## Gotchas del entorno (Windows)

- Compilar/correr para **Windows desktop o Android vía `flutter run`** requiere symlinks, lo que a su vez requiere "Modo de programador" activado en Windows (Configuración → Para desarrolladores). No se puede activar por script sin privilegios de administrador (clave en `HKLM`). **Web** (`flutter run -d chrome`) y `flutter analyze`/`flutter test` no lo necesitan — y, contra lo que decía antes esta sección, **`flutter build apk --debug` tampoco**: lo corrí de punta a punta con Modo de programador apagado y compiló bien.
- Android SDK y Android Studio **sí están instalados** en esta máquina (`C:\Users\rudy1\AppData\Local\Android\Sdk`) — lo que falta para probar en vivo es un dispositivo conectado o un emulador que arranque; ver "Build Android / iOS" para el detalle del hypervisor driver que falta para el AVD `x86_64` existente. iOS no es compilable desde Windows (requiere macOS/Xcode).
- `coin_screen.dart` calcula el tamaño de la moneda como `min(width*0.6, height*0.4).clamp(120, 400)` — **no** uses solo `screenWidth * 0.6` (como en el spec original), causa `RenderFlex overflow` en viewports anchos y bajos (ventanas de escritorio/navegador en landscape); se verificó y corrigió este bug durante la implementación inicial.
- `generate_placeholders.dart` escribe PNGs a mano (sin paquete `image`) para no depender de nada fuera del SDK de Dart — mantiene esa restricción si se modifica. **Ya no correr este script**: tanto `assets/coin/cara/cara.png`/`cruz.png` como los 36 frames de `assets/coin/flip_sequence/` son arte real desde 2026-09-06 (antes solo las dos caras lo eran, `flip_sequence/` era procedural). El script sigue en el repo solo como referencia histórica/para volver a placeholders a propósito — correrlo por error sobreescribiría los 36 frames reales con óvalos procedurales.
- `assets/coin/cara/cara.png` y `assets/coin/cruz/cruz.png` son arte real (recortado desde las referencias en `assets_ref/coins/`, con transparencia real extraída por flood-fill — las imágenes fuente NO tenían canal alfa real pese a ser PNG/tener fondo a cuadros). Los 36 frames de `assets/coin/flip_sequence/` vinieron de `assets/new_coin_assets/` (arte real ya con squish/motion-blur horneado, mismo choreography que documentaba el script: cara nítida en 00/34-35, canto borroso en ~08-11 y ~26-29, cruz nítida en ~16-19) y reemplazaron a los placeholders procedurales — ver el commit que agregó esta nota. `assets/new_coin_assets/` (con el `contact_sheet.png` de referencia) es material de trabajo sin trackear en git — no un directorio gitignoreado a propósito, simplemente nadie lo agregó — quedó ahí como registro de dónde salió el arte nuevo; se puede borrar o commitear según se decida más adelante.
- `_flipFrameCount` en `coin_screen.dart` debe coincidir con `_frameCount` en `generate_placeholders.dart` (ambos en 36) — están duplicados a propósito porque el script no puede importar código de la app (mismo patrón que la duplicación de `CoinPalette`).
- `android/app/src/main/res/drawable-nodpi/coin_widget_{cara,cruz}.png` y `coin_widget_flip_00..35.png` son copias manuales de `assets/coin/{cara,cruz}/*.png` y `assets/coin/flip_sequence/frame_00..35.png` — un `RemoteViews` nativo no puede leer el asset bundle de Flutter, así que el widget necesita su propia copia de los 38 archivos como recursos Android reales. Si se retoca el arte de la moneda (cualquiera de las dos caras o cualquier frame), recopiar los archivos correspondientes a mano; no se regeneran solos.

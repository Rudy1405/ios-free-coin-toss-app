# Cara o Cruz

App de Flutter para lanzar una moneda ("Cara o Cruz" / heads-or-tails). Interfaz en español, tema oscuro estilo Cupertino (iOS-like), multiplataforma (iOS, Android, Web, Windows).

## Qué hace

- Toca la moneda (o desliza hacia arriba) para lanzarla.
- El resultado se decide al instante con `Random.secure()`; la cara estática se desvanece hacia una animación de 36 frames (~60fps, con motion blur) que simula el giro, y la moneda cae en el resultado ya sorteado, desvaneciéndose de vuelta a la cara estática correspondiente.
- Al aterrizar aparece una etiqueta con efecto glassmorphism: **CARA** o **CRUZ**.
- Los últimos 10 lanzamientos se guardan localmente (Hive) y se muestran en una fila de historial con scroll horizontal, con hora, más reciente primero.

## Stack

- Flutter 3.24+ / Dart ^3.5.0
- Estado: `flutter_riverpod`
- Persistencia local: `hive` / `hive_flutter`
- Localización: `flutter_localizations` (locale `es`)
- Puente opcional a widget de pantalla de inicio: `home_widget` (solo el bridge en Dart; falta la extensión nativa de Xcode/Android para un widget real)

## Requisitos previos

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.24+ instalado y en el `PATH` (verifica con `flutter doctor`).
2. Para **Android**: Android Studio + Android SDK (`flutter doctor` debe marcar el toolchain de Android en verde).
3. Para **iOS**: una Mac con Xcode 15+ instalado y, para correr en un dispositivo físico, una cuenta de Apple Developer.
4. Para compilar plugins nativos en **Windows** (si desarrollas desde ahí): activa "Modo de programador" en Configuración → Para desarrolladores (Flutter lo pide para crear symlinks).

## Instalación

```bash
git clone https://github.com/Rudy1405/ios-free-coin-toss-app.git
cd ios-free-coin-toss-app
flutter pub get
```

`assets/coin/cara/cara.png` y `assets/coin/cruz/cruz.png` son arte final (no placeholders). El resto — `assets/coin/flip_sequence/` (36 frames procedurales) — sí es un placeholder generado; si necesitas regenerarlo:

```bash
dart run generate_placeholders.dart
```

Este comando **nunca** toca `cara.png`/`cruz.png`, solo `flip_sequence/`.

Ver [`assets/README_ASSETS.md`](assets/README_ASSETS.md) para la guía de reemplazo por arte final.

## Cómo correr la app

### Web

```bash
flutter run -d chrome
```

O para servir un build de producción:

```bash
flutter build web
```

El resultado queda en `build/web/`, listo para desplegar en cualquier hosting estático.

### Android

1. Conecta un dispositivo físico con depuración USB activada, o abre un emulador desde Android Studio (`flutter emulators --launch <id>`).
2. Verifica que aparezca en la lista de dispositivos:

   ```bash
   flutter devices
   ```

3. Corre la app:

   ```bash
   flutter run -d <device-id>
   ```

Para generar un APK/App Bundle de release:

```bash
flutter build apk --release
# o
flutter build appbundle --release
```

### iOS

Solo es posible compilar/correr iOS desde una Mac.

1. Abre `ios/Runner.xcworkspace` en Xcode al menos una vez para configurar el equipo de firma (Signing & Capabilities) si vas a correr en un dispositivo físico.
2. Corre en el simulador:

   ```bash
   open -a Simulator
   flutter run -d "iPhone 15"
   ```

   O en un dispositivo físico conectado:

   ```bash
   flutter devices
   flutter run -d <device-id>
   ```

Para generar un build de release/archivo IPA:

```bash
flutter build ios --release
```

## Desarrollo

```bash
flutter analyze          # análisis estático — debe dar 0 issues
flutter test              # corre toda la suite de tests
flutter test test/coin_rng_service_test.dart   # un solo archivo
```

## Estructura del proyecto

```
lib/
├── main.dart                      # entrypoint: init Hive, ProviderScope, CupertinoApp
├── core/theme.dart                # tema Cupertino claro/oscuro
└── features/
    ├── coin/            # RNG, controlador de animación, estado y pantalla principal
    ├── history/         # repositorio (Hive) y provider del historial de lanzamientos
    └── widget/          # puente hacia home_widget (widget de pantalla de inicio, iOS)
```

Más detalle de arquitectura en [`CLAUDE.md`](CLAUDE.md).

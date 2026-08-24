# claude_deploy.md — Cara o Cruz: Full Reconstruction Guide

> **Purpose:** Hand this file to a fresh Claude instance (or any developer) and they will be able to recreate the `cara_o_cruz` Flutter project from scratch, 100% identically — same architecture, same file structure, same logic, same dependencies, same tests.

---

## 1. Project Overview

**App name:** Cara o Cruz ("Heads or Tails" in Spanish)  
**Flutter package name:** `cara_o_cruz`  
**Platform targets:** iOS, Android, Windows (Flutter multi-platform)  
**Primary UX language:** Spanish (locale: `es`)  
**Theme:** Dark, iOS-style Cupertino UI  

### What the app does
- Shows a coin on screen (either "cara" = heads or "cruz" = tails).  
- User taps the coin (or swipes up) to flip it.  
- A 12-frame sprite animation plays at ~24fps simulating the coin spinning.  
- The result is determined via `Random.secure()` *before* the animation starts; the animation just reveals it.  
- After landing, a glassmorphism label ("CARA" or "CRUZ") appears below the coin.  
- The last 5 flip results are persisted to a local Hive database and displayed as a bottom history row (time + result).  
- A `home_widget` integration exists for iOS home-screen widget support (stubbed, not fully wired to a widget extension in this codebase).

---

## 2. Prerequisites & Tool Installation

Install **all** of the following before creating any files.

### 2.1 Flutter SDK

```bash
# Minimum version: Flutter 3.24+ / Dart SDK ^3.5.0
# Download from: https://docs.flutter.dev/get-started/install
# After installation, verify:
flutter --version
dart --version
```

### 2.2 IDE (recommended)

- **Android Studio** or **VS Code** with the Flutter + Dart extensions.

### 2.3 Platform toolchains (as needed)

| Platform | Requirement |
|----------|-------------|
| iOS      | Xcode 15+, macOS only, Apple Developer account for device deploy |
| Android  | Android SDK via Android Studio |
| Windows  | Visual Studio 2022 with "Desktop development with C++" workload |

### 2.4 Dart CLI (bundled with Flutter)

No separate install needed. `dart` is on PATH after installing Flutter.

---

## 3. Project Scaffold

```bash
# Create the project — use package name cara_o_cruz, NOT coin_toss
flutter create --org com.caracruz --project-name cara_o_cruz cara_o_cruz
cd cara_o_cruz
```

> The working directory will be `cara_o_cruz/` for all subsequent steps.

---

## 4. pubspec.yaml

Replace the generated `pubspec.yaml` entirely with the following:

```yaml
name: cara_o_cruz
description: Aplicación de lanzamiento de moneda — Cara o Cruz.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  intl: any
  home_widget: ^0.7.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true

  assets:
    - assets/coin/cara/
    - assets/coin/cruz/
    - assets/coin/flip_sequence/
```

Then run:

```bash
flutter pub get
```

---

## 5. analysis_options.yaml

Replace the generated `analysis_options.yaml` with:

```yaml
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.

# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

linter:
  # The lint rules applied to this project can be customized in the
  # section below to disable rules from the `package:flutter_lints/flutter.yaml`
  # included above or to enable additional rules. A list of all available lints
  # and their documentation is published at https://dart.dev/lints.
  #
  # Instead of disabling a lint rule for the entire project in the
  # section below, it can also be suppressed for a single line of code
  # or a specific dart file by using the `// ignore: name_of_lint` and
  # `// ignore_for_file: name_of_lint` syntax on the line or in the file
  # producing the lint.
  rules:
    # avoid_print: false  # Uncomment to disable the `avoid_print` rule
    # prefer_single_quotes: true  # Uncomment to enable the `prefer_single_quotes` rule

# Additional information about this file can be found at
# https://dart.dev/guides/language/analysis-options
```

---

## 6. Directory Structure

Create all directories before writing files:

```
cara_o_cruz/
├── assets/
│   └── coin/
│       ├── cara/
│       │   └── cara.png
│       ├── cruz/
│       │   └── cruz.png
│       └── flip_sequence/
│           ├── frame_00.png  (through frame_11.png — 12 frames total)
├── lib/
│   ├── main.dart
│   ├── core/
│   │   └── theme.dart
│   └── features/
│       ├── coin/
│       │   ├── coin_animation_controller.dart
│       │   ├── coin_rng_service.dart
│       │   ├── coin_state.dart
│       │   └── coin_screen.dart
│       ├── history/
│       │   ├── history_repository.dart
│       │   └── history_provider.dart
│       └── widget/
│           └── coin_widget_service.dart
├── test/
│   ├── coin_rng_service_test.dart
│   └── widget_test.dart
├── generate_placeholders.dart
└── assets/README_ASSETS.md
```

---

## 7. Asset Generation

The assets are **placeholder PNGs** (solid color, 300×300) auto-generated by a Dart script. Create `generate_placeholders.dart` at the project root:

### `generate_placeholders.dart`

```dart
import 'dart:io';
import 'dart:typed_data';

/// Generates minimal placeholder PNG files for the coin flip animation.
/// Each file is a 300x300 solid-color PNG with no text (text would require
/// a full font renderer). Files are color-coded for easy identification:
/// - cara: gold (#FFD700)
/// - cruz: silver (#C0C0C0)
/// - flip frames: gradient from gold to silver and back

void main() {
  final base = Directory.current.path;

  // Generate cara face (gold)
  _writePng('$base/assets/coin/cara/cara.png', 300, 300, [0xFF, 0xD7, 0x00]);

  // Generate cruz face (silver)
  _writePng('$base/assets/coin/cruz/cruz.png', 300, 300, [0xC0, 0xC0, 0xC0]);

  // Generate 12 flip frames with color transition
  // Simulates: cara(gold) -> edge(thin/dark) -> cruz(silver) -> edge -> cara
  final frameColors = <List<int>>[
    [0xFF, 0xD7, 0x00], // frame_00: full cara (gold)
    [0xE6, 0xC1, 0x00], // frame_01: cara tilting
    [0xBF, 0xA0, 0x00], // frame_02: cara foreshortened
    [0x80, 0x80, 0x40], // frame_03: edge view
    [0x40, 0x40, 0x40], // frame_04: thin edge (dark)
    [0x80, 0x80, 0x80], // frame_05: edge opening to cruz
    [0xC0, 0xC0, 0xC0], // frame_06: full cruz (silver)
    [0xA0, 0xA0, 0xA0], // frame_07: cruz tilting
    [0x80, 0x80, 0x80], // frame_08: cruz foreshortened
    [0x40, 0x40, 0x40], // frame_09: thin edge (dark)
    [0x80, 0x80, 0x40], // frame_10: edge opening to cara
    [0xFF, 0xD7, 0x00], // frame_11: full cara again (gold)
  ];

  for (var i = 0; i < frameColors.length; i++) {
    final name = 'frame_${i.toString().padLeft(2, '0')}.png';
    _writePng(
      '$base/assets/coin/flip_sequence/$name',
      300,
      300,
      frameColors[i],
    );
  }

  print('Generated 14 placeholder PNGs (2 faces + 12 frames)');
}

void _writePng(String path, int width, int height, List<int> rgb) {
  final file = File(path);
  file.createSync(recursive: true);

  final out = BytesBuilder();

  // PNG signature
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_uint32(width));
  ihdr.add(_uint32(height));
  ihdr.add([8, 2, 0, 0, 0]); // 8-bit RGB, no interlace
  _writeChunk(out, 'IHDR', ihdr.toBytes());

  // IDAT chunk — uncompressed deflate with raw image data
  final rawRows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rawRows.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      rawRows.add(rgb);
    }
  }
  final rawData = rawRows.toBytes();

  // Wrap in zlib (deflate with no compression)
  final zlib = BytesBuilder();
  zlib.add([0x78, 0x01]); // zlib header (CM=8, CINFO=7, no dict, FLEVEL=0)

  // Split into 65535-byte deflate blocks
  var offset = 0;
  while (offset < rawData.length) {
    final remaining = rawData.length - offset;
    final blockSize = remaining > 65535 ? 65535 : remaining;
    final isLast = (offset + blockSize) >= rawData.length;
    zlib.addByte(isLast ? 0x01 : 0x00); // BFINAL + BTYPE=00
    zlib.add([blockSize & 0xFF, (blockSize >> 8) & 0xFF]);
    zlib.add([(~blockSize) & 0xFF, ((~blockSize) >> 8) & 0xFF]);
    zlib.add(rawData.sublist(offset, offset + blockSize));
    offset += blockSize;
  }

  // Adler-32 checksum
  var a = 1, b = 0;
  for (final byte in rawData) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  zlib.add(_uint32((b << 16) | a));

  _writeChunk(out, 'IDAT', zlib.toBytes());

  // IEND chunk
  _writeChunk(out, 'IEND', Uint8List(0));

  file.writeAsBytesSync(out.toBytes());
}

Uint8List _uint32(int value) {
  return Uint8List(4)
    ..[0] = (value >> 24) & 0xFF
    ..[1] = (value >> 16) & 0xFF
    ..[2] = (value >> 8) & 0xFF
    ..[3] = value & 0xFF;
}

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  out.add(_uint32(data.length));
  final typeBytes = Uint8List.fromList(type.codeUnits);
  out.add(typeBytes);
  out.add(data);
  // CRC32 over type + data
  final crcInput = BytesBuilder();
  crcInput.add(typeBytes);
  crcInput.add(data);
  out.add(_uint32(_crc32(crcInput.toBytes())));
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
```

Then generate the assets:

```bash
dart run generate_placeholders.dart
```

This creates 14 PNG files total: `cara.png`, `cruz.png`, and `frame_00.png` through `frame_11.png`.

### `assets/README_ASSETS.md`

Create this file to document asset replacement for production:

```markdown
# Asset Replacement Guide — Cara o Cruz

## Overview

This folder contains placeholder PNGs for the coin flip animation. Replace them with final production artwork before release.

## File Structure

```
assets/coin/
├── cara/
│   └── cara.png          ← Static "heads" face (front of coin)
├── cruz/
│   └── cruz.png          ← Static "tails" face (back of coin)
└── flip_sequence/
    ├── frame_00.png      ← Full cara visible
    ├── frame_01.png      ← Cara tilting away
    ├── frame_02.png      ← Cara foreshortened
    ├── frame_03.png      ← Edge view (transitioning)
    ├── frame_04.png      ← Thin edge
    ├── frame_05.png      ← Edge opening to cruz
    ├── frame_06.png      ← Full cruz visible
    ├── frame_07.png      ← Cruz tilting away
    ├── frame_08.png      ← Cruz foreshortened
    ├── frame_09.png      ← Thin edge
    ├── frame_10.png      ← Edge opening to cara
    └── frame_11.png      ← Full cara visible (loop point)
```

## Specifications

| Property         | Requirement                          |
|------------------|--------------------------------------|
| Dimensions       | 300×300 px (1x), 600×600 px (2x), 900×900 px (3x) |
| Format           | PNG-24 with alpha transparency       |
| Color space      | sRGB                                 |
| Background       | Transparent (coin floats over app background) |

## Frame Count Recommendations

- **Minimum (current):** 12 frames — one full rotation. Acceptable for basic feel.
- **Recommended:** 24 frames — one full rotation at 24fps plays in exactly 1 second. Smooth motion.
- **Premium:** 36–48 frames — allows for ease-in/ease-out and blur on fast spin sections.

If you increase the frame count, maintain the naming convention: `frame_00.png` through `frame_NN.png` (zero-padded two digits). Update `CoinAnimationController` initialization with the new path list.

## Animation Sequence Logic

The frame sequence represents ONE full rotation (cara → edge → cruz → edge → cara). The controller loops through this sequence multiple times to simulate a coin spinning in the air, then stops on the appropriate frame:

- **frame_00** = cara fully visible (landing frame for "cara" result)
- **frame_06** (midpoint) = cruz fully visible (landing frame for "cruz" result)

## iOS Asset Density

For iOS deployment on modern devices, provide at minimum 2x and 3x variants. Place them using Flutter's density-aware naming:

```
assets/coin/flip_sequence/frame_00.png       ← 1x (300×300)
assets/coin/flip_sequence/2.0x/frame_00.png  ← 2x (600×600)
assets/coin/flip_sequence/3.0x/frame_00.png  ← 3x (900×900)
```

Flutter will automatically select the correct density at runtime.

## Performance Notes

- Keep individual frame PNGs under 100 KB each (compressed) for smooth playback.
- At 24fps with 24 frames, total animation memory for one rotation is ~2.4 MB uncompressed in RAM — well within iOS limits.
- Pre-cache frames on app startup using `precacheImage()` to avoid jank on first flip.
```

---

## 8. Dart Source Files

Create all files exactly as specified below.

### `lib/core/theme.dart`

```dart
import 'package:flutter/cupertino.dart';

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
```

---

### `lib/features/coin/coin_rng_service.dart`

```dart
import 'dart:math';

enum FlipResult { cara, cruz }

class CoinRngService {
  final Random _random = Random.secure();

  FlipResult flip() {
    return _random.nextBool() ? FlipResult.cara : FlipResult.cruz;
  }

  FlipResult getInitialFace() {
    return _random.nextBool() ? FlipResult.cara : FlipResult.cruz;
  }
}
```

---

### `lib/features/coin/coin_animation_controller.dart`

```dart
import 'dart:async';

enum CoinFace { cara, cruz }

enum AnimationState { idle, playing }

class CoinAnimationController {
  CoinAnimationController({
    required this.framePaths,
    required this.caraAssetPath,
    required this.cruzAssetPath,
    this.frameDuration = const Duration(milliseconds: 42),
  }) : assert(framePaths.isNotEmpty);

  final List<String> framePaths;
  final String caraAssetPath;
  final String cruzAssetPath;

  /// Duration per frame — defaults to ~24fps (42ms).
  final Duration frameDuration;

  int _currentFrameIndex = 0;
  int get currentFrameIndex => _currentFrameIndex;

  AnimationState _state = AnimationState.idle;
  AnimationState get state => _state;

  String get currentAssetPath {
    if (_state == AnimationState.idle && _landedFace != null) {
      return _landedFace == CoinFace.cara ? caraAssetPath : cruzAssetPath;
    }
    return framePaths[_currentFrameIndex];
  }

  CoinFace? _landedFace;
  CoinFace? get landedFace => _landedFace;

  Timer? _timer;

  void Function(int frameIndex)? onFrameChanged;
  void Function(CoinFace result)? onComplete;

  void play(CoinFace result, {int fullRotations = 3}) {
    if (_state == AnimationState.playing) return;

    _state = AnimationState.playing;
    _landedFace = null;

    final totalFrames = framePaths.length * fullRotations;

    final midpoint = framePaths.length ~/ 2;
    final landingFrame = result == CoinFace.cara ? 0 : midpoint;

    var elapsed = 0;
    _currentFrameIndex = 0;

    _timer = Timer.periodic(frameDuration, (timer) {
      elapsed++;
      _currentFrameIndex = elapsed % framePaths.length;
      onFrameChanged?.call(_currentFrameIndex);

      if (elapsed >= totalFrames) {
        _currentFrameIndex = landingFrame;
        _state = AnimationState.idle;
        _landedFace = result;
        timer.cancel();
        _timer = null;
        onFrameChanged?.call(_currentFrameIndex);
        onComplete?.call(result);
      }
    });
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _currentFrameIndex = 0;
    _state = AnimationState.idle;
    _landedFace = null;
    onFrameChanged?.call(_currentFrameIndex);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
```

---

### `lib/features/history/history_repository.dart`

```dart
import 'package:hive/hive.dart';

class FlipRecord {
  const FlipRecord({required this.result, required this.timestamp});

  final String result;
  final DateTime timestamp;

  String encode() => '${timestamp.millisecondsSinceEpoch}|$result';

  static FlipRecord decode(String raw) {
    final parts = raw.split('|');
    return FlipRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[0])),
      result: parts[1],
    );
  }
}

class HistoryRepository {
  static const _boxName = 'flip_history';
  static const _maxEntries = 5;

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> saveFlip(String result) async {
    final record = FlipRecord(result: result, timestamp: DateTime.now());
    await _box.add(record.encode());

    while (_box.length > _maxEntries) {
      await _box.deleteAt(0);
    }
  }

  List<FlipRecord> getLastFive() {
    return _box.values
        .map(FlipRecord.decode)
        .toList()
        .reversed
        .toList();
  }
}
```

---

### `lib/features/history/history_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  throw UnimplementedError('Must be overridden at app startup');
});

final historyProvider = StateNotifierProvider<HistoryNotifier, List<FlipRecord>>((ref) {
  return HistoryNotifier(ref.watch(historyRepositoryProvider));
});

class HistoryNotifier extends StateNotifier<List<FlipRecord>> {
  HistoryNotifier(this._repo) : super(_repo.getLastFive());

  final HistoryRepository _repo;

  Future<void> recordFlip(String result) async {
    await _repo.saveFlip(result);
    state = _repo.getLastFive();
  }
}
```

---

### `lib/features/coin/coin_state.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../history/history_provider.dart';
import 'coin_rng_service.dart';

enum CoinStatus { idle, flipping, result }

class CoinState {
  const CoinState({this.status = CoinStatus.idle, this.lastResult});

  final CoinStatus status;
  final FlipResult? lastResult;

  CoinState copyWith({CoinStatus? status, FlipResult? lastResult}) {
    return CoinState(
      status: status ?? this.status,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class CoinStateNotifier extends StateNotifier<CoinState> {
  CoinStateNotifier({
    CoinRngService? rngService,
    this.historyNotifier,
  })  : _rngService = rngService ?? CoinRngService(),
        super(const CoinState());

  final CoinRngService _rngService;
  final HistoryNotifier? historyNotifier;
  FlipResult? _pendingResult;

  FlipResult? get pendingResult => _pendingResult;

  void startFlip() {
    if (state.status == CoinStatus.flipping) return;
    _pendingResult = _rngService.flip();
    state = state.copyWith(status: CoinStatus.flipping);
  }

  void resolveFlip() {
    if (state.status != CoinStatus.flipping || _pendingResult == null) return;
    final result = _pendingResult!;
    state = CoinState(status: CoinStatus.result, lastResult: result);
    _pendingResult = null;

    final resultStr = result == FlipResult.cara ? 'cara' : 'cruz';
    historyNotifier?.recordFlip(resultStr);
  }

  void reset() {
    _pendingResult = null;
    state = const CoinState();
  }
}

final coinStateProvider =
    StateNotifierProvider<CoinStateNotifier, CoinState>((ref) {
  final history = ref.watch(historyProvider.notifier);
  return CoinStateNotifier(historyNotifier: history);
});
```

---

### `lib/features/coin/coin_screen.dart`

```dart
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../history/history_provider.dart';
import '../history/history_repository.dart';
import 'coin_animation_controller.dart';
import 'coin_rng_service.dart';
import 'coin_state.dart';

const _framePaths = [
  'assets/coin/flip_sequence/frame_00.png',
  'assets/coin/flip_sequence/frame_01.png',
  'assets/coin/flip_sequence/frame_02.png',
  'assets/coin/flip_sequence/frame_03.png',
  'assets/coin/flip_sequence/frame_04.png',
  'assets/coin/flip_sequence/frame_05.png',
  'assets/coin/flip_sequence/frame_06.png',
  'assets/coin/flip_sequence/frame_07.png',
  'assets/coin/flip_sequence/frame_08.png',
  'assets/coin/flip_sequence/frame_09.png',
  'assets/coin/flip_sequence/frame_10.png',
  'assets/coin/flip_sequence/frame_11.png',
];

const _caraAssetPath = 'assets/coin/cara/cara.png';
const _cruzAssetPath = 'assets/coin/cruz/cruz.png';

CoinFace _toCoinFace(FlipResult result) {
  return result == FlipResult.cara ? CoinFace.cara : CoinFace.cruz;
}

class CoinScreen extends ConsumerStatefulWidget {
  const CoinScreen({super.key});

  @override
  ConsumerState<CoinScreen> createState() => _CoinScreenState();
}

class _CoinScreenState extends ConsumerState<CoinScreen> {
  late final CoinAnimationController _animController;
  late final FlipResult _initialFace;
  String _displayedAsset = _caraAssetPath;

  @override
  void initState() {
    super.initState();
    _initialFace = CoinRngService().getInitialFace();
    _displayedAsset = _initialFace == FlipResult.cara
        ? _caraAssetPath
        : _cruzAssetPath;

    _animController = CoinAnimationController(
      framePaths: _framePaths,
      caraAssetPath: _caraAssetPath,
      cruzAssetPath: _cruzAssetPath,
    );

    _animController.onFrameChanged = (_) {
      setState(() {
        _displayedAsset = _animController.currentAssetPath;
      });
    };

    _animController.onComplete = (_) {
      ref.read(coinStateProvider.notifier).resolveFlip();
    };
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleFlip() {
    final status = ref.read(coinStateProvider).status;
    if (status != CoinStatus.idle && status != CoinStatus.result) return;

    final notifier = ref.read(coinStateProvider.notifier);
    notifier.startFlip();

    final pending = notifier.pendingResult;
    if (pending != null) {
      _animController.play(_toCoinFace(pending));
    }
  }

  @override
  Widget build(BuildContext context) {
    final coinState = ref.watch(coinStateProvider);
    final history = ref.watch(historyProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final coinSize = screenWidth * 0.6;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _handleFlip,
                      onVerticalDragEnd: (details) {
                        if (details.velocity.pixelsPerSecond.dy < -100) {
                          _handleFlip();
                        }
                      },
                      child: SizedBox(
                        width: coinSize,
                        height: coinSize,
                        child: Image.asset(
                          _displayedAsset,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (coinState.status == CoinStatus.result &&
                        coinState.lastResult != null)
                      _GlassLabel(
                        text: coinState.lastResult == FlipResult.cara
                            ? 'CARA'
                            : 'CRUZ',
                      ),
                  ],
                ),
              ),
            ),
            if (history.isNotEmpty)
              _HistoryRow(records: history),
          ],
        ),
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.records});

  final List<FlipRecord> records;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.systemGrey.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: records.map((r) => _HistoryChip(record: r)).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({required this.record});

  final FlipRecord record;

  @override
  Widget build(BuildContext context) {
    final label = record.result == 'cara' ? 'CARA' : 'CRUZ';
    final time = DateFormat.Hm().format(record.timestamp);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: CupertinoColors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: CupertinoColors.systemGrey2.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
```

---

### `lib/features/widget/coin_widget_service.dart`

```dart
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
```

---

### `lib/main.dart`

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/theme.dart';
import 'features/coin/coin_screen.dart';
import 'features/history/history_provider.dart';
import 'features/history/history_repository.dart';

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
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CoinScreen(),
    );
  }
}
```

---

## 9. Tests

### `test/coin_rng_service_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cara_o_cruz/features/coin/coin_rng_service.dart';
import 'package:cara_o_cruz/features/coin/coin_state.dart';

void main() {
  group('CoinRngService', () {
    late CoinRngService service;

    setUp(() {
      service = CoinRngService();
    });

    test('distribution: 1000 flips land between 40-60% for each side', () {
      var caraCount = 0;
      for (var i = 0; i < 1000; i++) {
        if (service.flip() == FlipResult.cara) caraCount++;
      }
      final caraPercent = caraCount / 1000;
      expect(caraPercent, greaterThanOrEqualTo(0.40));
      expect(caraPercent, lessThanOrEqualTo(0.60));
    });

    test('getInitialFace returns a valid FlipResult', () {
      final face = service.getInitialFace();
      expect(face, isA<FlipResult>());
      expect(FlipResult.values.contains(face), isTrue);
    });
  });

  group('CoinStateNotifier', () {
    test('stores result before animation callback fires', () {
      final notifier = CoinStateNotifier();

      expect(notifier.state.status, CoinStatus.idle);
      expect(notifier.pendingResult, isNull);

      notifier.startFlip();

      // Result is determined immediately on startFlip, before resolveFlip
      expect(notifier.state.status, CoinStatus.flipping);
      expect(notifier.pendingResult, isNotNull);
      expect(
        FlipResult.values.contains(notifier.pendingResult),
        isTrue,
      );

      // Simulate animation completion
      final determined = notifier.pendingResult;
      notifier.resolveFlip();

      expect(notifier.state.status, CoinStatus.result);
      expect(notifier.state.lastResult, determined);
      expect(notifier.pendingResult, isNull);
    });
  });
}
```

---

### `test/widget_test.dart`

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cara_o_cruz/features/coin/coin_screen.dart';
import 'package:cara_o_cruz/features/history/history_provider.dart';
import 'package:cara_o_cruz/features/history/history_repository.dart';

class FakeHistoryRepository extends HistoryRepository {
  final List<String> _entries = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> saveFlip(String result) async {
    _entries.add('${DateTime.now().millisecondsSinceEpoch}|$result');
    if (_entries.length > 5) _entries.removeAt(0);
  }

  @override
  List<FlipRecord> getLastFive() {
    return _entries.map(FlipRecord.decode).toList().reversed.toList();
  }
}

void main() {
  testWidgets('CoinScreen builds without errors', (WidgetTester tester) async {
    final fakeRepo = FakeHistoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const CupertinoApp(home: CoinScreen()),
      ),
    );

    expect(find.byType(CoinScreen), findsOneWidget);
  });
}
```

---

## 10. Run & Verify

```bash
# Get dependencies
flutter pub get

# Generate placeholder assets (if not done yet)
dart run generate_placeholders.dart

# Static analysis — should produce zero issues
flutter analyze

# Unit + widget tests
flutter test

# Run on a connected device / simulator
flutter run

# Run on Windows desktop
flutter run -d windows
```

---

## 11. Architecture Summary

```
main.dart
│  Initializes Hive, creates HistoryRepository, wraps app in ProviderScope
│
├── CaraOCruzApp  (CupertinoApp, dark theme, locale: es)
│   └── CoinScreen  (ConsumerStatefulWidget)
│       ├── CoinAnimationController  — Timer-based 12-frame sprite sequencer
│       │     play(CoinFace, fullRotations: 3) → fires onFrameChanged each tick
│       │     onComplete → triggers CoinStateNotifier.resolveFlip()
│       │
│       ├── CoinStateNotifier  (StateNotifier<CoinState>)
│       │     startFlip()  → samples RNG immediately → status: flipping
│       │     resolveFlip() → status: result → writes to HistoryNotifier
│       │
│       ├── CoinRngService  — Random.secure() for true randomness
│       │
│       ├── HistoryNotifier  (StateNotifier<List<FlipRecord>>)
│       │     recordFlip() → saves to HistoryRepository → updates state
│       │
│       └── HistoryRepository  — Hive Box<String>, max 5 entries, FIFO eviction
│
└── CoinWidgetService  — home_widget bridge for iOS home-screen widget (stubbed)
```

### Key design decisions

| Decision | Rationale |
|----------|-----------|
| Result determined in `startFlip()`, not `resolveFlip()` | Prevents result from changing after animation starts; coin always lands on what was decided. |
| `CoinAnimationController` uses `Timer.periodic` not Flutter's `AnimationController` | No `TickerProvider` required; works in unit tests without a widget tree. |
| `HistoryRepository` injected via Riverpod provider override at startup | Allows `FakeHistoryRepository` in tests without touching Hive. |
| `CupertinoApp` (not `MaterialApp`) | iOS-native look and feel is the design target. |
| `gaplessPlayback: true` on `Image.asset` | Prevents white-flash between animation frames. |

---

## 12. Dependency Notes

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.6.1 | State management (StateNotifier pattern) |
| `hive` | ^2.2.3 | Local key-value storage for flip history |
| `hive_flutter` | ^1.1.0 | Flutter-specific Hive init helpers |
| `intl` | any | `DateFormat.Hm()` for history timestamps |
| `home_widget` | ^0.7.0 | iOS/Android home-screen widget bridge |
| `flutter_localizations` | sdk | Cupertino locale support for Spanish |

> **Note:** `home_widget` requires additional native configuration (App Groups on iOS, AppWidgetProvider on Android) to display an actual home-screen widget. The `CoinWidgetService` class is wired up but the native widget extension is not part of this Flutter project — it would be added as a separate Xcode extension target.

---

## 13. Checklist for a Clean Recreation

- [ ] Flutter SDK ≥ 3.24 installed, `flutter doctor` shows no blocking issues
- [ ] Project created with `flutter create --org com.caracruz --project-name cara_o_cruz`
- [ ] `pubspec.yaml` replaced exactly as in §4
- [ ] `flutter pub get` runs without errors
- [ ] All `lib/` files created as in §8
- [ ] All `test/` files created as in §9
- [ ] `generate_placeholders.dart` created and run (`dart run generate_placeholders.dart`)
- [ ] `assets/README_ASSETS.md` created
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all tests pass
- [ ] App launches on target platform and coin flips correctly

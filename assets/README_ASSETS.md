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

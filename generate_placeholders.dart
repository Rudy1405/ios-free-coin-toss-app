import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Generates the placeholder PNG art for the coin's 36-frame flip sequence,
/// written by hand (no `image` package) so this script can run standalone
/// via `dart run` outside the Flutter SDK — see Gotchas in CLAUDE.md.
///
/// `cara.png` and `cruz.png` are real curated art (see assets_ref/coins/)
/// and are intentionally NOT written by this script anymore — re-running it
/// must never clobber them.
///
/// Each PNG is a transparent-background RGBA circle shaded like a metal
/// coin (offset highlight + rim shadow + a soft drop shadow underneath).
/// The 36 flip frames get a progressive vertical squish (`|cos(angle)|`,
/// one 10° step per frame) to fake the coin tumbling end-over-end through
/// the air, and their base color blends from cara to cruz and back across
/// that same angle.
///
/// To soften the jump between these low-detail procedural frames and the
/// high-detail static faces they crossfade with in `coin_screen.dart`, each
/// frame also gets a vertical motion blur + slight alpha fade proportional
/// to `|sin(angle)|` — i.e. near-zero at the full-face poses (frame_00,
/// frame_18) where detail matters and the crossfade happens, ramping up
/// through the edge-on poses where the coin is moving fastest and a thin
/// sliver anyway, so the blur reads as speed rather than as missing detail.
///
/// Colors must match `CoinPalette` in lib/core/theme.dart — this script
/// can't import Flutter code, so the hex values are duplicated here on
/// purpose. See public_rag/app_look_feel.md.

const _caraColor = [0xD6, 0xAD, 0x60]; // CoinPalette.cara.accent
const _cruzColor = [0x7B, 0x7B, 0xEA]; // CoinPalette.cruz.accent

const _canvasSize = 300;
const _frameCount = 36;
const _maxBlurPx = 9;

void main() {
  final base = Directory.current.path;

  for (var i = 0; i < _frameCount; i++) {
    final angle = i * 2 * math.pi / _frameCount; // 10° per frame, 360° total
    final squish = _clampD(math.cos(angle).abs(), 0.08, 1.0);
    final colorT = (1 - math.cos(angle)) / 2; // 0 = cara, 1 = cruz
    final edgeShade = 0.55 + 0.45 * squish; // the thin edge sits in shadow
    final speedT = math.sin(angle).abs(); // 0 = full-face, 1 = edge-on

    final frameColor = _lerpRgb(_caraColor, _cruzColor, colorT)
        .map((c) => _clampI((c * edgeShade).round(), 0, 255))
        .toList();

    final name = 'frame_${i.toString().padLeft(2, '0')}.png';
    _writeCoin(
      '$base/assets/coin/flip_sequence/$name',
      frameColor,
      squish,
      blurRadius: (speedT * _maxBlurPx).round(),
      speedFade: speedT,
    );
  }

  // ignore: avoid_print
  print(
    'Generated $_frameCount placeholder flip-sequence PNGs '
    '(cara.png/cruz.png are real art and were left untouched).',
  );
}

/// Draws a shaded metallic circle (squished vertically by [squish], 1.0 =
/// full face-on) with a soft drop shadow, on a transparent canvas. The
/// vertical squish simulates a coin tumbling end-over-end through the air
/// (as opposed to spinning flat like a top, which would squish sideways).
///
/// [blurRadius] applies a vertical motion blur (0 = none) and [speedFade]
/// (0..1) slightly lowers the coin's alpha — both simulate the coin moving
/// too fast to see clearly, see the file-level doc comment.
void _writeCoin(
  String path,
  List<int> baseColor,
  double squish, {
  int blurRadius = 0,
  double speedFade = 0.0,
}) {
  const size = _canvasSize;
  final pixels = Uint8List(size * size * 4);

  const cx = size / 2, cy = size / 2;
  const r = size * 0.42;
  const rx = r;
  final ry = r * squish;

  final highlight = _lighten(baseColor, 0.55);
  final shadow = _darken(baseColor, 0.55);
  final rim = _darken(baseColor, 0.75);

  const shadowCx = cx;
  final shadowCy = cy + ry; // just under the coin's rim
  const shadowRx = rx * 0.75;
  const shadowRy = r * 0.13;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var out = const [0, 0, 0, 0];

      // Soft drop shadow underneath, composited first.
      final sdx = (x - shadowCx) / shadowRx;
      final sdy = (y - shadowCy) / shadowRy;
      final shadowDist = math.sqrt(sdx * sdx + sdy * sdy);
      if (shadowDist < 1.0) {
        final falloff = 1 - shadowDist;
        final a = _clampI((falloff * falloff * 110).round(), 0, 110);
        out = _over([0, 0, 0, a], out);
      }

      // Coin sphere on top.
      final nx = (x - cx) / rx;
      final ny = (y - cy) / ry;
      final dist = math.sqrt(nx * nx + ny * ny);
      const edgeBand = 0.035;
      double alpha;
      if (dist <= 1 - edgeBand) {
        alpha = 1.0;
      } else if (dist >= 1 + edgeBand) {
        alpha = 0.0;
      } else {
        alpha = (1 + edgeBand - dist) / (2 * edgeBand);
      }
      alpha *= (1 - speedFade * 0.22);

      if (alpha > 0) {
        // Offset highlight (upper-left light source) fading through the
        // base color into a darker rim, like a brushed-metal sphere.
        const hlx = -0.35, hly = -0.4;
        final dHi =
            math.sqrt((nx - hlx) * (nx - hlx) + (ny - hly) * (ny - hly));
        final t = _clampD(dHi / 1.5, 0.0, 1.0);
        var shaded = t < 0.5
            ? _lerpRgb(highlight, baseColor, t / 0.5)
            : _lerpRgb(baseColor, shadow, (t - 0.5) / 0.5);

        final rimAmt = _clampD((dist - 0.72) / 0.28, 0.0, 1.0) * 0.5;
        shaded = _lerpRgb(shaded, rim, rimAmt);

        out = _over([...shaded, (alpha * 255).round()], out);
      }

      final idx = (y * size + x) * 4;
      pixels[idx] = out[0];
      pixels[idx + 1] = out[1];
      pixels[idx + 2] = out[2];
      pixels[idx + 3] = out[3];
    }
  }

  final finalPixels = _verticalBoxBlur(pixels, size, blurRadius);
  _writePngRGBA(path, size, size, finalPixels);
}

/// Vertical box blur over an RGBA buffer, averaging in premultiplied-alpha
/// space so transparent neighbors don't bleed black into the coin's edge.
/// No-op when [radius] is 0.
Uint8List _verticalBoxBlur(Uint8List pixels, int size, int radius) {
  if (radius <= 0) return pixels;

  final out = Uint8List(pixels.length);
  for (var x = 0; x < size; x++) {
    for (var y = 0; y < size; y++) {
      var rSum = 0, gSum = 0, bSum = 0, aSum = 0, count = 0;
      for (var k = -radius; k <= radius; k++) {
        final sy = y + k;
        if (sy < 0 || sy >= size) continue;
        final idx = (sy * size + x) * 4;
        final a = pixels[idx + 3];
        rSum += pixels[idx] * a;
        gSum += pixels[idx + 1] * a;
        bSum += pixels[idx + 2] * a;
        aSum += a;
        count++;
      }
      final idx = (y * size + x) * 4;
      final outAlpha = count == 0 ? 0 : (aSum / count).round();
      if (aSum == 0) {
        out[idx] = 0;
        out[idx + 1] = 0;
        out[idx + 2] = 0;
        out[idx + 3] = 0;
      } else {
        out[idx] = _clampI((rSum / aSum).round(), 0, 255);
        out[idx + 1] = _clampI((gSum / aSum).round(), 0, 255);
        out[idx + 2] = _clampI((bSum / aSum).round(), 0, 255);
        out[idx + 3] = _clampI(outAlpha, 0, 255);
      }
    }
  }
  return out;
}

/// Alpha "source-over" compositing of [fg] over [bg], both [r, g, b, a].
List<int> _over(List<int> fg, List<int> bg) {
  final fa = fg[3] / 255.0;
  final ba = bg[3] / 255.0;
  final oa = fa + ba * (1 - fa);
  if (oa <= 0) return const [0, 0, 0, 0];
  final r =
      _clampI(((fg[0] * fa + bg[0] * ba * (1 - fa)) / oa).round(), 0, 255);
  final g =
      _clampI(((fg[1] * fa + bg[1] * ba * (1 - fa)) / oa).round(), 0, 255);
  final b =
      _clampI(((fg[2] * fa + bg[2] * ba * (1 - fa)) / oa).round(), 0, 255);
  return [r, g, b, _clampI((oa * 255).round(), 0, 255)];
}

List<int> _lighten(List<int> rgb, double amt) => [
      _clampI((rgb[0] + (255 - rgb[0]) * amt).round(), 0, 255),
      _clampI((rgb[1] + (255 - rgb[1]) * amt).round(), 0, 255),
      _clampI((rgb[2] + (255 - rgb[2]) * amt).round(), 0, 255),
    ];

List<int> _darken(List<int> rgb, double amt) => [
      _clampI((rgb[0] * (1 - amt)).round(), 0, 255),
      _clampI((rgb[1] * (1 - amt)).round(), 0, 255),
      _clampI((rgb[2] * (1 - amt)).round(), 0, 255),
    ];

List<int> _lerpRgb(List<int> a, List<int> b, double t) => [
      _clampI((a[0] + (b[0] - a[0]) * t).round(), 0, 255),
      _clampI((a[1] + (b[1] - a[1]) * t).round(), 0, 255),
      _clampI((a[2] + (b[2] - a[2]) * t).round(), 0, 255),
    ];

double _clampD(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

int _clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

void _writePngRGBA(String path, int width, int height, Uint8List rgbaPixels) {
  final file = File(path);
  file.createSync(recursive: true);

  final out = BytesBuilder();

  // PNG signature
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  ihdr.add(_uint32(width));
  ihdr.add(_uint32(height));
  ihdr.add([8, 6, 0, 0, 0]); // 8-bit RGBA, no interlace
  _writeChunk(out, 'IHDR', ihdr.toBytes());

  // IDAT chunk — uncompressed deflate with raw image data
  final rawRows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rawRows.addByte(0); // filter: none
    final rowStart = y * width * 4;
    rawRows.add(rgbaPixels.sublist(rowStart, rowStart + width * 4));
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

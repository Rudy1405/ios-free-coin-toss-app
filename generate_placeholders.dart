import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Generates placeholder PNG art for the coin: two static faces (cara/cruz)
/// and a 12-frame flip sequence, written by hand (no `image` package) so
/// this script can run standalone via `dart run` outside the Flutter SDK —
/// see Gotchas in CLAUDE.md.
///
/// Each PNG is a transparent-background RGBA circle shaded like a metal
/// coin (offset highlight + rim shadow + a soft drop shadow underneath).
/// The 12 flip frames get a progressive horizontal squish
/// (`|cos(angle)|`, one 30° step per frame) to fake the coin turning
/// edge-on as it spins, and their base color blends from cara to cruz and
/// back across that same angle.
///
/// Colors must match `CoinPalette` in lib/core/theme.dart — this script
/// can't import Flutter code, so the hex values are duplicated here on
/// purpose. See public_rag/app_look_feel.md.

const _caraColor = [0xD6, 0xAD, 0x60]; // CoinPalette.cara.accent
const _cruzColor = [0x8F, 0xA3, 0xC2]; // CoinPalette.cruz.accent

const _canvasSize = 300;
const _frameCount = 12;

void main() {
  final base = Directory.current.path;

  _writeCoin('$base/assets/coin/cara/cara.png', _caraColor, 1.0);
  _writeCoin('$base/assets/coin/cruz/cruz.png', _cruzColor, 1.0);

  for (var i = 0; i < _frameCount; i++) {
    final angle = i * math.pi / 6; // 30° per frame, 360° over the sequence
    final squishX = _clampD(math.cos(angle).abs(), 0.08, 1.0);
    final colorT = (1 - math.cos(angle)) / 2; // 0 = cara, 1 = cruz
    final edgeShade = 0.55 + 0.45 * squishX; // the thin edge sits in shadow

    final frameColor = _lerpRgb(_caraColor, _cruzColor, colorT)
        .map((c) => _clampI((c * edgeShade).round(), 0, 255))
        .toList();

    final name = 'frame_${i.toString().padLeft(2, '0')}.png';
    _writeCoin('$base/assets/coin/flip_sequence/$name', frameColor, squishX);
  }

  // ignore: avoid_print
  print('Generated 14 placeholder coin PNGs (2 faces + 12 flip frames)');
}

/// Draws a shaded metallic circle (squished horizontally by [squishX], 1.0
/// = full face-on) with a soft drop shadow, on a transparent canvas.
void _writeCoin(String path, List<int> baseColor, double squishX) {
  const size = _canvasSize;
  final pixels = Uint8List(size * size * 4);

  const cx = size / 2, cy = size / 2;
  const r = size * 0.42;
  final rx = r * squishX;
  const ry = r;

  final highlight = _lighten(baseColor, 0.55);
  final shadow = _darken(baseColor, 0.55);
  final rim = _darken(baseColor, 0.75);

  const shadowCx = cx, shadowCy = cy + ry; // just under the coin's rim
  final shadowRx = math.max(rx * 0.75, r * 0.10);
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

  _writePngRGBA(path, size, size, pixels);
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

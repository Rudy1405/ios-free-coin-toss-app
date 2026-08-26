import 'dart:io';
import 'dart:typed_data';

/// Generates minimal placeholder PNG files for the coin flip animation.
/// Each file is a 300x300 solid-color PNG with no text (text would require
/// a full font renderer). Files are color-coded for easy identification:
/// - cara: metallic gold (#D6AD60) — paleta P1 "Oro y Grafito"
/// - cruz: metallic blue-silver (#8FA3C2) — paleta P2 "Plata Azulada"
/// - flip frames: gradient from gold to blue-silver and back
///
/// Estos hex deben coincidir con CoinPalette en lib/core/theme.dart y con
/// public_rag/app_look_feel.md — este script no puede importar ese archivo
/// porque corre con `dart run` fuera del SDK de Flutter.

void main() {
  final base = Directory.current.path;

  // Generate cara face (metallic gold)
  _writePng('$base/assets/coin/cara/cara.png', 300, 300, [0xD6, 0xAD, 0x60]);

  // Generate cruz face (metallic blue-silver)
  _writePng('$base/assets/coin/cruz/cruz.png', 300, 300, [0x8F, 0xA3, 0xC2]);

  // Generate 12 flip frames with color transition
  // Simulates: cara(gold) -> edge(thin/dark) -> cruz(blue-silver) -> edge -> cara
  final frameColors = <List<int>>[
    [0xD6, 0xAD, 0x60], // frame_00: full cara (metallic gold)
    [0xB8, 0x95, 0x52], // frame_01: cara tilting
    [0x8C, 0x76, 0x40], // frame_02: cara foreshortened
    [0x5C, 0x5C, 0x58], // frame_03: edge view
    [0x3A, 0x3A, 0x3C], // frame_04: thin edge (dark)
    [0x5C, 0x66, 0x70], // frame_05: edge opening to cruz
    [0x8F, 0xA3, 0xC2], // frame_06: full cruz (metallic blue-silver)
    [0x78, 0x90, 0xAC], // frame_07: cruz tilting
    [0x5F, 0x75, 0x90], // frame_08: cruz foreshortened
    [0x3A, 0x3A, 0x3C], // frame_09: thin edge (dark)
    [0x5C, 0x58, 0x50], // frame_10: edge opening to cara
    [0xD6, 0xAD, 0x60], // frame_11: full cara again (metallic gold)
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

  // ignore: avoid_print
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

import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:lzf/lzf.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LZFEncoder', () {
    test('does not compress data smaller than 16 bytes', () {
      final data = Uint8List.fromList([
        1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 97, 98, 99, //
      ]);
      final encoded = LZFEncoder.encode(data);
      check(
        encoded.length,
      ).equals(data.length + LZFChunk.headerLengthUncompressed);
      check(encoded).deepEquals(
        Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeUncompressed,
          0,
          data.length, // uncompressed length
          ...data, // uncompressed data
        ]),
      );
    });

    test('does not compress data if compression does not yield a saving of at '
        'least 2 bytes', () {
      final data = Uint8List.fromList([
        1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 97, 98, 99, 100, 0, 0, 9, //
      ]);
      final encoded = LZFEncoder.encode(data);
      check(
        encoded.length,
      ).equals(data.length + LZFChunk.headerLengthUncompressed);
      check(encoded).deepEquals(
        Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeUncompressed,
          0,
          data.length, // uncompressed length
          ...data, // uncompressed data
        ]),
      );
    });

    test('compresses data if it is larger than 16 bytes and compression yields '
        'a saving of at least 2 bytes', () {
      final data = Uint8List.fromList([
        1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 97, 98, 99, 100, 0, 0, 9, //
        97, 98, 99, 100,
      ]);
      final encoded = LZFEncoder.encode(data);
      check(encoded.length).equals(19 + LZFChunk.headerLengthCompressed);
      check(encoded).deepEquals(
        Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeCompressed,
          0,
          19, // compressed length
          0,
          data.length, // uncompressed length
          // compressed data
          11, 1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 224, 0, 6, 1, 99, //
          100,
        ]),
      );
    });
  });
}

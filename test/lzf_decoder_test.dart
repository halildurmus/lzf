import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:lzf/lzf.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LZFDecoder', () {
    test('decodes uncompressed chunk', () {
      final data = [1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 97, 98, 99];
      final encoded = Uint8List.fromList([
        LZFChunk.byteZ,
        LZFChunk.byteV,
        LZFChunk.blockTypeUncompressed,
        0,
        data.length, // uncompressed length
        ...data, // uncompressed data
      ]);
      final decoded = LZFDecoder.decode(encoded);
      check(decoded.length).equals(data.length);
      check(decoded).deepEquals(data);
    });

    test('decodes compressed chunk', () {
      final data = [
        1, 0, 9, 1, 1, 97, 98, 99, 100, 0, 0, 9, 97, 98, 99, 100, 0, 0, 9, //
        97, 98, 99, 100,
      ];
      final encoded = Uint8List.fromList([
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
      ]);
      final decoded = LZFDecoder.decode(encoded);
      check(decoded.length).equals(data.length);
      check(decoded).deepEquals(data);
    });
  });
}

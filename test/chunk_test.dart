import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:lzf/lzf.dart';
import 'package:test/test.dart';

void main() {
  group('LZFChunk', () {
    test('default constructor throws assertion error for invalid chunk', () {
      final invalidData = Uint8List.fromList([0x00, 0x00, 0x00]);
      check(() => LZFChunk(invalidData)).throws<AssertionError>();
    });

    group('compressed', () {
      test('creates a compressed chunk', () {
        final data = Uint8List.fromList(List.filled(10, 0xAB));
        final chunk = LZFChunk.compressed(data, 20);
        check(chunk.length).equals(17);
        check(chunk.bytes.length).equals(17);
        check(LZFChunk.isValidChunk(chunk.bytes)).isTrue();
      });

      test('throws if data exceeds maxChunkLength', () {
        final largeData = Uint8List(LZFChunk.maxChunkLength + 1);
        check(
          () => LZFChunk.compressed(largeData, 70_000),
        ).throws<ArgumentError>();
      });
    });

    group('uncompressed', () {
      test('creates an uncompressed chunk', () {
        final data = Uint8List.fromList(List.filled(10, 0xCD));
        final chunk = LZFChunk.uncompressed(data);
        check(chunk.length).equals(15);
        check(chunk.bytes.length).equals(15);
        check(LZFChunk.isValidChunk(chunk.bytes)).isTrue();
      });

      test('throws if data exceeds maxChunkLength', () {
        final largeData = Uint8List(LZFChunk.maxChunkLength + 1);
        check(() => LZFChunk.uncompressed(largeData)).throws<ArgumentError>();
      });
    });

    test('copyTo copies bytes correctly', () {
      final data = Uint8List.fromList(List.filled(10, 0xEF));
      final chunk = LZFChunk.uncompressed(data);
      final destination = Uint8List(50);
      final offset = chunk.copyTo(destination, offset: 5);
      check(offset).equals(5 + chunk.length);
      check(destination.sublist(5, offset)).deepEquals(chunk.bytes);
    });

    test('toString returns expected output', () {
      final data = Uint8List.fromList(List.generate(20, (i) => i));
      final chunk = LZFChunk.uncompressed(data);
      final stringOutput = chunk.toString();
      check(stringOutput).equals(
        'LZFChunk(length: 25, bytes (first 10): [90, 86, 0, 0, 20, 0, 1, 2, 3, 4])',
      );
    });

    group('isValidChunk', () {
      test('returns true for valid compressed chunk', () {
        final compressedData = Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeCompressed,
          0x00,
          0x05, // Compressed length = 5
          0x00,
          0x10, // Uncompressed length = 16
          ...List.filled(5, 0xAB), // Sample data
        ]);
        check(LZFChunk.isValidChunk(compressedData)).isTrue();
      });

      test('returns true for valid uncompressed chunk', () {
        final uncompressedData = Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeUncompressed,
          0x00,
          0x08, // Uncompressed length = 8
          ...List.filled(8, 0xCD), // Sample data
        ]);
        check(LZFChunk.isValidChunk(uncompressedData)).isTrue();
      });

      test('returns false for invalid magic bytes', () {
        final invalidData = Uint8List.fromList([
          0x00, // Invalid first byte
          LZFChunk.byteV,
          LZFChunk.blockTypeCompressed,
          0x00,
          0x05,
          0x00,
          0x10,
          ...List.filled(5, 0xAB),
        ]);
        check(LZFChunk.isValidChunk(invalidData)).isFalse();
      });

      test('returns false for invalid block type', () {
        final invalidData = Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          0xFF, // Invalid block type
          0x00,
          0x05,
          0x00,
          0x10,
          ...List.filled(5, 0xAB),
        ]);
        check(LZFChunk.isValidChunk(invalidData)).isFalse();
      });

      test('returns false for data shorter than minimum header length', () {
        final shortData = Uint8List.fromList([
          LZFChunk.byteZ,
          LZFChunk.byteV,
          LZFChunk.blockTypeCompressed,
        ]);
        check(LZFChunk.isValidChunk(shortData)).isFalse();
      });
    });
  });
}

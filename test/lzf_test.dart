import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:lzf/lzf.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('LZF round-trip encode/decode', () {
    test('using sample files', () {
      // Load all files from test/data recursively.
      final files =
          Directory(
            'test/data',
          ).listSync(recursive: true).whereType<File>().toList();

      // Ensure we have files to test.
      check(
        files.isNotEmpty,
        because: 'No test files found in "test/data".',
      ).isTrue();

      for (final file in files) {
        final data = file.readAsBytesSync();
        final encoded = LZFEncoder.encode(data);
        final decoded = LZFDecoder.decode(encoded);
        // Check that the decoded output matches the original input.
        check(
          decoded.length,
          because: 'Decoded length did not match original for ${file.path}.',
        ).equals(data.length);
        check(
          decoded,
          because:
              'Decoded bytes differ from original data in file ${file.path}.',
        ).deepEquals(data);
      }
    });

    test('compressible single chunk', () {
      // Generate compressible data that fits into a single LZF chunk.
      final data = _generateCompressibleData(1000);
      final lzf = LZFEncoder.encode(data);
      final decoded = LZFDecoder.decode(lzf);
      // Check that the decoded output matches the original input.
      check(
        decoded.length,
        because:
            'Decoded length does not match original for compressible data.',
      ).equals(data.length);
      check(
        decoded,
        because: 'Decoded data does not equal original for compressible data.',
      ).deepEquals(data);
    });

    test('compressible multiple chunks', () {
      // Generate data larger than 256KB to force multiple chunks.
      final data = _generateCompressibleData(
        4 * LZFChunk.maxChunkLength + 4000,
      );
      final encoded = LZFEncoder.encode(data);
      final decoded = LZFDecoder.decode(encoded);
      // Check that the decoded output matches the original input.
      check(
        decoded.length,
        because:
            'Decoded length does not match original for compressible data.',
      ).equals(data.length);
      check(
        decoded,
        because: 'Decoded data does not equal original for compressible data.',
      ).deepEquals(data);
    });

    test('uncompressible single chunk', () {
      // Generate random data which is unlikely to compress.
      final data = _generateUncompressibleData(4000);
      final encoded = LZFEncoder.encode(data);
      final decoded = LZFDecoder.decode(encoded);
      // Check that the decoded output matches the original input.
      check(
        decoded.length,
        because:
            'Decoded length does not match original for uncompressible data.',
      ).equals(data.length);
      check(
        decoded,
        because:
            'Decoded data does not equal original for uncompressible data.',
      ).deepEquals(data);
    });
  });
}

/// Generates a byte list that is expected to compress effectively by filling
/// it with a repeating pattern of bytes.
Uint8List _generateCompressibleData(int length) {
  final random = math.Random(length);
  final bytes = BytesBuilder();

  while (bytes.length < length) {
    final n = random.nextInt(10);
    // Alternate between adding a fixed sequence and random small values.
    switch (n & 3) {
      case 0:
        bytes.add(_abcd);
      case 1:
        bytes.addByte(n);
      default:
        bytes.addByte((n >> 3) & 0x7);
    }
  }

  // Ensure the length is exactly as requested.
  if (bytes.length > length) return bytes.takeBytes().sublist(0, length);

  return bytes.takeBytes();
}

/// Generates a byte list that is not expected to compress effectively by
/// filling it with random values.
Uint8List _generateUncompressibleData(int length) {
  final result = Uint8List(length);
  final random = math.Random(length);
  for (var i = 0; i < length; i++) {
    result[i] = random.nextInt(256);
  }
  return result;
}

final _abcd = [97, 98, 99, 100];

import 'dart:math' as math;
import 'dart:typed_data';

import 'chunk.dart';

/// Encodes raw data into LZF chunks.
///
/// This encoder attempts to compress the input data if it's large enough (at
/// least `16` bytes) and if the compression ratio is good enough to yield
/// savings, and falls back to storing it uncompressed otherwise.
final class ChunkEncoder {
  /// Creates a [ChunkEncoder] with an internal hash table sized based on the
  /// provided [length].
  ///
  /// The [length] represents the size of the data that is expected to be
  /// processed.
  factory ChunkEncoder({required int length}) {
    final largestChunkLength = math.min(length, LZFChunk.maxChunkLength);
    final bufferLength =
        largestChunkLength +
        ((largestChunkLength + 31) >> 5) +
        LZFChunk.maxHeaderLength;
    final encodeBuffer = Uint8List(bufferLength);
    final suggestedHashSize = _calculateHashSize(largestChunkLength);
    final hashTable = List.filled(suggestedHashSize, 0);
    final hashModulo = suggestedHashSize - 1;
    return ChunkEncoder._(encodeBuffer, hashTable, hashModulo);
  }

  ChunkEncoder._(this._encodeBuffer, this._hashTable, this._hashModulo);

  /// Buffer in which encoded content is stored during processing.
  final Uint8List _encodeBuffer;

  /// Lookup table for 3-byte sequences.
  ///
  /// The key is a hash of a 3-byte sequence, and the value is an offset in the
  /// input buffer.
  final List<int> _hashTable;

  /// Mask used for modulo operations on the hash value.
  final int _hashModulo;

  /// Encodes [data] (from [offset] for an optional [length]) into a LZF chunk.
  ///
  /// If the input data is large enough (at least `16` bytes) and compression
  /// yields a saving of at least `2` bytes, the data is compressed. Otherwise,
  /// it is stored uncompressed.
  LZFChunk encode(Uint8List data, {int offset = 0, int? length}) {
    length ??= data.length;
    if (length >= minBlockToCompress) {
      final compressedLength = _tryCompress(
        data,
        offset,
        offset + length,
        _encodeBuffer,
        0,
      );
      // Check if compression was effective.
      if (compressedLength < (length - 2)) {
        final encodedData = Uint8List.sublistView(
          _encodeBuffer,
          0,
          compressedLength,
        );
        return LZFChunk.compressed(encodedData, length);
      }
    }

    // Fallback: store data uncompressed.
    return LZFChunk.uncompressed(
      Uint8List.sublistView(data, offset, offset + length),
    );
  }

  /// Attempts to compress the input data.
  ///
  /// The [input] is read from [inPosition] to [inEnd] and the compressed data
  /// is written to [output] starting at [outPosition].
  ///
  /// Returns the new output position after compression.
  int _tryCompress(
    Uint8List input,
    int inPosition,
    int inEnd,
    Uint8List output,
    int outPosition,
  ) {
    var inputPosition = inPosition;
    final firstPos = inputPosition;
    var outputPosition = outPosition;
    outputPosition++; // Reserve one byte for literal-length indicator.
    var seen = _first(input, inputPosition);
    var literals = 0;

    // Adjust the endpoint to ensure we have enough bytes for lookahead.
    final inputEnd = inEnd - _tailLength;

    while (inputPosition < inputEnd) {
      // Slide the window to include the next byte.
      final p2 = input[inputPosition + 2];
      seen = (seen << 8) + p2;
      final hashKey = _hash(seen);
      final ref = _hashTable[hashKey];
      _hashTable[hashKey] = inputPosition;

      // Check if a back-reference can be used.
      if (ref >= inputPosition ||
          (ref < firstPos) ||
          (inputPosition - ref) > _maxOff ||
          input[ref + 2] != p2 ||
          input[ref + 1] != ((seen >> 8) & 0xFF) ||
          input[ref] != ((seen >> 16) & 0xFF)) {
        // No match: output literal byte.
        output[outputPosition++] = input[inputPosition++];
        literals++;
        // If literal run reached its maximum, reset it.
        if (literals == LZFChunk.maxLiteral) {
          output[outputPosition - literals - 1] = LZFChunk.maxLiteral - 1;
          literals = 0;
          outputPosition++; // Reserve a new literal-length indicator.
        }
        continue;
      }

      // Found a match.
      var maxLen = inputEnd - inputPosition + 2;
      if (maxLen > _maxRef) {
        maxLen = _maxRef;
      }

      // Write out literal run length if any.
      if (literals != 0) {
        output[outputPosition - literals - 1] = literals - 1;
        literals = 0;
      } else {
        outputPosition--; // No literal indicator needed.
      }

      // Determine match length.
      var len = 3;
      while (len < maxLen && input[ref + len] == input[inputPosition + len]) {
        len++;
      }
      len -= 2;
      final off = inputPosition - ref - 1;
      if (len < 7) {
        output[outputPosition++] = ((off >> 8) + (len << 5)) & 0xFF;
      } else {
        output[outputPosition++] = ((off >> 8) + (7 << 5)) & 0xFF;
        output[outputPosition++] = (len - 7) & 0xFF;
      }
      output[outputPosition++] = off & 0xFF;
      outputPosition++; // Reserve space for next literal length indicator.
      inputPosition += len;
      // Prime the hash table with the new sequence.
      seen = _first(input, inputPosition);
      seen = _next(seen, input, inputPosition);
      _hashTable[_hash(seen)] = inputPosition;
      inputPosition++;
      seen = _next(seen, input, inputPosition);
      _hashTable[_hash(seen)] = inputPosition;
      inputPosition++;
    }

    // Process remaining bytes (tail).
    return _handleTail(
      input,
      inputPosition,
      inEnd,
      output,
      outputPosition,
      literals,
    );
  }

  /// Handles the final bytes of the input that were not compressed.
  ///
  /// Returns the new output position after copying the tail bytes.
  int _handleTail(
    Uint8List input,
    int inPosition,
    int inEnd,
    Uint8List output,
    int outPosition,
    int literal,
  ) {
    var inputPosition = inPosition;
    var outputPosition = outPosition;
    var literals = literal;

    while (inputPosition < inEnd) {
      output[outputPosition++] = input[inputPosition++];
      literals++;
      if (literals == LZFChunk.maxLiteral) {
        output[outputPosition - literals - 1] = (literals - 1) & 0xFF;
        literals = 0;
        outputPosition++;
      }
    }
    output[outputPosition - literals - 1] = (literals - 1) & 0xFF;
    if (literals == 0) {
      outputPosition--;
    }

    return outputPosition;
  }

  /// Reads the first two bytes starting at [inputPosition] as a 16-bit value.
  @pragma('vm:prefer-inline')
  int _first(Uint8List input, int inputPosition) =>
      (input[inputPosition] << 8) | input[inputPosition + 1];

  /// Incorporates the next byte from [input] at [inputPosition + 2] into
  /// [value].
  @pragma('vm:prefer-inline')
  int _next(int value, Uint8List input, int inputPosition) =>
      (value << 8) | input[inputPosition + 2];

  /// Computes a hash for a 3-byte sequence.
  ///
  /// The returned hash is used as an index into [_hashTable].
  @pragma('vm:prefer-inline')
  int _hash(int h) => ((h * 57321) >> 9) & _hashModulo;

  /// Calculates the appropriate hash table size for a given [chunkLength].
  ///
  /// The hash table size is chosen as the smallest power of 2 that is at least
  /// twice the [chunkLength], but no larger than [_maxHashSize].
  static int _calculateHashSize(int chunkLength) {
    final doubleSize = chunkLength * 2;
    if (doubleSize >= _maxHashSize) return _maxHashSize;
    var hashLength = _minHashSize;
    while (hashLength < doubleSize) {
      hashLength += hashLength;
    }
    return hashLength;
  }

  /// Minimum block size to attempt compression.
  static const minBlockToCompress = 16;

  /// Minimum allowed hash table size.
  static const _minHashSize = 256;

  /// Maximum allowed hash table size.
  static const _maxHashSize = 16384;

  /// Maximum offset allowed for a back-reference.
  static const _maxOff = 1 << 13;

  /// Maximum match length (reference) allowed.
  static const _maxRef = (1 << 8) + (1 << 3);

  /// The number of bytes at the end of the block that are not processed by the
  /// main compression loop.
  static const _tailLength = 4;
}

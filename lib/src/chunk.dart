import 'dart:math' as math;
import 'dart:typed_data';

/// A chunk of LZF-encoded data, which may be either compressed or uncompressed.
///
/// LZF compresses data into segments (chunks), each starting with a header
/// indicating whether it is compressed or uncompressed. Chunks can be linked
/// together to form a complete LZF-encoded file.
final class LZFChunk {
  /// Creates an LZF chunk from the provided [bytes].
  ///
  /// The [bytes] should be a valid LZF block, including the necessary headers.
  LZFChunk(this.bytes) : assert(isValidChunk(bytes), 'Invalid LZF chunk.');

  /// Creates a compressed LZF chunk from [compressed] data.
  ///
  /// The [uncompressedLength] specifies the original size before compression.
  ///
  /// Throws an [ArgumentError] if the length of [compressed] exceeds
  /// [maxChunkLength].
  factory LZFChunk.compressed(Uint8List compressed, int uncompressedLength) {
    final compressedLength = compressed.length;
    if (compressedLength > maxChunkLength) {
      throw ArgumentError.value(
        compressed,
        'compressed',
        'Chunk length exceeds maximum allowed value ($maxChunkLength).',
      );
    }

    final totalLength = headerLengthCompressed + compressedLength;
    final result = Uint8List(totalLength);
    result[0] = byteZ;
    result[1] = byteV;
    result[2] = blockTypeCompressed;
    result[3] = compressedLength >> 8;
    result[4] = compressedLength & 0xFF;
    result[5] = uncompressedLength >> 8;
    result[6] = uncompressedLength & 0xFF;
    result.setRange(headerLengthCompressed, totalLength, compressed);
    return LZFChunk(result);
  }

  /// Creates an uncompressed LZF chunk from [uncompressed] data.
  ///
  /// Throws an [ArgumentError] if the length of [uncompressed] exceeds
  /// [maxChunkLength].
  factory LZFChunk.uncompressed(Uint8List uncompressed) {
    final uncompressedLength = uncompressed.length;
    if (uncompressedLength > maxChunkLength) {
      throw ArgumentError.value(
        uncompressed,
        'uncompressed',
        'Chunk length exceeds maximum allowed value ($maxChunkLength).',
      );
    }

    final totalLength = headerLengthUncompressed + uncompressedLength;
    final result = Uint8List(totalLength);
    result[0] = byteZ;
    result[1] = byteV;
    result[2] = blockTypeUncompressed;
    result[3] = uncompressedLength >> 8;
    result[4] = uncompressedLength & 0xFF;
    result.setRange(headerLengthUncompressed, totalLength, uncompressed);
    return LZFChunk(result);
  }

  /// The raw bytes representing this LZF chunk, including the header.
  final Uint8List bytes;

  /// The next LZF chunk in the sequence, if any.
  LZFChunk? next;

  /// Copies this chunk's bytes into the [destination] buffer at the given
  /// [offset].
  ///
  /// Returns the new offset immediately after the copied data.
  int copyTo(Uint8List destination, {int offset = 0}) {
    final length = bytes.length;
    destination.setRange(offset, offset + length, bytes);
    return offset + length;
  }

  /// Returns the total length of this chunk in bytes.
  @pragma('vm:prefer-inline')
  int get length => bytes.length;

  @override
  String toString() {
    final length = bytes.length;
    final previewLength = math.min(length, 10);
    final previewData = bytes.sublist(0, previewLength);
    return 'LZFChunk(length: $length, bytes (first 10): $previewData)';
  }

  /// Validates whether the given [data] follows the LZF format.
  ///
  /// A valid LZF chunk must:
  /// - Have a minimum length of [headerLengthUncompressed].
  /// - Start with the magic bytes (`ZV`).
  /// - Have a valid block type ([blockTypeCompressed] or
  ///   [blockTypeUncompressed]).
  static bool isValidChunk(Uint8List data) =>
      data.length >= headerLengthUncompressed &&
      data[0] == byteZ &&
      data[1] == byteV &&
      (data[2] == blockTypeCompressed || data[2] == blockTypeUncompressed);

  /// Indicates an LZF block that contains compressed data.
  static const blockTypeCompressed = 1;

  /// Indicates an LZF block that contains uncompressed (raw) data.
  static const blockTypeUncompressed = 0;

  /// The first magic byte in an LZF block, representing `'Z'`.
  static const byteV = 0x56;

  /// The second magic byte in an LZF block, representing `'V'`.
  static const byteZ = 0x5A;

  /// The length of the header for a compressed LZF block.
  static const headerLengthCompressed = 7;

  /// The length of the header for an uncompressed LZF block.
  static const headerLengthUncompressed = 5;

  /// The maximum allowable length for an LZF chunk (65,535 bytes).
  static const maxChunkLength = 0xFFFF;

  /// The maximum header length of a LZF block.
  static const maxHeaderLength = 7;

  /// The maximum length of a literal run in LZF encoding.
  static const maxLiteral = 32;
}

import 'dart:math' as math;
import 'dart:typed_data';

import 'chunk.dart';
import 'chunk_encoder.dart';

/// A utility class for encoding data into LZF format.
///
/// This class provides static methods for encoding raw data into one or more
/// LZF chunks and coalescing them into a single contiguous [Uint8List].
abstract final class LZFEncoder {
  /// Encodes the entire [data] buffer.
  ///
  /// Returns a [Uint8List] containing the LZF-encoded data.
  static Uint8List encode(Uint8List data) =>
      encodeWithEncoder(ChunkEncoder(length: data.length), data);

  /// Encodes the [data] buffer using the provided [encoder].
  ///
  /// If the data length exceeds [LZFChunk.maxChunkLength], it is split into
  /// multiple chunks which are then coalesced into a single contiguous byte
  /// list.
  static Uint8List encodeWithEncoder(ChunkEncoder encoder, Uint8List data) {
    var remaining = data.length;
    var offset = 0;

    // Process the first chunk.
    var chunkLength = math.min(LZFChunk.maxChunkLength, remaining);
    final firstChunk = encoder.encode(
      data,
      offset: offset,
      length: chunkLength,
    );
    remaining -= chunkLength;
    offset += chunkLength;

    // If the entire data fits into one chunk, return it directly.
    if (remaining < 1) return firstChunk.bytes;

    // Otherwise, chain additional chunks.
    var totalBytes = firstChunk.length;
    var currentChunk = firstChunk;

    while (remaining > 0) {
      chunkLength = math.min(remaining, LZFChunk.maxChunkLength);
      final nextChunk = encoder.encode(
        data,
        offset: offset,
        length: chunkLength,
      );
      offset += chunkLength;
      remaining -= chunkLength;
      totalBytes += nextChunk.length;
      currentChunk.next = nextChunk;
      currentChunk = nextChunk;
    }

    // Coalesce all chunks into a single contiguous byte list.
    final result = Uint8List(totalBytes);
    offset = 0;
    LZFChunk? chunk = firstChunk;
    while (chunk != null) {
      offset = chunk.copyTo(result, offset: offset);
      chunk = chunk.next;
    }

    return result;
  }
}

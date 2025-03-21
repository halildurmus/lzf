import 'dart:typed_data';

import 'chunk_decoder.dart';

/// A utility class for decoding LZF-encoded data.
///
/// This class provides a simple static API to decode LZF data into its
/// original, uncompressed form.
abstract final class LZFDecoder {
  static const _decoder = ChunkDecoder();

  /// Decodes the provided LZF-encoded [data].
  ///
  /// Returns a [Uint8List] containing the uncompressed data.
  static Uint8List decode(Uint8List data) => _decoder.decode(data);

  /// Decodes the provided LZF-encoded [data] using a custom [decoder].
  ///
  /// Returns a [Uint8List] containing the uncompressed data.
  static Uint8List decodeWithDecoder(ChunkDecoder decoder, Uint8List data) =>
      decoder.decode(data);
}

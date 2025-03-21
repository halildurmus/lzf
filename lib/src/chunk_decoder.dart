import 'dart:typed_data';

import 'chunk.dart';
import 'exception.dart';

/// Decodes LZF-encoded data into its original (uncompressed) form.
///
/// This decoder processes both compressed and uncompressed LZF chunks.
final class ChunkDecoder {
  const ChunkDecoder();

  /// Decodes an entire LZF-encoded [data] buffer starting at [offset].
  ///
  /// Returns a new [Uint8List] containing the uncompressed data.
  Uint8List decode(Uint8List data, {int offset = 0}) {
    final uncompressedSize = _calculateUncompressedSize(data);
    final result = Uint8List(uncompressedSize);
    _decode(data, offset, result);
    return result;
  }

  /// Internal method to decode LZF data from [source] starting at [offset]
  /// into [target].
  ///
  /// Returns the final write offset in [target].
  int _decode(Uint8List source, int offset, Uint8List target) {
    var inputPosition = offset;
    var outputPosition = 0;
    var blockNo = 0;
    // Reserve last byte for optional end marker.
    final end = offset + source.length - 1;

    while (inputPosition < end) {
      _validateHeader(source, inputPosition, blockNo);
      final type = source[inputPosition + 2];
      // Read block length from header.
      final len = _uint16(source, inputPosition + 3);
      inputPosition += 5;

      if (type == LZFChunk.blockTypeUncompressed) {
        _validateBufferSize(target, outputPosition, len);
        target.setRange(
          outputPosition,
          outputPosition + len,
          source,
          inputPosition,
        );
        outputPosition += len;
      } else if (type == LZFChunk.blockTypeCompressed) {
        final uncompLen = _uint16(source, inputPosition);
        _validateBufferSize(target, outputPosition, uncompLen);
        inputPosition += 2;
        outputPosition = _decodeChunk(
          source,
          inputPosition,
          target,
          outputPosition,
          outputPosition + uncompLen,
        );
      } else {
        throw LZFException(
          'Corrupt input data, block #$blockNo: unrecognized block type $type',
        );
      }
      inputPosition += len;
      blockNo++;
    }

    return outputPosition;
  }

  /// Decodes a single LZF chunk given in [data] into [output].
  ///
  /// Returns a new [Uint8List] view of the [output] buffer up to the decoded
  /// length.
  Uint8List decodeChunk(Uint8List data, Uint8List output) {
    _validateHeader(data, 0);
    final blockType = data[2];
    final compressedLength = _uint16(data, 3);

    switch (blockType) {
      case LZFChunk.blockTypeCompressed:
        final uncompressedLength = _uint16(data, 0);
        final outputPos = _decodeChunk(data, 2, output, 0, uncompressedLength);
        return Uint8List.view(output.buffer, 0, outputPos);

      case LZFChunk.blockTypeUncompressed:
        return Uint8List.view(
          data.buffer,
          LZFChunk.headerLengthUncompressed,
          compressedLength,
        );

      default:
        throw LZFException('Unrecognized block type: $blockType');
    }
  }

  /// Decodes a compressed block from [input] starting at [inPos] into [output].
  ///
  /// Decoding continues until [outPos] reaches [outEnd].
  ///
  /// Returns the final output position.
  int _decodeChunk(
    Uint8List input,
    int inPos,
    Uint8List output,
    int outPos,
    int outEnd,
  ) {
    var inputPosition = inPos;
    var outputPosition = outPos;

    do {
      var ctrl = input[inputPosition++];
      if (ctrl < LZFChunk.maxLiteral) {
        // Literal run: copy ctrl+1 bytes.
        final literalLen = ctrl + 1;
        output.setRange(
          outputPosition,
          outputPosition + literalLen,
          input,
          inputPosition,
        );
        inputPosition += literalLen;
        outputPosition += literalLen;
      } else {
        // Compressed match.
        var len = ctrl >> 5;
        ctrl = -((ctrl & 31) << 8) - 1;
        if (len < 7) {
          ctrl -= input[inputPosition++] & 0xFF;
          // Copy two bytes explicitly.
          output[outputPosition] = output[outputPosition++ + ctrl];
          output[outputPosition] = output[outputPosition++ + ctrl];
          // Copy remaining len bytes.
          for (var i = 1; i <= len; i++) {
            output[outputPosition] = output[outputPosition++ + ctrl];
          }
        } else {
          len = input[inputPosition++];
          ctrl -= input[inputPosition++] & 0xFF;
          if (ctrl + len < -9) {
            len += 9;
            if (len <= 32) {
              _copyUpTo(
                output,
                outputPosition + ctrl,
                output,
                outputPosition,
                len - 1,
              );
            } else {
              output.setRange(
                outputPosition,
                outputPosition + len,
                output,
                outputPosition + ctrl,
              );
            }
            outputPosition += len;
          } else {
            // Unrolled copy for longer matches.
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            output[outputPosition] = output[outputPosition++ + ctrl];
            len += outputPosition;

            while (outputPosition < len - 3) {
              output[outputPosition] = output[outputPosition++ + ctrl];
              output[outputPosition] = output[outputPosition++ + ctrl];
              output[outputPosition] = output[outputPosition++ + ctrl];
            }

            switch (len - outputPosition) {
              case 3:
                output[outputPosition] = output[outputPosition++ + ctrl];
                output[outputPosition] = output[outputPosition++ + ctrl];
                output[outputPosition] = output[outputPosition++ + ctrl];
              case 2:
                output[outputPosition] = output[outputPosition++ + ctrl];
                output[outputPosition] = output[outputPosition++ + ctrl];
              case 1:
                output[outputPosition] = output[outputPosition++ + ctrl];
            }
          }
        }
      }
    } while (outputPosition < outEnd);

    if (outputPosition != outEnd) {
      throw LZFException(
        'Corrupt data: overrun in decompress (input offset $inputPosition, output offset $outputPosition)',
      );
    }

    return outputPosition;
  }

  /// Copies up to [lengthMinusOne] + `1` bytes from [input] (starting at
  /// [inPosition]) to [output] (starting at [outPosition]).
  static void _copyUpTo(
    Uint8List input,
    int inPosition,
    Uint8List output,
    int outPosition,
    int lengthMinusOne,
  ) {
    for (var i = 0; i <= lengthMinusOne; i++) {
      output[outPosition + i] = input[inPosition + i];
    }
  }

  /// Calculates the total uncompressed size by scanning through the encoded
  /// [data].
  ///
  /// Throws a [LZFException] if input data appears truncated or corrupt.
  static int _calculateUncompressedSize(Uint8List data) {
    var uncompressedSize = 0;
    var blockNo = 0;
    var offset = 0;
    final end = data.length;

    while (offset < end) {
      // Optional end marker handling.
      if (offset == (end - 1) && data[offset] == 0) {
        offset++;
        break;
      }

      try {
        _validateHeader(data, offset, blockNo);
        final type = data[offset + 2];
        final blockLength = _uint16(data, offset + 3);
        if (type == LZFChunk.blockTypeUncompressed) {
          offset += LZFChunk.headerLengthUncompressed;
          uncompressedSize += blockLength;
        } else if (type == LZFChunk.blockTypeCompressed) {
          uncompressedSize += _uint16(data, offset + 5);
          offset += LZFChunk.headerLengthCompressed;
        } else {
          throw LZFException(
            'Corrupt input data, block #$blockNo (at offset $offset): unrecognized block type ${type & 0xFF}',
          );
        }
        offset += blockLength;
      } catch (e) {
        throw LZFException(
          'Corrupt input data, block #$blockNo (at offset $offset): truncated block header',
        );
      }
      blockNo++;
    }

    // one more sanity check:
    if (offset != end) {
      throw LZFException(
        'Corrupt input data: block #$blockNo extends ${data.length - offset} beyond end of input',
      );
    }

    return uncompressedSize;
  }

  /// Reads a 16-bit unsigned integer from [data] at position [offset].
  static int _uint16(Uint8List data, int offset) =>
      ((data[offset] & 0xFF) << 8) + (data[offset + 1] & 0xFF);

  /// Validates that [buffer] has enough space from [offset] for [size] bytes.
  static void _validateBufferSize(Uint8List buffer, int offset, int size) {
    if ((offset + size) > buffer.length) {
      throw LZFException(
        'Target buffer too small: cannot copy/uncompress $size bytes at offset $offset',
      );
    }
  }

  /// Validates that the LZF header at [offset] in [data] starts with the magic
  /// bytes.
  static void _validateHeader(Uint8List data, int offset, [int blockNo = -1]) {
    if (data[offset] != LZFChunk.byteZ || data[offset + 1] != LZFChunk.byteV) {
      throw LZFException(
        'Corrupt input data${blockNo >= 0 ? ", block #$blockNo" : ""} (at offset $offset): '
        "did not start with 'ZV' signature bytes",
      );
    }
  }
}

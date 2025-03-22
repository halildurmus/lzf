import 'dart:convert';

import 'package:lzf/lzf.dart';

void main() {
  // A text with repeated patterns for better compression.
  const originalText =
      'LZF compression is fast and efficient. '
      'Fast and efficient compression is useful. '
      'Useful compression is fast and efficient. '
      'Efficient and fast compression is useful. '
      'Compression is fast, efficient, and useful.';

  // Convert the text into a UTF-8 encoded byte list.
  final originalData = utf8.encode(originalText);
  print('Original text: $originalText');
  print('Original size: ${originalData.length} bytes');

  // Compress the byte data using LZF.
  final compressedData = LZFEncoder.encode(originalData);
  print('Compressed size: ${compressedData.length} bytes');
  final compressionRatio =
      (1 - (compressedData.length / originalData.length)) * 100;
  print('Compression ratio: ${compressionRatio.toStringAsFixed(2)}%');

  // Decompress the compressed data back to its original form.
  final decompressedData = LZFDecoder.decode(compressedData);
  print('Decompressed size: ${decompressedData.length} bytes');

  // Convert the decompressed byte list back into a string.
  final decompressedText = utf8.decode(decompressedData);
  print('Decompressed text: $decompressedText');
}

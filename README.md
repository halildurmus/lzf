[![ci][ci_badge]][ci_link]
[![Package: lzf][package_badge]][package_link]
[![Publisher: halildurmus.dev][publisher_badge]][publisher_link]
[![Language: Dart][language_badge]][language_link]
[![License: BSD-3-Clause][license_badge]][license_link]
[![codecov][codecov_badge_link]][codecov_link]

**A Dart implementation of the LZF, a fast, lightweight compression algorithm
optimized for speed.**

LZF is optimized for speed over compression ratio. Ideal for real-time data
processing, caching layers, and low-latency systems where throughput matters
most.

> The data format and algorithm are based on the C library
> [liblzf](https://software.schmorp.de/pkg/liblzf.html) by Marc Lehmann, with
> the implementation adapted from the Java library
> [compress-lzf](https://github.com/ning/compress) by Tatu Saloranta.
>
> For more details about the LZF data format, refer to the
> [LZF Format Specification][].

## 🚀 Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  lzf: ^0.1.1
```

Then import it:

```dart
import 'package:lzf/lzf.dart';
```

## ⚡ Quick Example

Compress data with `LZFEncoder.encode()` and decompress it with
`LZFDecoder.decode()`. Both works with `Uint8List`:

```dart
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
```

## 🐞 Features and Bugs

If you encounter bugs or need additional functionality, please
[file an issue][issue_tracker_link].

[ci_badge]: https://github.com/halildurmus/lzf/actions/workflows/lzf.yml/badge.svg
[ci_link]: https://github.com/halildurmus/lzf/actions/workflows/lzf.yml
[codecov_badge_link]: https://codecov.io/gh/halildurmus/lzf/graph/badge.svg?token=ZG7GBT95JP
[codecov_link]: https://codecov.io/gh/halildurmus/lzf
[issue_tracker_link]: https://github.com/halildurmus/lzf/issues
[language_badge]: https://img.shields.io/badge/language-Dart-blue.svg
[language_link]: https://dart.dev
[license_badge]: https://img.shields.io/github/license/halildurmus/lzf?color=blue
[license_link]: https://opensource.org/licenses/BSD-3-Clause
[LZF Format Specification]: https://web.archive.org/web/20161025225604/https://github.com/ning/compress/wiki/LZFFormat
[package_badge]: https://img.shields.io/pub/v/lzf.svg
[package_link]: https://pub.dev/packages/lzf
[publisher_badge]: https://img.shields.io/pub/publisher/lzf.svg
[publisher_link]: https://pub.dev/publishers/halildurmus.dev

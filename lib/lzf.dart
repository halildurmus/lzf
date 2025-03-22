/// A Dart implementation of the LZF, a fast and lightweight data compression
/// algorithm.
///
/// LZF is optimized for speed rather than achieving the highest compression
/// ratios, making it ideal for scenarios where performance is the priority,
/// such as real-time data processing and low-latency systems.
library;

export 'src/chunk.dart';
export 'src/chunk_decoder.dart';
export 'src/chunk_encoder.dart';
export 'src/exception.dart';
export 'src/lzf_decoder.dart';
export 'src/lzf_encoder.dart';

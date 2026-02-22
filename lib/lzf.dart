/// This library provides a Dart implementation of the LZF, a fast and
/// lightweight data compression algorithm.
///
/// LZF is optimized for speed over compression ratio. Ideal for real-time data
/// processing, caching layers, and low-latency systems where throughput matters
/// most.
library;

export 'src/chunk.dart';
export 'src/chunk_decoder.dart';
export 'src/chunk_encoder.dart';
export 'src/exception.dart';
export 'src/lzf_decoder.dart';
export 'src/lzf_encoder.dart';

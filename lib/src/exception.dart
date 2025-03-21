/// Exception thrown when an error occurs during LZF compression or
/// decompression.
final class LZFException implements Exception {
  /// Creates a new `LZFException` with an error [message].
  LZFException(this.message);

  /// A message describing the error.
  final String message;

  @override
  String toString() => 'LZFException: $message';
}

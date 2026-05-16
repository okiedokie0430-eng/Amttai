import 'dart:math';

/// Generates and tracks nonces for replay protection.
///
/// Each request to the Appwrite Function includes a unique nonce.
/// The function rejects any nonce it has already seen within 24 hours.
class NonceManager {
  NonceManager._();

  static final _random = Random.secure();

  /// Generate a 64-character hex nonce.
  static String generate() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

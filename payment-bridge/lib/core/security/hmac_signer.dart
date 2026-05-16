import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../config/bridge_config.dart';

/// HMAC-SHA256 signer for securing requests to Appwrite Functions.
///
/// Signs payloads with a shared secret to prevent unauthorized
/// submissions to the payment processing endpoint.
class HmacSigner {
  HmacSigner._();

  /// Sign a payload and return the hex-encoded HMAC-SHA256 signature.
  static String sign({
    required String deviceId,
    required String transactionCode,
    required int amount,
    required int timestamp,
    required String nonce,
    String? secret,
  }) {
    final key = utf8.encode(secret ?? BridgeConfig.hmacSecret);
    final message = '$deviceId|$transactionCode|$amount|$timestamp|$nonce';
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(utf8.encode(message));
    return digest.toString();
  }

  /// Verify a signature against expected values.
  static bool verify({
    required String signature,
    required String deviceId,
    required String transactionCode,
    required int amount,
    required int timestamp,
    required String nonce,
    String? secret,
  }) {
    final expected = sign(
      deviceId: deviceId,
      transactionCode: transactionCode,
      amount: amount,
      timestamp: timestamp,
      nonce: nonce,
      secret: secret,
    );
    // Constant-time comparison to prevent timing attacks
    if (signature.length != expected.length) return false;
    var result = 0;
    for (var i = 0; i < signature.length; i++) {
      result |= signature.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Create a fingerprint hash of an SMS for dedup.
  static String fingerprint(String sender, String body, DateTime receivedAt) {
    // Round timestamp to minute to handle slight timing differences
    final roundedMs =
        (receivedAt.millisecondsSinceEpoch ~/ 60000) * 60000;
    final input = '$sender|$body|$roundedMs';
    return sha256.convert(utf8.encode(input)).toString();
  }
}

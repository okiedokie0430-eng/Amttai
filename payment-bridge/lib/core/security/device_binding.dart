import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Manages device identity binding for security.
///
/// Generates and persists a unique device ID on first launch.
/// This ID is included in all Appwrite requests for whitelisting.
class DeviceBinding {
  DeviceBinding._();

  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'bridge_device_id';
  static const _apiKeyKey = 'bridge_api_key';
  static const _hmacSecretKey = 'bridge_hmac_secret';

  static String? _cachedDeviceId;
  static String? _cachedApiKey;

  /// Get or generate the persistent device ID.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Store the Appwrite API key securely.
  static Future<void> setApiKey(String apiKey) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    _cachedApiKey = apiKey;
  }

  /// Get the stored API key.
  static Future<String?> getApiKey() async {
    _cachedApiKey ??= await _storage.read(key: _apiKeyKey);
    return _cachedApiKey;
  }

  /// Store the HMAC secret securely.
  static Future<void> setHmacSecret(String secret) async {
    await _storage.write(key: _hmacSecretKey, value: secret);
  }

  /// Get the stored HMAC secret.
  static Future<String?> getHmacSecret() async {
    return await _storage.read(key: _hmacSecretKey);
  }

  /// Check if device is set up (has device ID and API key).
  static Future<bool> isSetUp() async {
    final deviceId = await getDeviceId();
    final apiKey = await getApiKey();
    return deviceId.isNotEmpty && apiKey != null && apiKey.isNotEmpty;
  }
}

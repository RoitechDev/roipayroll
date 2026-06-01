import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypts and decrypts sensitive application fields.
///
/// Notes:
/// - Uses AES-256-GCM with a fresh nonce per value.
/// - Uses a stable prefix for backward-compatible encrypted-field detection.
/// - Falls back cleanly for legacy plaintext records.
class EncryptionService {
  EncryptionService._();

  static const String _masterKeyName = 'roipayroll_encryption_master_key_v1';
  static const List<String> _legacyMasterKeyNames = [
    'encryption_master_key',
    'roipayroll_encryption_master_key',
  ];
  static const String _cipherPrefix = 'enc_v1:';
  static const int _nonceLength = 12;
  static const List<int> _supportedNonceLengths = [12, 16];
  static const String _configuredMasterSecret = String.fromEnvironment(
    'ROI_MASTER_ENCRYPTION_KEY',
  );
  static const String _legacyConfiguredMasterSecret = String.fromEnvironment(
    'ROI_LEGACY_MASTER_ENCRYPTION_KEY',
  );

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static enc.Key? _keyCache;
  static enc.Encrypter? _encrypterCache;
  static List<enc.Key>? _decryptKeyCache;
  static bool _reportedCipherMismatch = false;

  static Future<void> initialize() async {
    await _getEncrypter();
  }

  static Future<String> _getOrCreateMasterSecret() async {
    if (_configuredMasterSecret.trim().isNotEmpty) {
      await _storage.write(key: _masterKeyName, value: _configuredMasterSecret);
      return _configuredMasterSecret;
    }

    final existingSecret = await _storage.read(key: _masterKeyName);
    if (existingSecret != null && existingSecret.isNotEmpty) {
      return existingSecret;
    }

    final random = Random.secure();
    final secretBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final secret = base64UrlEncode(secretBytes);
    await _storage.write(key: _masterKeyName, value: secret);
    return secret;
  }

  static enc.Key _deriveKeyFromSecret(String masterSecret) {
    final derivedKey = sha256.convert(utf8.encode(masterSecret)).bytes;
    return enc.Key(Uint8List.fromList(derivedKey));
  }

  static Uint8List? _tryDecodeBase64(String value) {
    try {
      return Uint8List.fromList(base64Decode(value));
    } catch (_) {
      try {
        return Uint8List.fromList(base64Url.decode(base64Url.normalize(value)));
      } catch (_) {
        return null;
      }
    }
  }

  static enc.Key? _tryCreateLegacyRawKey(String secret) {
    final decoded = _tryDecodeBase64(secret);
    if (decoded == null || decoded.length != 32) {
      return null;
    }
    return enc.Key(decoded);
  }

  static void _addUniqueKey(List<enc.Key> keys, enc.Key? key) {
    if (key == null) return;
    final signature = base64Encode(key.bytes);
    final exists = keys.any((candidate) {
      return base64Encode(candidate.bytes) == signature;
    });
    if (!exists) {
      keys.add(key);
    }
  }

  static Future<List<enc.Key>> _getDecryptKeys() async {
    if (_decryptKeyCache != null) {
      return _decryptKeyCache!;
    }

    final keys = <enc.Key>[];
    final secrets = <String>[];

    void addSecret(String? value) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty || secrets.contains(normalized)) return;
      secrets.add(normalized);
    }

    addSecret(_configuredMasterSecret);
    addSecret(_legacyConfiguredMasterSecret);
    addSecret(await _storage.read(key: _masterKeyName));
    for (final legacyKeyName in _legacyMasterKeyNames) {
      addSecret(await _storage.read(key: legacyKeyName));
    }

    if (secrets.isEmpty) {
      addSecret(await _getOrCreateMasterSecret());
    }

    for (final secret in secrets) {
      _addUniqueKey(keys, _deriveKeyFromSecret(secret));
      _addUniqueKey(keys, _tryCreateLegacyRawKey(secret));
    }

    _decryptKeyCache = keys;
    return keys;
  }

  static Future<enc.Key> _getKey() async {
    if (_keyCache != null) {
      return _keyCache!;
    }

    final masterSecret = await _getOrCreateMasterSecret();
    _keyCache = _deriveKeyFromSecret(masterSecret);
    return _keyCache!;
  }

  static Future<enc.Encrypter> _getEncrypter() async {
    if (_encrypterCache != null) {
      return _encrypterCache!;
    }

    final key = await _getKey();
    _encrypterCache = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return _encrypterCache!;
  }

  static Uint8List? _decodeEncryptedPayload(String encryptedText) {
    try {
      final encodedPayload = encryptedText.substring(_cipherPrefix.length);
      return Uint8List.fromList(base64Decode(encodedPayload));
    } catch (_) {
      return null;
    }
  }

  static String _decryptPayloadWithKey(
    Uint8List payload,
    enc.Key key, {
    required int nonceLength,
  }) {
    if (payload.length <= nonceLength) {
      throw const FormatException('Encrypted payload is too short.');
    }
    final nonce = enc.IV(Uint8List.fromList(payload.sublist(0, nonceLength)));
    final cipherBytes = payload.sublist(nonceLength);
    final encrypted = enc.Encrypted(Uint8List.fromList(cipherBytes));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    return encrypter.decrypt(encrypted, iv: nonce);
  }

  static bool isEncryptedValue(String? value) {
    return value != null && value.startsWith(_cipherPrefix);
  }

  static Future<String?> encrypt(String? plainText) async {
    if (plainText == null || plainText.isEmpty) {
      return plainText;
    }
    if (isEncryptedValue(plainText)) {
      return plainText;
    }

    try {
      final encrypter = await _getEncrypter();
      final nonce = enc.IV.fromSecureRandom(_nonceLength);
      final encrypted = encrypter.encrypt(plainText, iv: nonce);
      final payload = <int>[...nonce.bytes, ...encrypted.bytes];
      return '$_cipherPrefix${base64Encode(payload)}';
    } catch (e) {
      debugPrint('Encryption error: $e');
      rethrow;
    }
  }

  static Future<String?> decrypt(String? encryptedText) async {
    if (encryptedText == null || encryptedText.isEmpty) {
      return encryptedText;
    }
    if (!isEncryptedValue(encryptedText)) {
      return encryptedText;
    }

    try {
      final payload = _decodeEncryptedPayload(encryptedText);
      if (payload == null || payload.length <= _supportedNonceLengths.first) {
        return encryptedText;
      }
      final decryptKeys = await _getDecryptKeys();

      for (final key in decryptKeys) {
        for (final nonceLength in _supportedNonceLengths) {
          try {
            return _decryptPayloadWithKey(
              payload,
              key,
              nonceLength: nonceLength,
            );
          } catch (_) {}
        }
      }

      if (!_reportedCipherMismatch) {
        debugPrint(
          'Decryption warning: some legacy encrypted fields could not be decrypted with the current key and will be left as-is.',
        );
        _reportedCipherMismatch = true;
      }
      return encryptedText;
    } catch (e) {
      debugPrint('Decryption error: $e');
      return encryptedText;
    }
  }

  static Future<String?> normalizeForStorage(String? value) async {
    if (value == null || value.isEmpty) {
      return value;
    }

    if (!isEncryptedValue(value)) {
      return encrypt(value);
    }

    final payload = _decodeEncryptedPayload(value);
    if (payload == null) {
      return value;
    }

    final currentKey = await _getKey();
    for (final nonceLength in _supportedNonceLengths) {
      try {
        _decryptPayloadWithKey(payload, currentKey, nonceLength: nonceLength);
        return value;
      } catch (_) {}
    }

    final decryptKeys = await _getDecryptKeys();
    for (final key in decryptKeys) {
      final sameKey = base64Encode(key.bytes) == base64Encode(currentKey.bytes);
      if (sameKey) continue;
      for (final nonceLength in _supportedNonceLengths) {
        try {
          final plainText = _decryptPayloadWithKey(
            payload,
            key,
            nonceLength: nonceLength,
          );
          return encrypt(plainText);
        } catch (_) {}
      }
    }

    return value;
  }

  static Future<Map<String, dynamic>> normalizeFieldsForStorage(
    Map<String, dynamic> data,
    Iterable<String> fieldsToNormalize,
  ) async {
    final result = <String, dynamic>{};
    for (final field in fieldsToNormalize) {
      final value = data[field];
      if (value is String) {
        result[field] = await normalizeForStorage(value);
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> encryptFields(
    Map<String, dynamic> data,
    Iterable<String> fieldsToEncrypt,
  ) async {
    final result = Map<String, dynamic>.from(data);
    for (final field in fieldsToEncrypt) {
      final value = result[field];
      if (value is String) {
        result[field] = await encrypt(value);
      }
    }
    return result;
  }

  static Future<Map<String, dynamic>> decryptFields(
    Map<String, dynamic> data,
    Iterable<String> fieldsToDecrypt,
  ) async {
    final result = Map<String, dynamic>.from(data);
    for (final field in fieldsToDecrypt) {
      final value = result[field];
      if (value is String) {
        result[field] = await decrypt(value);
      }
    }
    return result;
  }

  static Future<void> rotateKey() async {
    await _storage.delete(key: _masterKeyName);
    _keyCache = null;
    _encrypterCache = null;
    _decryptKeyCache = null;
    _reportedCipherMismatch = false;
    await _getOrCreateMasterSecret();
  }
}

// AuthCryptoService - сервис для криптографических операций авторизации
//
// Ответственность:
// - Шифрование/дешифрование API ключей перед сохранением в БД
// - Хеширование PIN кодов для безопасного хранения
// - Проверка PIN кодов при входе
// - Управление ключами шифрования (AES-256-GCM)
//
// Безопасность:
// - API ключи шифруются AES-256-GCM перед сохранением в БД
// - Ключ шифрования хранится в FlutterSecureStorage (платформо-зависимое безопасное хранилище)
// - PIN коды хешируются SHA-256 с солью (salt) перед сохранением
// - Nonce генерируется случайно для каждого шифрования
//
// Алгоритмы:
// - Шифрование: AES-256-GCM (через cryptography пакет)
// - Хеширование: SHA-256 (через crypto пакет)
// - Хранение ключа: FlutterSecureStorage (Keychain на iOS, Keystore на Android)

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as crypto_hash;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Сервис для криптографических операций авторизации
class AuthCryptoService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _encryptionKeyStorageKey = 'auth_encryption_key_v1';

  final AesGcm _aesGcmCipher = AesGcm.with256bits();

  Future<SecretKey> _getOrCreateEncryptionKey() async {
    final String? existingBase64Key =
        await _secureStorage.read(key: _encryptionKeyStorageKey);

    if (existingBase64Key != null && existingBase64Key.isNotEmpty) {
      final List<int> keyBytes = base64Decode(existingBase64Key);
      return SecretKey(keyBytes);
    }

    final List<int> newKeyBytes =
        List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final String newBase64Key = base64Encode(newKeyBytes);

    await _secureStorage.write(
        key: _encryptionKeyStorageKey, value: newBase64Key);
    return SecretKey(newKeyBytes);
  }

  Future<String> encryptApiKeyForDatabase({required String plainApiKey}) async {
    final SecretKey encryptionKey = await _getOrCreateEncryptionKey();
    final List<int> nonceBytes =
        List<int>.generate(12, (_) => Random.secure().nextInt(256));

    final SecretBox encryptedSecretBox = await _aesGcmCipher.encrypt(
      utf8.encode(plainApiKey),
      secretKey: encryptionKey,
      nonce: nonceBytes,
    );

    // Сохраняем nonce + ciphertext + mac
    final Map<String, String> payload = {
      'nonce': base64Encode(encryptedSecretBox.nonce),
      'ciphertext': base64Encode(encryptedSecretBox.cipherText),
      'mac': base64Encode(encryptedSecretBox.mac.bytes),
    };

    return jsonEncode(payload);
  }

  Future<String> decryptApiKeyFromDatabase(
      {required String encryptedApiKey}) async {
    final SecretKey encryptionKey = await _getOrCreateEncryptionKey();
    final Map<String, dynamic> payload =
        jsonDecode(encryptedApiKey) as Map<String, dynamic>;

    final SecretBox secretBox = SecretBox(
      base64Decode(payload['ciphertext'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );

    final List<int> clearBytes = await _aesGcmCipher.decrypt(
      secretBox,
      secretKey: encryptionKey,
    );

    return utf8.decode(clearBytes);
  }

  /// Храним "saltBase64:hashHex"
  String hashPinCodeForStorage({required String pinCode}) {
    final List<int> saltBytes =
        List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final String saltBase64 = base64Encode(saltBytes);

    final List<int> bytesToHash = <int>[
      ...saltBytes,
      ...utf8.encode(pinCode),
    ];

    final String hashHex = crypto_hash.sha256.convert(bytesToHash).toString();
    return '$saltBase64:$hashHex';
  }

  bool verifyPinCode({required String pinCode, required String storedPinHash}) {
    final List<String> parts = storedPinHash.split(':');
    if (parts.length != 2) return false;

    final List<int> saltBytes = base64Decode(parts[0]);
    final String expectedHashHex = parts[1];

    final List<int> bytesToHash = <int>[
      ...saltBytes,
      ...utf8.encode(pinCode),
    ];

    final String actualHashHex =
        crypto_hash.sha256.convert(bytesToHash).toString();
    return actualHashHex == expectedHashHex;
  }
}

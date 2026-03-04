import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> _getOrCreateKey() async {
    String? key = await _secureStorage.read(key: 'encryption_key');
    if (key == null) {
      final newKey = encrypt.Key.fromSecureRandom(32);
      key = newKey.base64;
      await _secureStorage.write(key: 'encryption_key', value: key);
    }
    return key;
  }

  Future<String> encryptData(String plaintext) async {
    try {
      final keyString = await _getOrCreateKey();
      if (keyString == null) throw Exception('Failed to get encryption key');
      final key = encrypt.Key.fromBase64(keyString);
      final iv = encrypt.IV.fromSecureRandom(12);
      final encrypter =
      encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      final encrypted = encrypter.encrypt(plaintext, iv: iv);
      final combined = '${iv.base64}:${encrypted.base64}';
      print('✅ Encrypted with AES-256-GCM: ${combined.substring(0, 50)}...');
      return combined;
    } catch (e) {
      print('❌ Encryption error: $e');
      return plaintext;
    }
  }

  /// Encrypts [plaintext] for vault storage.
  /// Always uses the device encryption key (AES-256-GCM).
  /// This is an alias for [encryptData] and is called when adding files to
  /// the vault so the naming is clear at the call site.
  Future<String> encryptContent(String plaintext) => encryptData(plaintext);

  Future<String> decryptData(String encryptedData) async {
    try {
      final keyString = await _getOrCreateKey();
      if (keyString == null) throw Exception('Failed to get encryption key');
      final key = encrypt.Key.fromBase64(keyString);
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid encrypted data format');
      }
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      final encrypter =
      encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      return encryptedData;
    }
  }

  bool isEncrypted(String? data) {
    if (data == null || data.isEmpty) return false;
    final parts = data.split(':');
    final result =
        parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;
    if (result) {
      print('🔐 Detected AES-256-GCM encrypted content');
    }
    return result;
  }

  Future<void> setPreviewPin(String pin) async {
    await _secureStorage.write(key: 'vault_preview_pin', value: pin);
    print('✅ Preview PIN set successfully');
  }

  Future<String?> getPreviewPin() async {
    return await _secureStorage.read(key: 'vault_preview_pin');
  }

  Future<String?> decryptWithPin(String encryptedData, String pin) async {
    try {
      final storedPin = await getPreviewPin();
      if (storedPin == null) {
        if (pin.isEmpty) return null;
        return await decryptData(encryptedData);
      }
      if (pin != storedPin) {
        print('❌ Incorrect PIN');
        return null;
      }
      return await decryptData(encryptedData);
    } catch (e) {
      print('❌ Preview access denied: $e');
      return null;
    }
  }
}
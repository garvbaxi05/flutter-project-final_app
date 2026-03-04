import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/vault_item.dart';
import '../services/encryption_service.dart';

class VaultProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final EncryptionService _encryptionService = EncryptionService();

  List<VaultItem> _items = [];

  List<VaultItem> get items => _items;

  Future<void> loadVaultItems() async {
    try {
      final jsonStr = await _secureStorage.read(key: 'vault_items');
      if (jsonStr != null) {
        final List decoded = json.decode(jsonStr);
        _items = decoded.map((e) => VaultItem.fromJson(e)).toList();
        print('✅ Loaded ${_items.length} items from secure storage');
      } else {
        print('📭 No vault items found in storage');
      }
    } catch (e) {
      print('❌ Error loading vault items: $e');
      _items = [];
    }
    notifyListeners();
  }

  Future<void> addItem(VaultItem item) async {
    if (item.content != null) {
      print(
          '📝 Before encryption - content: ${item.content!.substring(0, min(50, item.content!.length))}...');
      item.content = await _encryptionService.encryptData(item.content!);
      print(
          '🔒 After encryption - content: ${item.content!.substring(0, min(50, item.content!.length))}...');
    }

    _items.insert(0, item);
    await _save();
    print('💾 Item saved to secure storage. Total items: ${_items.length}');
    notifyListeners();
  }

  Future<void> removeItem(String id) async {
    _items.removeWhere((item) => item.id == id);
    await _save();
    print('🗑️ Item removed. Total items: ${_items.length}');
    notifyListeners();
  }

  void clearItems() {
    print('🧹 Clearing all items from memory');
    _items = [];
    notifyListeners();
  }

  Future<void> _save() async {
    final jsonStr =
    json.encode(_items.map((e) => e.toJson()).toList());
    await _secureStorage.write(key: 'vault_items', value: jsonStr);
    print('💾 Vault saved (${_items.length} items)');
  }
}

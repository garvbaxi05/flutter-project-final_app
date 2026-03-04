import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/vault_item.dart';

class DecoyVaultProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  List<VaultItem> _galleryItems = [];
  List<VaultItem> _notesItems = [];

  List<VaultItem> get galleryItems => _galleryItems;
  List<VaultItem> get notesItems => _notesItems;

  Future<void> loadGalleryItems() async {
    try {
      final jsonStr =
      await _secureStorage.read(key: 'decoy_gallery_items');
      if (jsonStr != null) {
        final List decoded = json.decode(jsonStr);
        _galleryItems =
            decoded.map((e) => VaultItem.fromJson(e)).toList();
      }
    } catch (e) {
      _galleryItems = [];
    }
    notifyListeners();
  }

  Future<void> loadNotesItems() async {
    try {
      final jsonStr =
      await _secureStorage.read(key: 'decoy_notes_items');
      if (jsonStr != null) {
        final List decoded = json.decode(jsonStr);
        _notesItems =
            decoded.map((e) => VaultItem.fromJson(e)).toList();
      }
    } catch (e) {
      _notesItems = [];
    }
    notifyListeners();
  }

  Future<void> addGalleryItem(VaultItem item) async {
    _galleryItems.insert(0, item);
    await _saveGallery();
    notifyListeners();
  }

  Future<void> addNotesItem(VaultItem item) async {
    _notesItems.insert(0, item);
    await _saveNotes();
    notifyListeners();
  }

  Future<void> removeGalleryItem(String id) async {
    _galleryItems.removeWhere((item) => item.id == id);
    await _saveGallery();
    notifyListeners();
  }

  Future<void> removeNotesItem(String id) async {
    _notesItems.removeWhere((item) => item.id == id);
    await _saveNotes();
    notifyListeners();
  }

  Future<void> _saveGallery() async {
    final jsonStr =
    json.encode(_galleryItems.map((e) => e.toJson()).toList());
    await _secureStorage.write(
        key: 'decoy_gallery_items', value: jsonStr);
  }

  Future<void> _saveNotes() async {
    final jsonStr =
    json.encode(_notesItems.map((e) => e.toJson()).toList());
    await _secureStorage.write(
        key: 'decoy_notes_items', value: jsonStr);
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import '../services/duress_service.dart';

/// 🔐 Panic modes (used across setup + login)
enum PanicMode { notes, gallery, email }

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final DuressService _duressService = DuressService();

  bool _isInitialized = false;
  bool _isAuthenticated = false;

  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated;

  // ---------- INIT ----------
  Future<void> initialize() async {
    final hasSetup = await _secureStorage.read(key: 'setup_complete');
    _isInitialized = hasSetup == 'true';
    notifyListeners();
  }

  // ---------- SETUP ----------
  Future<bool> setupPins({
    required String vaultPin,
    required String panicPin,
    required PanicMode panicMode,
  }) async {
    try {
      // Store PIN hashes securely
      await _secureStorage.write(
        key: 'pin_vault',
        value: _hashPin(vaultPin),
      );
      await _secureStorage.write(
        key: 'pin_panic',
        value: _hashPin(panicPin),
      );

      await _secureStorage.write(
        key: 'setup_complete',
        value: 'true',
      );

      // Store panic mode (non-sensitive)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('panic_mode', panicMode.name);

      _isInitialized = true;
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ---------- AUTH ----------
  Future<String> authenticate(String pin) async {
    final hashed = _hashPin(pin);

    // 🔴 Panic PIN first (important)
    final panicHash = await _secureStorage.read(key: 'pin_panic');
    if (hashed == panicHash) {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString('panic_mode');

      if (mode == PanicMode.email.name) {
        // Silent alert + fake failure
        _duressService.sendDuressAlert();
        return 'invalid';
      }

      // Dummy notes / gallery
      return mode ?? 'invalid';
    }

    // ✅ Vault PIN
    final vaultHash = await _secureStorage.read(key: 'pin_vault');
    if (hashed == vaultHash) {
      _isAuthenticated = true;
      notifyListeners();
      return 'vault';
    }

    return 'invalid';
  }

  // ---------- RESET ----------
  Future<void> resetAllPins() async {
    await _secureStorage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isInitialized = false;
    _isAuthenticated = false;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  // ---------- HELPERS ----------
  String _hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  // ---------- EMAIL SETTINGS ----------
  Future<String?> getEmergencyEmail() =>
      _duressService.getEmergencyEmail();

  Future<void> setEmergencyEmail(String email) =>
      _duressService.setEmergencyEmail(email);

  Future<bool> isSilentAlertEnabled() =>
      _duressService.isSilentAlertEnabled();

  Future<void> setSilentAlertEnabled(bool enabled) =>
      _duressService.setSilentAlertEnabled(enabled);
}
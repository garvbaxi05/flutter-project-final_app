import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class DuressService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> getEmergencyEmail() async {
    return await _secureStorage.read(key: 'emergency_email');
  }

  Future<void> setEmergencyEmail(String email) async {
    await _secureStorage.write(key: 'emergency_email', value: email);
  }

  Future<bool> isSilentAlertEnabled() async {
    final enabled = await _secureStorage.read(key: 'silent_alert_enabled');
    return enabled == 'true';
  }

  Future<void> setSilentAlertEnabled(bool enabled) async {
    await _secureStorage.write(
      key: 'silent_alert_enabled',
      value: enabled.toString(),
    );
  }

  Future<String> _getLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied by user');
          return 'Location unavailable (permission denied)';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permission permanently denied');
        return 'Location unavailable (permission permanently denied)';
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      ).timeout(const Duration(seconds: 5));

      return 'Lat: ${position.latitude.toStringAsFixed(4)}, '
          'Long: ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      print('Location error: $e');
      return 'Location unavailable (error: ${e.toString()})';
    }
  }

  Future<bool> sendDuressAlert() async {
    try {
      final email = await getEmergencyEmail();
      final enabled = await isSilentAlertEnabled();

      if (email == null || email.isEmpty || !enabled) {
        print('🚨 Alert not sent: email=$email, enabled=$enabled');
        return false;
      }

      final timestamp = DateTime.now().toIso8601String();
      final location = await _getLocation();

      print('🚨 DURESS ALERT TRIGGERED');
      print('Sending to: $email');
      print('Timestamp: $timestamp');
      print('Location: $location');

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id': 'service_4fjzw5i',
          'template_id': 'template_gdx87bi',
          'user_id': 'wPp2CeU0kKoIzJpZb',
          'accessToken': 'wPp2CeU0kKoIzJpZb',
          'template_params': {
            'to_email': email,
            'from_name': 'Secure Vault App',
            'subject': '🚨 DURESS ALERT - Secure Vault Pro',
            'timestamp': timestamp,
            'location': location,
            'message': '''🚨 EMERGENCY ALERT 🚨

The DURESS PIN was entered on Secure Vault app.

⏰ Time: $timestamp
📍 Location: $location

⚠️ This is an automated security alert. If you did not trigger this, please contact the user immediately.

This may indicate the user is in danger or under duress.

---
Do not reply to this email.
Sent automatically by Secure Vault App''',
          },
        }),
      ).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Alert sent successfully');
        return true;
      } else {
        print('❌ Alert failed with status ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Alert exception: $e');
      return false;
    }
  }
}

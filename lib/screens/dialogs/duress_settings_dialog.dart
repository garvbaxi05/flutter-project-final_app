import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class DuressSettingsDialog extends StatefulWidget {
  const DuressSettingsDialog({super.key});

  @override
  State<DuressSettingsDialog> createState() =>
      _DuressSettingsDialogState();
}

class _DuressSettingsDialogState
    extends State<DuressSettingsDialog> {
  final _emailController = TextEditingController();

  bool _silentAlertEnabled = false;
  bool _isLoading = true;
  String _locationPermissionStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission =
      await Geolocator.checkPermission();

      setState(() {
        switch (permission) {
          case LocationPermission.denied:
            _locationPermissionStatus =
            '❌ Not granted';
            break;
          case LocationPermission.deniedForever:
            _locationPermissionStatus =
            '❌ Permanently denied';
            break;
          case LocationPermission.whileInUse:
          case LocationPermission.always:
            _locationPermissionStatus =
            '✅ Granted';
            break;
          default:
            _locationPermissionStatus =
            '⚠️ Unknown';
        }
      });
    } catch (e) {
      setState(() {
        _locationPermissionStatus =
        '⚠️ Error checking';
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      final permission =
      await Geolocator.requestPermission();

      await _checkLocationPermission();

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                  'Please enable location in app settings'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadSettings() async {
    final authProvider =
    Provider.of<AuthProvider>(
        context,
        listen: false);

    final email =
    await authProvider.getEmergencyEmail();
    final enabled =
    await authProvider.isSilentAlertEnabled();

    setState(() {
      _emailController.text = email ?? '';
      _silentAlertEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_silentAlertEnabled &&
        !_isValidEmail(
            _emailController.text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
            content:
            Text('Please enter a valid email address')),
      );
      return;
    }

    final authProvider =
    Provider.of<AuthProvider>(
        context,
        listen: false);

    if (_emailController.text.isNotEmpty) {
      await authProvider
          .setEmergencyEmail(
          _emailController.text);
    }

    await authProvider
        .setSilentAlertEnabled(
        _silentAlertEnabled);

    if (_silentAlertEnabled) {
      await _requestLocationPermission();
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
            content:
            Text('Duress settings saved')),
      );
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(
        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
        .hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.shield,
              color: Colors.orange[700]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Duress PIN Settings',
              overflow:
              TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
        height: 100,
        child: Center(
            child:
            CircularProgressIndicator()),
      )
          : SizedBox(
        width: MediaQuery.of(context)
            .size
            .width *
            0.85,
        child:
        SingleChildScrollView(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Container(
                padding:
                const EdgeInsets
                    .all(12),
                decoration:
                BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),

                    borderRadius:
                  BorderRadius
                      .circular(
                      8),
                ),
                child: Row(
                  children: [
                    Icon(
                        Icons
                            .info_outline,
                        size: 20,
                        color: Colors
                            .orange[
                        700]),
                    const SizedBox(
                        width: 8),
                    Expanded(
                      child: Text(
                        'When duress PIN is entered, it will appear as a failed login but silently send an alert.',
                        style: TextStyle(
                            fontSize:
                            12,
                            color: Colors
                                .grey[
                            700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                  height: 20),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  color: Colors.white,
                ),
                cursorColor: const Color(0xFFFF3B30),
                decoration: InputDecoration(
                  labelText: 'Emergency Contact Email',
                  labelStyle: const TextStyle(
                    color: Colors.white70,
                  ),
                  hintText: 'alert@example.com',
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.white70,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E), // 🔥 matches PIN boxes
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Colors.white12,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFFFF3B30),
                      width: 2,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                  height: 16),
              SwitchListTile(
                value:
                _silentAlertEnabled,
                onChanged: (val) =>
                    setState(() =>
                    _silentAlertEnabled =
                        val),
                title: const Text(
                    'Enable Silent Alert'),
                subtitle: const Text(
                  'Send email notification when duress PIN is used',
                  style: TextStyle(
                      fontSize: 12),
                ),
                contentPadding:
                EdgeInsets.zero,
              ),
              const SizedBox(
                  height: 12),
              Container(
                padding:
                const EdgeInsets
                    .all(12),
                decoration:
                BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.3),
                  borderRadius:
                  BorderRadius
                      .circular(
                      8),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                            Icons
                                .location_on,
                            size: 18,
                            color: Colors
                                .blue),
                        SizedBox(
                            width: 8),
                        Text(
                          'Location Permission',
                          style: TextStyle(
                              fontWeight:
                              FontWeight
                                  .w600,
                              fontSize:
                              13),
                        ),
                      ],
                    ),
                    const SizedBox(
                        height: 8),
                    Text(
                      'Status: $_locationPermissionStatus',
                      style:
                      const TextStyle(
                          fontSize:
                          12),
                    ),
                    const SizedBox(
                        height: 8),
                    SizedBox(
                      width: double
                          .infinity,
                      child:
                      OutlinedButton
                          .icon(
                        onPressed:
                        _requestLocationPermission,
                        icon: const Icon(
                            Icons
                                .gps_fixed,
                            size: 16),
                        label: const Text(
                          'Request Permission',
                          style:
                          TextStyle(
                              fontSize:
                              12),
                        ),
                        style:
                        OutlinedButton
                            .styleFrom(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              vertical:
                              8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text(
              'Save Settings'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

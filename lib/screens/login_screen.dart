import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import 'real_vault_screen.dart';
import 'fake_gallery_screen.dart';
import 'fake_notes_screen.dart';
import 'dialogs/duress_settings_dialog.dart';
import 'setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isShaking = false;
  bool _showShieldIcon = false;

  @override
  void initState() {
    super.initState();
    _loadPanicMode();
  }

  Future<void> _loadPanicMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('panic_mode');

    if (!mounted) return;

    setState(() {
      _showShieldIcon = (mode == 'email');
    });
  }

  Future<void> _authenticate() async {
    if (_controller.text.length != 4) return;

    final res =
        await Provider.of<AuthProvider>(context, listen: false)
            .authenticate(_controller.text);

    if (res == 'invalid') {
      HapticFeedback.heavyImpact();
      setState(() => _isShaking = true);

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _isShaking = false;
          _controller.clear();
        });
      }
      return;
    }

    Widget target;
    if (res == 'vault') {
      target = const RealVaultScreen();
    } else if (res == 'notes') {
      target = const FakeNotesScreen();
    } else if (res == 'gallery') {
      target = const FakeGalleryScreen();
    } else {
      return;
    }

    if (mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => target));
      _controller.clear();
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => const DuressSettingsDialog(),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reset All PINs?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all PINs and vault data.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              await authProvider.resetAllPins();

              if (!mounted) return;

              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final titleText = auth.isInitialized ? "ENTER PIN" : "Enter PIN";

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF3B0D0D),
                Color(0xFF0E0E0E),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  /// TOP ICONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_showShieldIcon)
                        IconButton(
                          icon: const Icon(Icons.shield_outlined,
                              color: Colors.white70),
                          onPressed: _showSettingsDialog,
                        )
                      else
                        const SizedBox(width: 48),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded,
                            color: Colors.white70),
                        onPressed: _showResetDialog,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  /// TITLE
                  Text(
                    titleText,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Enter your 4-digit PIN',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 50),

                  /// HIDDEN INPUT
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// PIN BOXES (WITH POP ANIMATION)
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: Row(
                      children: List.generate(4, (i) {
                        final filled = i < _controller.text.length;
                        final isActive = i == _controller.text.length;

                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFFFF3B30)
                                    : Colors.white12,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: AnimatedScale(
                              scale: filled ? 1.2 : 1,
                              duration:
                                  const Duration(milliseconds: 120),
                              curve: Curves.easeOutBack,
                              child: Text(
                                filled ? '●' : '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    )
                        .animate(target: _isShaking ? 1 : 0)
                        .shake(hz: 5, duration: 500.ms),
                  ),

                  const Spacer(),

                  /// CONTINUE BUTTON (FADE ENABLE)
                  AnimatedOpacity(
                    opacity:
                        _controller.text.length == 4 ? 1 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _controller.text.length == 4
                                ? _authenticate
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFF3B30),
                          padding:
                              const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
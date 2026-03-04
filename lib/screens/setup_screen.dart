import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_provider.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  int step = 0;

  PanicMode? selectedMode;

  final vaultPinCtrl = TextEditingController();
  final panicPinCtrl = TextEditingController();
  final emailCtrl = TextEditingController();

  bool silentAlert = true;

  late final AnimationController _stepAnimCtrl;

  @override
  void initState() {
    super.initState();
    _stepAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
  }

  @override
  void dispose() {
    _stepAnimCtrl.dispose();
    vaultPinCtrl.dispose();
    panicPinCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  // ---------- VALIDATION ----------
  bool get canContinue {
    if (step == 0) return selectedMode != null;

    if (step == 1) {
      if (vaultPinCtrl.text.length != 4) return false;
      if (panicPinCtrl.text.length != 4) return false;
      if (vaultPinCtrl.text == panicPinCtrl.text) return false;

      if (selectedMode == PanicMode.email &&
          silentAlert &&
          !_isValidEmail(emailCtrl.text)) {
        return false;
      }
      return true;
    }

    return false;
  }

  // ---------- FINISH ----------
  Future<void> _finish() async {
    final auth = context.read<AuthProvider>();

    await auth.setupPins(
      vaultPin: vaultPinCtrl.text,
      panicPin: panicPinCtrl.text,
      panicMode: selectedMode!,
    );

    if (selectedMode == PanicMode.email) {
      await auth.setEmergencyEmail(emailCtrl.text);
      await auth.setSilentAlertEnabled(silentAlert);

      if (silentAlert) {
        try {
          await Geolocator.requestPermission();
        } catch (_) {}
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$')
        .hasMatch(email);
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Security Setup")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _progressBar(),
              const SizedBox(height: 30),

              /// 🔽 Animated + Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      );
                    },
                    child: step == 0
                        ? _panicModeStep(key: const ValueKey(0))
                        : _setPinsStep(key: const ValueKey(1)),
                  ),
                ),
              ),

              /// 🔒 Fixed Bottom Buttons
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    if (step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _stepAnimCtrl.reset();
                            _stepAnimCtrl.forward();
                            setState(() => step--);
                          },
                          child: const Text("Back"),
                        ),
                      ),
                    if (step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: canContinue
                            ? () {
                                _stepAnimCtrl.reset();
                                _stepAnimCtrl.forward();
                                if (step == 0) {
                                  setState(() => step = 1);
                                } else {
                                  _finish();
                                }
                              }
                            : null,
                        child:
                            Text(step == 0 ? "Next" : "Complete Setup"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- COMPONENTS ----------

  Widget _progressBar() {
    return Row(
      children: List.generate(
        2,
        (i) => Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 4,
            decoration: BoxDecoration(
              color: i <= step ? Colors.white : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- STEP 1 ----------
  Widget _panicModeStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Choose Panic Mode",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "When someone forces you to unlock, what should happen?",
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 24),

        _modeCard(
          PanicMode.notes,
          "Dummy Notes",
          "Shows a fake notes app",
        ),
        _modeCard(
          PanicMode.gallery,
          "Dummy Gallery",
          "Shows a fake gallery",
        ),
        _modeCard(
          PanicMode.email,
          "Email Alert",
          "Silent email + failed login",
        ),
      ],
    );
  }

  Widget _modeCard(
    PanicMode mode,
    String title,
    String subtitle,
  ) {
    final selected = selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? Colors.white10 : Colors.white12,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.red : Colors.white12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- STEP 2 ----------
  Widget _setPinsStep({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Set Your PINs",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Two different PINs — one real, one panic.",
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 24),

        _pinField(
          "Vault PIN",
          "Opens your real vault",
          vaultPinCtrl,
        ),
        const SizedBox(height: 20),
        _pinField(
          "Panic PIN",
          "Triggers: ${_panicLabel()}",
          panicPinCtrl,
        ),

        if (selectedMode == PanicMode.email) ...[
          const SizedBox(height: 20),
          TextField(
            controller: emailCtrl,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(labelText: "Emergency Email"),
          ),
          SwitchListTile(
            value: silentAlert,
            onChanged: (v) => setState(() => silentAlert = v),
            title: const Text("Enable Silent Alert"),
          ),
        ],

        const SizedBox(height: 16),
        _warningBox(),
      ],
    );
  }

  Widget _pinField(
    String title,
    String subtitle,
    TextEditingController ctrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle,
            style:
                const TextStyle(fontSize: 12, color: Colors.white54)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            counterText: '',
            hintText: "••••",
          ),
        ),
      ],
    );
  }

  Widget _warningBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: const Text(
        "PINs must be different.\nThey cannot be recovered.",
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  String _panicLabel() {
    switch (selectedMode) {
      case PanicMode.notes:
        return "Dummy Notes";
      case PanicMode.gallery:
        return "Dummy Gallery";
      case PanicMode.email:
        return "Email Alert";
      default:
        return "";
    }
  }
}
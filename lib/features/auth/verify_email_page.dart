import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/features/auth/auth_gate.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';
import 'package:e_barangay_mo/core/widgets/press_scale.dart';

/// Asks for the 6-digit code the server emailed. Shown after sign-up, or
/// after logging in to an account that was never verified.
///
/// The password is kept only in this page's memory: the server needs it with
/// the code, so a code alone can't take over an account.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  static const _cooldown = 60;

  final code = TextEditingController();
  bool isVerifying = false;
  bool isResending = false;
  int secondsLeft = _cooldown; // a code was just sent
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    code.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = _cooldown]) {
    _timer?.cancel();
    setState(() => secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 1) t.cancel();
      setState(() => secondsLeft = secondsLeft > 0 ? secondsLeft - 1 : 0);
    });
  }

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> verify() async {
    final value = code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      _show("Enter the 6-digit code from the email.");
      return;
    }

    setState(() => isVerifying = true);
    try {
      await ApiService.verifyEmail(
        email: widget.email,
        password: widget.password,
        code: value,
      );
      if (!mounted) return;
      goToAuthGate(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      code.clear();
      _show(e.message);
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<void> resend() async {
    setState(() => isResending = true);
    try {
      final message = await ApiService.resendCode(widget.email, widget.password);
      if (!mounted) return;
      code.clear();
      _startCooldown();
      _show(message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _show(e.message);
    } finally {
      if (mounted) setState(() => isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Verify your email")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 56),
                  const SizedBox(height: AppSpace.s4),
                  Text("Check your email", style: text.titleLarge),
                  const SizedBox(height: AppSpace.s1),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: "We sent a 6-digit code to\n"),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(
                          text: ".\nIt expires in 10 minutes. Check your spam folder too."),
                    ]),
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s6),

                  TextField(
                    controller: code,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: text.headlineSmall?.copyWith(letterSpacing: 8),
                    onSubmitted: (_) => isVerifying ? null : verify(),
                    decoration: const InputDecoration(
                      labelText: "Verification code",
                      counterText: "",
                      prefixIcon: Icon(PhosphorIconsRegular.envelope),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),

                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      enabled: !isVerifying,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : verify,
                        child: isVerifying
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onPrimary,
                                ),
                              )
                            : const Text("Verify and continue"),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s3),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed:
                          secondsLeft > 0 || isResending ? null : resend,
                      child: Text(secondsLeft > 0
                          ? "Send a new code in ${secondsLeft}s"
                          : "Send a new code"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

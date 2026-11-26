import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';
import 'package:e_barangay_mo/core/widgets/press_scale.dart';

/// "Forgot password" in two steps on one page:
///  1. enter the email, and the server emails a 6-digit code;
///  2. enter the code and a new password.
/// After a reset every session is signed out, so the user logs in again.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _cooldown = 60;

  late final email = TextEditingController(text: widget.initialEmail);
  final code = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  bool codeSent = false;
  bool isBusy = false;
  int secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    email.dispose();
    code.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft <= 1) t.cancel();
      setState(() => secondsLeft = secondsLeft > 0 ? secondsLeft - 1 : 0);
    });
  }

  void _show(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String get _email => email.text.trim().toLowerCase();

  Future<void> sendCode() async {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email)) {
      _show("Enter the email you registered with.");
      return;
    }

    setState(() => isBusy = true);
    try {
      final message = await ApiService.forgotPassword(_email);
      if (!mounted) return;
      setState(() => codeSent = true);
      code.clear();
      _startCooldown();
      _show(message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _show(e.message);
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> resetPassword() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) {
      _show("Enter the 6-digit code from the email.");
      return;
    }
    if (password.text.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(password.text) ||
        !RegExp(r'\d').hasMatch(password.text)) {
      _show("Use at least 8 characters with letters and numbers.");
      return;
    }
    if (password.text != confirm.text) {
      _show("The passwords don't match.");
      return;
    }

    setState(() => isBusy = true);
    try {
      final message = await ApiService.resetPassword(
        email: _email,
        code: code.text.trim(),
        password: password.text,
      );
      if (!mounted) return;
      _show(message);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      _show(e.message);
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Reset password")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpace.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandMark(size: 56)),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    codeSent ? "Check your email" : "Forgot your password?",
                    style: text.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    codeSent
                        ? "Enter the 6-digit code we sent to $_email and choose a new password. "
                            "The code expires in 10 minutes. Check your spam folder too."
                        : "Enter the email you registered with. We'll send you a 6-digit code.",
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s6),
                  TextField(
                    controller: email,
                    enabled: !codeSent,
                    autofocus: !codeSent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) => isBusy || codeSent ? null : sendCode(),
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(PhosphorIconsRegular.envelope),
                    ),
                  ),
                  if (codeSent) ..._resetFields(text),
                  const SizedBox(height: AppSpace.s6),
                  _primaryButton(context),
                  if (codeSent) ...[
                    const SizedBox(height: AppSpace.s3),
                    OutlinedButton(
                      onPressed: secondsLeft > 0 || isBusy ? null : sendCode,
                      child: Text(secondsLeft > 0
                          ? "Send a new code in ${secondsLeft}s"
                          : "Send a new code"),
                    ),
                    TextButton(
                      onPressed: isBusy
                          ? null
                          : () => setState(() {
                                codeSent = false;
                                _timer?.cancel();
                                secondsLeft = 0;
                              }),
                      child: const Text("Use a different email"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _resetFields(TextTheme text) => [
        const SizedBox(height: AppSpace.s4),
        TextField(
          controller: code,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: text.headlineSmall?.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: "Reset code",
            counterText: "",
            prefixIcon: Icon(PhosphorIconsRegular.envelope),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        TextField(
          controller: password,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(
            labelText: "New password",
            helperText: "At least 8 characters, with letters and numbers",
            prefixIcon: Icon(PhosphorIconsRegular.lock),
          ),
        ),
        const SizedBox(height: AppSpace.s4),
        TextField(
          controller: confirm,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onSubmitted: (_) => isBusy ? null : resetPassword(),
          decoration: const InputDecoration(
            labelText: "Confirm new password",
            prefixIcon: Icon(PhosphorIconsRegular.lock),
          ),
        ),
      ];

  Widget _primaryButton(BuildContext context) {
    final c = context.colors;
    return PressScale(
      enabled: !isBusy,
      child: ElevatedButton(
        onPressed: isBusy ? null : (codeSent ? resetPassword : sendCode),
        child: isBusy
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.onPrimary),
              )
            : Text(codeSent ? "Reset password" : "Send code"),
      ),
    );
  }
}

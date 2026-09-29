import 'package:flutter/material.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/auth/auth_gate.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/widgets/app_card.dart';
import 'package:e_barangay_mo/widgets/brand_logo.dart';
import 'package:e_barangay_mo/widgets/press_scale.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();

  bool isLoading = false;

  void signUp() async {
    try {
      setState(() => isLoading = true);

      // One request: the server creates the account (always as a
      // resident) and logs the user in.
      await ApiService.register(
        fullName: fullName.text.trim(),
        email: email.text.trim(),
        password: password.text,
      );

      if (!mounted) return;
      goToAuthGate(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Create account")),
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
                  Text("Resident registration", style: text.titleLarge),
                  const SizedBox(height: AppSpace.s1),
                  Text(
                    "Use your real name. It appears on your documents.",
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.s6),

                  TextField(
                    controller: fullName,
                    decoration: const InputDecoration(
                      labelText: "Full name",
                      prefixIcon: Icon(PhosphorIconsRegular.user),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),

                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      prefixIcon: Icon(PhosphorIconsRegular.envelope),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s4),

                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password",
                      helperText: "At least 8 characters, with letters and numbers",
                      prefixIcon: Icon(PhosphorIconsRegular.lock),
                    ),
                  ),
                  const SizedBox(height: AppSpace.s6),

                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      enabled: !isLoading,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : signUp,
                        child: isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.onPrimary,
                                ),
                              )
                            : const Text("Sign up"),
                      ),
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

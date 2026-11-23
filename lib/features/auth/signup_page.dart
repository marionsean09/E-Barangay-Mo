import 'package:flutter/material.dart';
import 'package:e_barangay_mo/core/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/features/auth/google_sign_in_section.dart';
import 'package:e_barangay_mo/features/auth/privacy_notice.dart';
import 'package:e_barangay_mo/features/auth/verify_email_page.dart';
import 'package:e_barangay_mo/core/theme/app_colors.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/core/widgets/app_card.dart';
import 'package:e_barangay_mo/core/widgets/brand_logo.dart';
import 'package:e_barangay_mo/core/widgets/press_scale.dart';

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
  bool acceptedPrivacy = false;

  void signUp() async {
    try {
      setState(() => isLoading = true);

      // The server creates the account (always as a resident) and emails a
      // code. The user is logged in only after entering it.
      final address = email.text.trim().toLowerCase();
      await ApiService.register(
        fullName: fullName.text.trim(),
        email: address,
        password: password.text,
        privacyConsent: acceptedPrivacy,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VerifyEmailPage(email: address, password: password.text),
        ),
      );
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
                  const SizedBox(height: AppSpace.s4),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: acceptedPrivacy,
                        onChanged: (value) =>
                            setState(() => acceptedPrivacy = value ?? false),
                      ),
                      const SizedBox(width: AppSpace.s2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.s2),
                              child: Text(
                                "I have read the privacy notice and consent to the processing of my personal information.",
                                style: text.bodySmall,
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => showPrivacyNotice(context),
                              child: const Text("Read the privacy notice"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.s4),

                  SizedBox(
                    width: double.infinity,
                    child: PressScale(
                      enabled: !isLoading && acceptedPrivacy,
                      child: ElevatedButton(
                        onPressed: isLoading || !acceptedPrivacy ? null : signUp,
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
                  GoogleSignInSection(
                    signUp: true,
                    privacyConsent: acceptedPrivacy,
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

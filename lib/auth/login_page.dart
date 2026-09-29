import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:e_barangay_mo/theme/phosphor_icons.dart';
import 'package:e_barangay_mo/services/api_service.dart';
import 'package:e_barangay_mo/auth/auth_gate.dart';

import 'package:e_barangay_mo/auth/signup_page.dart';
import 'package:e_barangay_mo/theme/app_colors.dart';
import 'package:e_barangay_mo/theme/app_tokens.dart';
import 'package:e_barangay_mo/widgets/app_card.dart';
import 'package:e_barangay_mo/widgets/brand_logo.dart';
import 'package:e_barangay_mo/widgets/hero_panel.dart';
import 'package:e_barangay_mo/widgets/press_scale.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  void login() async {
    try {
      setState(() => isLoading = true);

      await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
      );

      if (!mounted) return;
      goToAuthGate(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final form = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _form(context),
            );

            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: c.heroGradient),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.s8),
                          child: _cover(context, wordmarkSize: 80),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpace.s8),
                        child: form,
                      ),
                    ),
                  ),
                ],
              );
            }

            const overlap = 40.0;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: c.heroGradient,
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.lg)),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpace.s6,
                            AppSpace.s6, AppSpace.s6, AppSpace.s8 + overlap),
                        child: _cover(context, wordmarkSize: 52),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpace.s4),
                    child: HeroOverlap(
                      amount: overlap,
                      child: Center(child: form),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cover(BuildContext context, {required double wordmarkSize}) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final wordmark = text.headlineMedium?.copyWith(
      fontSize: wordmarkSize,
      height: 0.95,
      letterSpacing: -0.03 * wordmarkSize,
      color: c.onHero,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BrandSeal(
          size: wordmarkSize >= 80 ? 280 : 168,
          style: BrandSealStyle.onRed,
        ),
        const SizedBox(height: AppSpace.s8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              label: 'eBarangay Mo',
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: "eBarangay\n"),
                    TextSpan(
                        text: "Mo", style: TextStyle(color: c.onHeroMuted)),
                  ]),
                  style: wordmark,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            Text("Barangay services, one tap away.",
                style: text.bodyLarge?.copyWith(color: c.onHeroMuted)),
          ],
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Log in", style: text.titleLarge),
          const SizedBox(height: AppSpace.s1),
          Text("Use the email you registered with.", style: text.bodySmall),
          const SizedBox(height: AppSpace.s6),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: "Email",
              prefixIcon: Icon(PhosphorIconsRegular.envelope),
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          TextField(
            controller: passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => isLoading ? null : login(),
            decoration: const InputDecoration(
              labelText: "Password",
              prefixIcon: Icon(PhosphorIconsRegular.lock),
            ),
          ),
          const SizedBox(height: AppSpace.s6),
          PressScale(
            enabled: !isLoading,
            child: ElevatedButton(
              onPressed: isLoading ? null : login,
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.onPrimary),
                    )
                  : const Text("Log in"),
            ),
          ),
          const SizedBox(height: AppSpace.s3),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupPage()),
              );
            },
            child: const Text("Create an account"),
          ),
        ],
      ),
    );
  }
}

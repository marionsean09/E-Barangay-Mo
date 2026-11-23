import 'package:flutter/material.dart';

import 'package:e_barangay_mo/core/services/api_service.dart';
import 'package:e_barangay_mo/core/services/google_auth.dart';
import 'package:e_barangay_mo/core/theme/app_tokens.dart';
import 'package:e_barangay_mo/features/auth/auth_gate.dart';
import 'package:e_barangay_mo/features/auth/google_button_io.dart'
    if (dart.library.js_interop) 'package:e_barangay_mo/features/auth/google_button_web.dart';

/// "or" divider + Google button. Hidden when the app was built without a
/// GOOGLE_CLIENT_ID, so nothing breaks before Google is set up.
class GoogleSignInSection extends StatefulWidget {
  const GoogleSignInSection({
    super.key,
    this.signUp = false,
    this.privacyConsent = false,
  });

  /// Shows "Sign up with Google" instead of "Continue with Google".
  final bool signUp;

  /// Whether the privacy notice was accepted on the sign-up page.
  final bool privacyConsent;

  @override
  State<GoogleSignInSection> createState() => _GoogleSignInSectionState();
}

class _GoogleSignInSectionState extends State<GoogleSignInSection> {
  late final Future<void> _ready = GoogleAuth.ensureInitialized();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (GoogleAuth.isConfigured) {
      GoogleAuth.listen(onToken: _onToken, onError: _onError);
    }
  }

  @override
  void dispose() {
    GoogleAuth.stopListening(_onToken);
    super.dispose();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onToken(String idToken) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ApiService.googleLogin(idToken,
          privacyConsent: widget.signUp && widget.privacyConsent);
      if (!mounted) return;
      goToAuthGate(context);
    } on ApiException catch (e) {
      await GoogleAuth.signOut();
      _show(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onError(Object error) =>
      _show("Google sign-in didn't work. Please try again.");

  Future<void> _signInOnDevice() async {
    try {
      await GoogleAuth.signInOnDevice();
    } on Exception catch (e) {
      _onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoogleAuth.isConfigured) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpace.s4),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
            child: Text("or", style: text.bodySmall),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: AppSpace.s4),
        FutureBuilder<void>(
          future: _ready,
          builder: (context, snapshot) {
            if (_busy || snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return Text("Google sign-in is unavailable right now.",
                  style: text.bodySmall, textAlign: TextAlign.center);
            }
            if (widget.signUp && !widget.privacyConsent) {
              return Text("Accept the privacy notice to sign up with Google.",
                  style: text.bodySmall, textAlign: TextAlign.center);
            }
            return Center(
              child: googlePlatformButton(
                signUp: widget.signUp,
                onPressed: _signInOnDevice,
              ),
            );
          },
        ),
      ],
    );
  }
}

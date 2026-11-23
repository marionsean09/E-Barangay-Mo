import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// "Sign in with Google". Google returns an ID token, which the app hands to
/// the Laravel API; the server checks it with Google before logging in.
///
/// Set the OAuth Web client ID at build time:
///   --dart-define=GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
/// Without it, the Google button is simply not shown.
class GoogleAuth {
  static const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static bool get isConfigured => clientId.isNotEmpty;

  static Future<void>? _ready;

  /// Only the Google button currently on screen receives results, so a
  /// sign-in is never handled twice (e.g. sign-up page pushed over login).
  static void Function(String idToken)? _onToken;
  static void Function(Object error)? _onError;

  static Future<void> ensureInitialized() => _ready ??= () async {
        await GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? clientId : null,
          serverClientId: kIsWeb ? null : clientId,
        );
        GoogleSignIn.instance.authenticationEvents.listen(
          (event) {
            if (event is GoogleSignInAuthenticationEventSignIn) {
              final token = event.user.authentication.idToken;
              if (token != null) _onToken?.call(token);
            }
          },
          onError: (Object error) {
            final canceled = error is GoogleSignInException &&
                (error.code == GoogleSignInExceptionCode.canceled ||
                    error.code == GoogleSignInExceptionCode.interrupted);
            if (!canceled) _onError?.call(error);
          },
        );
      }();

  static void listen({
    required void Function(String idToken) onToken,
    required void Function(Object error) onError,
  }) {
    _onToken = onToken;
    _onError = onError;
  }

  static void stopListening(void Function(String idToken) onToken) {
    if (identical(_onToken, onToken)) {
      _onToken = null;
      _onError = null;
    }
  }

  /// Mobile only. On the web, Google's own rendered button starts sign-in.
  static Future<void> signInOnDevice() async {
    await ensureInitialized();
    try {
      await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) rethrow;
    }
  }

  /// Forget the Google account choice so the next sign-in asks again.
  static Future<void> signOut() async {
    if (_ready == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } on Exception {
      // Already signed out of Google: nothing to do.
    }
  }
}

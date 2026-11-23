import 'package:flutter/material.dart';

/// Android / iOS: a regular button that opens the Google account picker.
Widget googlePlatformButton({required bool signUp, required VoidCallback onPressed}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Text("G", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
    label: Text(signUp ? "Sign up with Google" : "Continue with Google"),
  );
}

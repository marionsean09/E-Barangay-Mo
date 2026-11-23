import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Google's official button. Google requires its own rendered button on the
/// web; tapping it opens Google's account picker.
Widget googlePlatformButton({required bool signUp, required VoidCallback onPressed}) {
  return SizedBox(
    height: 44,
    child: web.renderButton(
      configuration: web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        shape: web.GSIButtonShape.pill,
        text: signUp ? web.GSIButtonText.signupWith : web.GSIButtonText.continueWith,
        minimumWidth: 280,
      ),
    ),
  );
}

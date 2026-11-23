import 'dart:ui' show VoidCallback;

/// Browser notifications exist only on the web. In-app alerts still work here.
bool get browserAlertsSupported => false;

String get browserAlertPermission => 'denied';

bool get appIsHidden => false;

Future<bool> requestBrowserAlerts() async => false;

void showBrowserAlert({
  required String title,
  required String body,
  required String tag,
  required VoidCallback onTap,
}) {}

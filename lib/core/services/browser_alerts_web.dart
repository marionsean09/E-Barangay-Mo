import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show VoidCallback;

@JS('Notification')
extension type _Notification._(JSObject _) implements JSObject {
  external factory _Notification(String title, [_Options? options]);
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
  external set onclick(JSFunction? handler);
  external void close();
}

extension type _Options._(JSObject _) implements JSObject {
  external factory _Options({String body, String tag});
}

@JS('document.hidden')
external bool get _documentHidden;

@JS('window.focus')
external void _focusWindow();

bool get browserAlertsSupported => globalContext.has('Notification');

/// "default" (not asked yet), "granted" or "denied".
String get browserAlertPermission =>
    browserAlertsSupported ? _Notification.permission : 'denied';

bool get appIsHidden => _documentHidden;

/// Browsers only allow this right after a user action, such as a tap.
Future<bool> requestBrowserAlerts() async {
  if (!browserAlertsSupported) return false;
  final result = await _Notification.requestPermission().toDart;
  return result.toDart == 'granted';
}

void showBrowserAlert({
  required String title,
  required String body,
  required String tag,
  required VoidCallback onTap,
}) {
  if (browserAlertPermission != 'granted') return;
  try {
    late final _Notification alert;
    alert = _Notification(title, _Options(body: body, tag: tag));
    alert.onclick = (JSAny? _) {
      _focusWindow();
      alert.close();
      onTap();
    }.toJS;
  } catch (_) {
    // Some mobile browsers refuse this constructor. The in-app alert remains.
  }
}

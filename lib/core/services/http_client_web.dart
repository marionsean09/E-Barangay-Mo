import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

// withCredentials lets the browser store and send the httpOnly refresh
// cookie. Dart code can never read that cookie.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;

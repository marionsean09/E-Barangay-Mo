import 'package:http/http.dart' as http;

// Mobile/desktop builds. The web build is the supported target: only a
// browser stores the httpOnly refresh cookie (see http_client_web.dart).
http.Client createHttpClient() => http.Client();

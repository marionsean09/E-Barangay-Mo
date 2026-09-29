import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:e_barangay_mo/models/app_user.dart';
import 'package:e_barangay_mo/models/concern.dart';
import 'package:e_barangay_mo/services/http_client_io.dart'
    if (dart.library.js_interop) 'package:e_barangay_mo/services/http_client_web.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// A file to upload: the bytes plus the filename sent in the multipart form.
typedef UploadFile = ({Uint8List bytes, String filename});

/// Talks to the Laravel API. The only thing the app knows is the API's URL:
/// no database credentials, API keys or secrets exist in the Flutter bundle.
class ApiService {
  // Same origin in production ("/api/"). For local dev pass
  // --dart-define=API_URL=http://localhost:8000/api/
  static final Uri _base = Uri.base.resolve(_withSlash(
      const String.fromEnvironment('API_URL', defaultValue: '/api/')));

  static final http.Client _client = createHttpClient();

  // Access token lives only in memory, never in localStorage, so an XSS
  // payload can't steal a long-lived credential. A page reload loses it and
  // restoreSession() gets a new one from the httpOnly refresh cookie.
  static String? _accessToken;
  static Future<bool>? _refreshing;

  static const _baseHeaders = {
    'Accept': 'application/json',
    // Required by the server's CSRF check on the cookie endpoints.
    'X-Requested-With': 'XMLHttpRequest',
  };

  static String _withSlash(String url) => url.endsWith('/') ? url : '$url/';

  // ---------------------------------------------------------------- auth

  static Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final body = await _json('POST', 'auth/register',
        body: {'full_name': fullName, 'email': email, 'password': password},
        auth: false);
    return _takeSession(body);
  }

  static Future<AppUser> login(String email, String password) async {
    final body = await _json('POST', 'auth/login',
        body: {'email': email, 'password': password}, auth: false);
    return _takeSession(body);
  }

  /// Called on app start: trades the refresh cookie (if any) for a new
  /// access token. Returns null when the user has to log in.
  static Future<AppUser?> restoreSession() async {
    try {
      final body = await _json('POST', 'auth/refresh', auth: false);
      return _takeSession(body);
    } on ApiException {
      return null;
    }
  }

  static Future<void> logout() async {
    try {
      await _json('POST', 'auth/logout', auth: false);
    } finally {
      _accessToken = null;
    }
  }

  static AppUser _takeSession(Map<String, dynamic> body) {
    _accessToken = body['accessToken'] as String;
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  // ------------------------------------------------------------- profile

  static Future<AppUser> updateProfile({
    required String fullName,
    required String email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = await _json('PATCH', 'me', body: {
      'full_name': fullName,
      'email': email,
      if (currentPassword != null && currentPassword.isNotEmpty)
        'current_password': currentPassword,
      if (newPassword != null && newPassword.isNotEmpty)
        'new_password': newPassword,
    });
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  // ------------------------------------------------------------ concerns

  static Future<List<Concern>> myConcerns() async =>
      _concerns(await _json('GET', 'concerns'));

  static Future<List<Concern>> allConcerns() async =>
      _concerns(await _json('GET', 'admin/concerns'));

  static Future<Concern> submitConcern({
    required Map<String, String> fields,
    Map<String, UploadFile> files = const {},
    List<UploadFile> evidence = const [],
  }) async {
    final response = await _send(() {
      final request = http.MultipartRequest('POST', _base.resolve('concerns'))
        ..fields.addAll(fields);
      files.forEach((key, file) => request.files.add(
          http.MultipartFile.fromBytes(key, file.bytes, filename: file.filename)));
      for (final file in evidence) {
        request.files.add(http.MultipartFile.fromBytes('evidence[]', file.bytes,
            filename: file.filename));
      }
      return request;
    });
    return Concern.fromJson(_decode(response)['concern']);
  }

  /// Admin only. Keys: status, final_date, claim_date (dates as yyyy-MM-dd).
  static Future<Concern> updateConcern(int id, Map<String, dynamic> changes) async {
    final body = await _json('PATCH', 'admin/concerns/$id', body: changes);
    return Concern.fromJson(body['concern']);
  }

  static Future<Uint8List> attachment(int id) async {
    final response =
        await _send(() => http.Request('GET', _base.resolve('attachments/$id')));
    _decode(response);
    return response.bodyBytes;
  }

  static List<Concern> _concerns(Map<String, dynamic> body) =>
      (body['concerns'] as List)
          .map((c) => Concern.fromJson(c as Map<String, dynamic>))
          .toList();

  // ------------------------------------------------------------ plumbing

  static Future<Map<String, dynamic>> _json(String method, String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    http.BaseRequest build() {
      final request = http.Request(method, _base.resolve(path));
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      return request;
    }

    final response = await _send(build, auth: auth);
    return _decode(response);
  }

  /// Sends a request with the access token. On 401 it refreshes once and
  /// retries, so callers never deal with token expiry.
  static Future<http.Response> _send(http.BaseRequest Function() build,
      {bool auth = true}) async {
    Future<http.Response> attempt() async {
      final request = build()..headers.addAll(_baseHeaders);
      if (auth && _accessToken != null) {
        request.headers['Authorization'] = 'Bearer $_accessToken';
      }
      try {
        return await http.Response.fromStream(await _client.send(request));
      } on http.ClientException {
        throw ApiException(0, "Can't reach the server. Check your connection.");
      }
    }

    var response = await attempt();
    if (auth && response.statusCode == 401 && await _refresh()) {
      response = await attempt();
    }
    return response;
  }

  /// Only one refresh at a time. Two parallel refreshes would present the
  /// same refresh token twice, which the server treats as token theft.
  static Future<bool> _refresh() => _refreshing ??= () async {
        try {
          return await restoreSession() != null;
        } finally {
          _refreshing = null;
        }
      }();

  static Map<String, dynamic> _decode(http.Response response) {
    final isJson =
        response.headers['content-type']?.contains('application/json') ?? false;
    final Map<String, dynamic> body =
        isJson && response.body.isNotEmpty ? jsonDecode(response.body) : {};

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    if (response.statusCode == 429) {
      final wait = response.headers['retry-after'];
      throw ApiException(429,
          "Too many attempts. Try again${wait == null ? ' later' : ' in $wait seconds'}.");
    }

    // Laravel validation errors: {"message": ..., "errors": {"field": ["..."]}}
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      throw ApiException(response.statusCode,
          first is List && first.isNotEmpty ? '${first.first}' : '$first');
    }
    throw ApiException(response.statusCode,
        body['message'] as String? ?? 'Something went wrong (${response.statusCode}).');
  }
}

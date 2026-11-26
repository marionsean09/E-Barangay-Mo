import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:http/http.dart' as http;

import 'package:e_barangay_mo/core/models/app_user.dart';
import 'package:e_barangay_mo/core/models/concern.dart';
import 'package:e_barangay_mo/core/models/concern_message.dart';
import 'package:e_barangay_mo/core/models/reply_notification.dart';
import 'package:e_barangay_mo/core/utils/concern_format.dart' show apiDate;
import 'package:e_barangay_mo/core/services/http_client_io.dart'
    if (dart.library.js_interop) 'package:e_barangay_mo/core/services/http_client_web.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

/// Login worked, but the email hasn't been verified yet. The server has
/// emailed a code; the app should show the code screen.
class EmailNotVerifiedException extends ApiException {
  EmailNotVerifiedException(String message) : super(403, message);
}

/// A file to upload: the bytes plus the filename sent in the multipart form.
typedef UploadFile = ({Uint8List bytes, String filename});

/// One admin list: the matching records, their total, and overall status counts.
typedef AdminConcerns = ({
  List<Concern> concerns,
  Map<String, int> counts,
  int total,
});

/// Talks to the Laravel API. The only thing the app knows is the API's URL:
/// no database credentials, API keys or secrets exist in the Flutter bundle.
class ApiService {
  // Same origin in production ("/api/"). For local dev pass
  // --dart-define=API_URL=http://localhost:8000/api/
  // Debug builds without API_URL fall back to the local Laravel server on
  // the same host the page was opened on (keeps the refresh cookie same-site).
  static const _apiUrl = String.fromEnvironment('API_URL');
  static final Uri _base = Uri.base.resolve(_withSlash(_apiUrl.isNotEmpty
      ? _apiUrl
      : kReleaseMode
          ? '/api/'
          : 'http://${Uri.base.host.isEmpty ? 'localhost' : Uri.base.host}:8000/api/'));

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

  /// Creates the account and has the server email a 6-digit code.
  /// No session yet: call [verifyEmail] with the code to log in.
  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required bool privacyConsent,
  }) async {
    await _json('POST', 'auth/register',
        body: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'privacy_consent': privacyConsent,
        },
        auth: false);
  }

  /// Throws [EmailNotVerifiedException] if the account still needs its code.
  static Future<AppUser> login(String email, String password) async {
    final body = await _json('POST', 'auth/login',
        body: {'email': email, 'password': password}, auth: false);
    return _takeSession(body);
  }

  static Future<AppUser> verifyEmail({
    required String email,
    required String password,
    required String code,
  }) async {
    final body = await _json('POST', 'auth/verify-email',
        body: {'email': email, 'password': password, 'code': code},
        auth: false);
    return _takeSession(body);
  }

  /// Trades a Google ID token for a session. The server checks the token
  /// with Google; the app never decides who the user is.
  static Future<AppUser> googleLogin(String idToken,
      {bool privacyConsent = false}) async {
    final body = await _json('POST', 'auth/google',
        body: {'id_token': idToken, 'privacy_consent': privacyConsent},
        auth: false);
    return _takeSession(body);
  }

  /// Returns the server's message, e.g. "We sent a new code to ...".
  static Future<String> resendCode(String email, String password) async {
    final body = await _json('POST', 'auth/resend-code',
        body: {'email': email, 'password': password}, auth: false);
    return body['message'] as String? ?? 'We sent a new code.';
  }

  /// Asks the server to email a password reset code. The reply is the same
  /// whether or not the email has an account.
  static Future<String> forgotPassword(String email) async {
    final body = await _json('POST', 'auth/forgot-password',
        body: {'email': email}, auth: false);
    return body['message'] as String? ?? 'Check your email for a code.';
  }

  /// Sets a new password with the emailed code. No session: log in after.
  static Future<String> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    final body = await _json('POST', 'auth/reset-password',
        body: {'email': email, 'code': code, 'password': password},
        auth: false);
    return body['message'] as String? ?? 'Your password was changed.';
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

  /// Admin only. The server sorts and filters, so results cover all records.
  static Future<AdminConcerns> adminConcerns({
    String sort = 'newest',
    String? type,
    String? status,
    String? search,
    DateTime? date,
  }) async {
    final query = Uri(queryParameters: {
      'sort': sort,
      'type': ?type,
      'status': ?status,
      if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      if (date != null) 'date': apiDate(date),
    }).query;
    final body = await _json('GET', 'admin/concerns?$query');
    return (
      concerns: _concerns(body),
      counts: (body['counts'] as Map<String, dynamic>).cast<String, int>(),
      total: body['total'] as int,
    );
  }

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

  /// Complaint conversation. The server allows only the owner and admins.
  static Future<List<ConcernMessage>> concernMessages(int concernId) async {
    final body = await _json('GET', 'concerns/$concernId/messages');
    return (body['messages'] as List)
        .map((m) => ConcernMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  static Future<ConcernMessage> sendConcernMessage(
      int concernId, String message) async {
    final body = await _json('POST', 'concerns/$concernId/messages',
        body: {'body': message});
    return ConcernMessage.fromJson(body['message'] as Map<String, dynamic>);
  }

  static Future<void> markMessagesRead(int concernId, int lastMessageId) async {
    await _json('POST', 'concerns/$concernId/messages/read',
        body: {'last_message_id': lastMessageId});
  }

  /// Complaints with unread replies from the other side.
  static Future<List<ReplyNotification>> replyNotifications() async {
    final body = await _json('GET', 'notifications');
    return (body['notifications'] as List)
        .map((n) => ReplyNotification.fromJson(n as Map<String, dynamic>))
        .toList();
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

    if (response.statusCode == 403 && body['verificationRequired'] == true) {
      throw EmailNotVerifiedException(
          body['message'] as String? ?? 'Verify your email first.');
    }

    if (response.statusCode == 429) {
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      final minutes = seconds == null ? 0 : (seconds / 60).ceil();
      final when = seconds == null
          ? 'later'
          : seconds < 60
              ? 'in $seconds seconds'
              : 'in $minutes minute${minutes == 1 ? '' : 's'}';
      throw ApiException(429, "Too many attempts. Try again $when.");
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

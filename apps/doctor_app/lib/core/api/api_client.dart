import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:uuid/uuid.dart';

import '../config.dart';
import 'api_exception.dart';
import 'token_store.dart';

const _uuid = Uuid();

/// A fresh idempotency key. Create one per *user action* and reuse it when
/// retrying that same action (see [IdempotentAction]).
String newIdempotencyKey() => _uuid.v4();

/// Holds the idempotency key of one user action so a retry after a network
/// failure re-sends the same key, while a new action gets a new key.
class IdempotentAction {
  String? _key;

  String get key => _key ??= newIdempotencyKey();

  /// Call once the action reached a definitive server outcome.
  void complete() => _key = null;
}

/// One file part of a multipart request.
class MultipartFilePart {
  const MultipartFilePart({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final String field;
  final List<int> bytes;
  final String filename;
  final String contentType;
}

/// JSON client for the CareCompanion API (docs/api/API_CONTRACT.md).
///
/// - Adds `Authorization: Bearer`, `Accept-Language` and a fresh
///   `X-Correlation-Id` per logical request (kept across the refresh retry).
/// - Sends `Idempotency-Key` when given.
/// - On 401 it rotates the session once via `POST /auth/refresh` (single
///   flight: concurrent 401s share one refresh) and replays the request.
/// - `403 MFA_REQUIRED` (contract §22) fires [onMfaRequired] so the app can
///   route the doctor to the TOTP step, then throws.
/// - Maps every failure to [ApiException]; transport failures get statusCode 0.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? httpClient,
    this.languageCode = 'en',
    this.onSessionExpired,
    this.onMfaRequired,
  }) : _http = httpClient ?? http.Client();

  /// Mutable: the runtime "Server address" setting re-points the client.
  String baseUrl;
  final TokenStore tokens;
  final http.Client _http;
  String languageCode;
  void Function()? onSessionExpired;
  void Function()? onMfaRequired;

  Future<bool>? _refreshing;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _json('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body, String? idempotencyKey, bool auth = true}) =>
      _json('POST', path, body: body, idempotencyKey: idempotencyKey, auth: auth);

  Future<dynamic> put(String path, {Object? body}) => _json('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) => _json('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) => _json('DELETE', path, body: body);

  /// `multipart/form-data` POST (photo upload, scribe audio). The request is
  /// rebuilt for the refresh-and-retry attempt.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    required List<MultipartFilePart> files,
    String? idempotencyKey,
  }) async {
    final res = await _send(
      () {
        final m = http.MultipartRequest('POST', uri(path))
          ..fields.addAll(fields)
          ..files.addAll(
            files.map(
              (f) => http.MultipartFile.fromBytes(
                f.field,
                f.bytes,
                filename: f.filename,
                contentType: MediaType.parse(f.contentType),
              ),
            ),
          );
        return m;
      },
      idempotencyKey: idempotencyKey,
      timeout: AppConfig.uploadTimeout,
    );
    return _decodeJson(res);
  }

  /// Raw bytes (PDFs, original record files).
  Future<List<int>> getBytes(String path) async {
    final res = await _send(() => http.Request('GET', uri(path)), accept: '*/*');
    return res.bodyBytes;
  }

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final s = '$v';
      if (s.isEmpty) return;
      q[k] = s;
    });
    final u = Uri.parse('$base$path');
    return q.isEmpty ? u : u.replace(queryParameters: q);
  }

  Future<dynamic> _json(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) async {
    final res = await _send(
      () {
        final r = http.Request(method, uri(path, query));
        if (body != null) {
          r.headers['Content-Type'] = 'application/json';
          r.body = jsonEncode(body);
        }
        return r;
      },
      idempotencyKey: idempotencyKey,
      auth: auth,
    );
    return _decodeJson(res);
  }

  dynamic _decodeJson(http.Response res) {
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<http.Response> _send(
    http.BaseRequest Function() build, {
    String? idempotencyKey,
    bool auth = true,
    String accept = 'application/json',
    Duration timeout = AppConfig.requestTimeout,
  }) async {
    final correlationId = _uuid.v4();
    var res = await _once(build, correlationId, idempotencyKey, auth, accept, timeout);
    if (res.statusCode == 401 && auth && tokens.hasSession) {
      if (await _refreshSingleFlight()) {
        res = await _once(build, correlationId, idempotencyKey, auth, accept, timeout);
      }
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;

    final error = parseError(res);
    if (error.isMfaRequired) {
      onMfaRequired?.call();
    } else if (error.statusCode == 401 && auth) {
      await tokens.clear();
      onSessionExpired?.call();
    }
    throw error;
  }

  Future<http.Response> _once(
    http.BaseRequest Function() build,
    String correlationId,
    String? idempotencyKey,
    bool auth,
    String accept,
    Duration timeout,
  ) async {
    final req = build();
    req.headers.addAll({
      'Accept': accept,
      'Accept-Language': languageCode,
      'X-Correlation-Id': correlationId,
      'Idempotency-Key': ?idempotencyKey,
      if (auth && tokens.accessToken != null) 'Authorization': 'Bearer ${tokens.accessToken}',
    });
    try {
      final streamed = await _http.send(req).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException.network('Request timed out');
    } catch (e) {
      throw ApiException.network(e.toString());
    }
  }

  static ApiException parseError(http.Response response) {
    var code = _codeForStatus(response.statusCode);
    var message = response.reasonPhrase ?? 'Request failed';
    var details = const <String, dynamic>{};
    String? correlationId = response.headers['x-correlation-id'];
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        code = (err['code'] as String?) ?? code;
        message = (err['message'] as String?) ?? message;
        if (err['details'] is Map) details = Map<String, dynamic>.from(err['details'] as Map);
        correlationId = (err['correlationId'] as String?) ?? correlationId;
      }
    } catch (_) {}
    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      details: details,
      correlationId: correlationId,
    );
  }

  static String _codeForStatus(int status) => switch (status) {
    400 => 'VALIDATION_ERROR',
    401 => 'UNAUTHENTICATED',
    403 => 'FORBIDDEN',
    404 => 'NOT_FOUND',
    409 => 'CONFLICT',
    429 => 'RATE_LIMITED',
    503 => 'DEPENDENCY_UNAVAILABLE',
    _ => status >= 500 ? 'INTERNAL' : 'HTTP_$status',
  };

  Future<bool> _refreshSingleFlight() {
    final inflight = _refreshing;
    if (inflight != null) return inflight;
    final f = _refresh().whenComplete(() => _refreshing = null);
    _refreshing = f;
    return f;
  }

  /// Rotates tokens. A definitive refusal clears the session; a network
  /// failure keeps it (the next request can try again).
  Future<bool> _refresh() async {
    final refresh = tokens.refreshToken;
    if (refresh == null) return false;
    http.Response res;
    try {
      final req = http.Request('POST', uri('/auth/refresh'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Correlation-Id': _uuid.v4(),
        })
        ..body = jsonEncode({'refreshToken': refresh});
      final streamed = await _http.send(req).timeout(AppConfig.requestTimeout);
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      return false;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is Map && body['accessToken'] is String && body['refreshToken'] is String) {
          await tokens.save(body['accessToken'] as String, body['refreshToken'] as String);
          return true;
        }
      } catch (_) {}
      return false;
    }
    if (res.statusCode < 500) {
      await tokens.clear();
    }
    return false;
  }
}

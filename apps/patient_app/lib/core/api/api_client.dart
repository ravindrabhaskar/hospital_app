import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import 'api_exception.dart';
import 'token_store.dart';

const _uuid = Uuid();

/// Generates a fresh idempotency key. Create one per *user action* and reuse
/// it when retrying that same action (see [IdempotentAction]).
String newIdempotencyKey() => _uuid.v4();

/// Holds the idempotency key of one user action so that a retry after a
/// network failure re-sends the same key, while a new action gets a new key.
class IdempotentAction {
  String? _key;

  /// The key for the current attempt (created lazily, reused on retry).
  String get key => _key ??= newIdempotencyKey();

  /// Call once the action reached a definitive server outcome (success or a
  /// business error), so the next tap is treated as a new action.
  void complete() => _key = null;
}

class ApiResponse {
  ApiResponse(this.statusCode, this.body, this.headers);
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;
}

class UploadFile {
  UploadFile({
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

typedef RequestFactory = Future<http.BaseRequest> Function();

/// HTTP client for the CareCompanion API.
///
/// * Adds `Authorization: Bearer`, `X-Correlation-Id`, `Accept-Language`.
/// * On a 401 it refreshes the session once (single-flight, rotating the
///   refresh token) and replays the request; if the refresh fails the
///   session is cleared and [onSessionExpired] fires.
/// * Maps non-2xx responses to [ApiException] from the error envelope and
///   transport failures to [ApiException.network].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required http.Client httpClient,
    required TokenStore tokenStore,
    this.languageCode,
    this.onSessionExpired,
    this.onSessionRefreshed,
  })  : _http = httpClient,
        _tokens = tokenStore;

  /// Mutable: the runtime "Server address" setting re-points the client.
  String baseUrl;
  final http.Client _http;
  final TokenStore _tokens;
  String Function()? languageCode;
  void Function()? onSessionExpired;

  /// Called with the full AuthSession JSON after a successful refresh.
  void Function(Map<String, dynamic> session)? onSessionRefreshed;

  Future<bool>? _refreshing;

  TokenStore get tokenStore => _tokens;

  Uri uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final s = v is bool ? v.toString() : '$v';
      if (s.isEmpty) return;
      q[k] = s;
    });
    return Uri.parse('$baseUrl$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) async =>
      (await send('GET', path, query: query, auth: auth)).body;

  Future<dynamic> post(String path,
          {Object? body, String? idempotencyKey, bool auth = true}) async =>
      (await send('POST', path,
              body: body, idempotencyKey: idempotencyKey, auth: auth))
          .body;

  Future<dynamic> patch(String path, {Object? body}) async =>
      (await send('PATCH', path, body: body)).body;

  Future<dynamic> put(String path, {Object? body}) async =>
      (await send('PUT', path, body: body)).body;

  Future<dynamic> delete(String path, {Object? body}) async =>
      (await send('DELETE', path, body: body)).body;

  Future<ApiResponse> send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) {
    final correlationId = _uuid.v4();
    return _execute(
      () async {
        final req = http.Request(method, uri(path, query));
        req.headers.addAll(await _headers(auth, correlationId, idempotencyKey));
        if (body != null) {
          req.headers['Content-Type'] = 'application/json';
          req.body = jsonEncode(body);
        }
        return req;
      },
      auth: auth,
    );
  }

  Future<dynamic> multipart(
    String path, {
    required Map<String, String> fields,
    required List<UploadFile> files,
  }) async {
    final correlationId = _uuid.v4();
    final res = await _execute(() async {
      final req = http.MultipartRequest('POST', uri(path));
      req.headers.addAll(await _headers(true, correlationId, null));
      req.fields.addAll(fields);
      for (final f in files) {
        req.files.add(http.MultipartFile.fromBytes(
          f.field,
          f.bytes,
          filename: f.filename,
          contentType: MediaType.parse(f.contentType),
        ));
      }
      return req;
    }, auth: true);
    return res.body;
  }

  /// Downloads raw bytes (e.g. `GET /records/:id/file`).
  Future<List<int>> getBytes(String path) async {
    final correlationId = _uuid.v4();
    final res = await _execute(() async {
      final req = http.Request('GET', uri(path));
      req.headers.addAll(await _headers(true, correlationId, null));
      return req;
    }, auth: true, raw: true);
    return res.body as List<int>;
  }

  Future<Map<String, String>> _headers(
      bool auth, String correlationId, String? idempotencyKey) async {
    final h = <String, String>{
      'Accept': 'application/json',
      'X-Correlation-Id': correlationId,
    };
    final lang = languageCode?.call();
    if (lang != null) h['Accept-Language'] = lang;
    if (idempotencyKey != null) h['Idempotency-Key'] = idempotencyKey;
    if (auth) {
      final t = await _tokens.read();
      if (t != null) h['Authorization'] = 'Bearer ${t.accessToken}';
    }
    return h;
  }

  Future<ApiResponse> _execute(RequestFactory build,
      {required bool auth, bool raw = false}) async {
    var res = await _once(build);
    if (res.statusCode == 401 && auth) {
      final refreshed = await _refreshSingleFlight();
      if (refreshed) {
        res = await _once(build);
      }
      if (res.statusCode == 401) {
        await _tokens.clear();
        onSessionExpired?.call();
      }
    }
    return _decode(res, raw: raw);
  }

  Future<http.Response> _once(RequestFactory build) async {
    try {
      final req = await build();
      final streamed =
          await _http.send(req).timeout(AppConfig.requestTimeout);
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(
          code: ApiException.network, message: 'The request timed out');
    } on http.ClientException catch (e) {
      throw ApiException(code: ApiException.network, message: e.message);
    } on ApiException {
      rethrow;
    } catch (e) {
      // SocketException / HandshakeException etc. on IO platforms.
      throw ApiException(code: ApiException.network, message: e.toString());
    }
  }

  Future<bool> _refreshSingleFlight() {
    final inflight = _refreshing;
    if (inflight != null) return inflight;
    final f = _refresh().whenComplete(() => _refreshing = null);
    _refreshing = f;
    return f;
  }

  Future<bool> _refresh() async {
    final current = await _tokens.read();
    if (current == null) return false;
    try {
      final req = http.Request('POST', uri('/auth/refresh'))
        ..headers.addAll({
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Correlation-Id': _uuid.v4(),
        })
        ..body = jsonEncode({'refreshToken': current.refreshToken});
      final streamed = await _http.send(req).timeout(AppConfig.requestTimeout);
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return false;
      final access = body['accessToken'] as String?;
      final refresh = body['refreshToken'] as String?;
      if (access == null || refresh == null) return false;
      await _tokens.write(
          StoredTokens(accessToken: access, refreshToken: refresh));
      onSessionRefreshed?.call(Map<String, dynamic>.from(body));
      return true;
    } catch (_) {
      return false;
    }
  }

  ApiResponse _decode(http.Response res, {bool raw = false}) {
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok && raw) {
      return ApiResponse(res.statusCode, res.bodyBytes, res.headers);
    }
    dynamic body;
    if (res.bodyBytes.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        if (ok) {
          throw ApiException(
              code: ApiException.badResponse,
              message: 'Unexpected response from server',
              statusCode: res.statusCode);
        }
      }
    }
    if (!ok) throw ApiException.fromEnvelope(res.statusCode, body);
    return ApiResponse(res.statusCode, body, res.headers);
  }
}

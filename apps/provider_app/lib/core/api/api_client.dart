import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;

import '../config.dart';
import 'api_exception.dart';
import 'token_store.dart';

/// Thin JSON client for the CareCompanion API (see docs/api/API_CONTRACT.md).
///
/// - Adds `Authorization: Bearer` and `Accept-Language`.
/// - On 401 it rotates the session once via `POST /auth/refresh` and retries.
/// - Maps every failure to [ApiException]; transport failures get statusCode 0.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokens,
    http.Client? httpClient,
    this.languageCode = 'en',
    this.onSessionExpired,
  }) : _http = httpClient ?? http.Client();

  /// Mutable: the runtime "Server address" setting re-points the client.
  String baseUrl;
  final TokenStore tokens;
  final http.Client _http;
  String languageCode;
  void Function()? onSessionExpired;

  Future<void>? _refreshing;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

  Future<dynamic> post(
    String path, {
    Object? body,
    String? idempotencyKey,
    bool auth = true,
  }) =>
      _request('POST', path, body: body, idempotencyKey: idempotencyKey, auth: auth);

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path, {Object? body}) =>
      _request('DELETE', path, body: body);

  /// `multipart/form-data` POST (record uploads, contract §9). The request is
  /// rebuilt for the refresh-and-retry attempt, so the same file and
  /// Idempotency-Key are sent again.
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required MultipartFilePart file,
    String? idempotencyKey,
    UploadProgress? onProgress,
  }) =>
      _request('POST', path,
          multipart: (fields: fields, file: file), idempotencyKey: idempotencyKey, onProgress: onProgress);

  Uri _uri(String path, Map<String, String>? query) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$base$path');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    ({Map<String, String> fields, MultipartFilePart file})? multipart,
    String? idempotencyKey,
    bool auth = true,
    bool allowRefresh = true,
    UploadProgress? onProgress,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Accept-Language': languageCode,
      if (body != null) 'Content-Type': 'application/json',
      'Idempotency-Key': ?idempotencyKey,
      if (auth && tokens.accessToken != null) 'Authorization': 'Bearer ${tokens.accessToken}',
    };

    http.Response response;
    try {
      final http.BaseRequest request;
      if (multipart != null) {
        final m = http.MultipartRequest(method, _uri(path, query))
          ..headers.addAll(headers)
          ..fields.addAll(multipart.fields)
          ..files.add(http.MultipartFile.fromBytes(
            multipart.file.field,
            multipart.file.bytes,
            filename: multipart.file.filename,
            contentType: MediaType.parse(multipart.file.contentType),
          ));
        request = onProgress == null ? m : _withProgress(m, onProgress);
      } else {
        final r = http.Request(method, _uri(path, query))..headers.addAll(headers);
        if (body != null) r.body = jsonEncode(body);
        request = r;
      }
      final streamed = await _http.send(request).timeout(AppConfig.requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(AppConfig.requestTimeout);
    } on TimeoutException {
      throw const ApiException.network('Request timed out');
    } catch (e) {
      throw ApiException.network(e.toString());
    }

    if (response.statusCode == 401 && auth && allowRefresh && tokens.hasSession) {
      final refreshed = await _refreshSession();
      if (refreshed) {
        return _request(method, path,
            query: query,
            body: body,
            multipart: multipart,
            idempotencyKey: idempotencyKey,
            auth: auth,
            allowRefresh: false,
            onProgress: onProgress);
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        return null;
      }
    }

    final error = _parseError(response, authenticated: auth);
    if (error.statusCode == 401 && auth) {
      onSessionExpired?.call();
    }
    throw error;
  }

  /// Streams the multipart body through a byte counter so the UI can show
  /// upload progress (0.0 to 1.0). On web the browser buffers the body, so
  /// progress jumps to 1.0 once the bytes are handed over.
  http.BaseRequest _withProgress(http.MultipartRequest m, UploadProgress onProgress) {
    final total = m.contentLength;
    final body = m.finalize();
    final r = http.StreamedRequest(m.method, m.url)
      ..headers.addAll(m.headers)
      ..contentLength = total;
    var sent = 0;
    onProgress(0);
    body.listen(
      (chunk) {
        sent += chunk.length;
        r.sink.add(chunk);
        onProgress(total <= 0 ? 1 : (sent / total).clamp(0, 1).toDouble());
      },
      onError: r.sink.addError,
      onDone: r.sink.close,
      cancelOnError: true,
    );
    return r;
  }

  ApiException _parseError(http.Response response, {bool authenticated = true}) {
    String code = 'HTTP_${response.statusCode}';
    var details = const <String, dynamic>{};
    String message = response.reasonPhrase ?? 'Request failed';
    String? correlationId = response.headers['x-correlation-id'];
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is Map) {
        final err = decoded['error'] as Map;
        code = (err['code'] as String?) ?? code;
        message = (err['message'] as String?) ?? message;
        correlationId = (err['correlationId'] as String?) ?? correlationId;
        if (err['details'] is Map) details = Map<String, dynamic>.from(err['details'] as Map);
      }
    } catch (_) {}
    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
      correlationId: correlationId,
      details: details,
      authenticated: authenticated,
    );
  }

  /// Rotates tokens; concurrent callers share one refresh.
  Future<bool> _refreshSession() async {
    final inFlight = _refreshing;
    if (inFlight != null) {
      await inFlight;
      return tokens.accessToken != null;
    }
    final completer = Completer<void>();
    _refreshing = completer.future;
    try {
      final result = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': tokens.refreshToken},
        auth: false,
        allowRefresh: false,
      );
      if (result is Map && result['accessToken'] is String && result['refreshToken'] is String) {
        await tokens.save(result['accessToken'] as String, result['refreshToken'] as String);
        return true;
      }
      return false;
    } on ApiException catch (e) {
      if (!e.isNetwork) {
        await tokens.clear();
        onSessionExpired?.call();
      }
      return false;
    } finally {
      completer.complete();
      _refreshing = null;
    }
  }
}

/// Upload progress callback (fraction sent, 0.0 to 1.0).
typedef UploadProgress = void Function(double fraction);

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

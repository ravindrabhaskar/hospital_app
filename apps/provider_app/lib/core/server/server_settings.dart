import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime "Server address" setting (demo / QA builds only).
///
/// The effective API base URL is the persisted override when one is set and
/// overrides are allowed, otherwise the compiled `API_BASE_URL`. Overrides are
/// allowed only in non-production builds: builds whose compiled base URL is
/// not https, or that were built with `--dart-define=ALLOW_SERVER_OVERRIDE=true`.
/// An https production build can neither set nor use an override, so a store
/// build can never be redirected to another server.
///
/// The preference key is global (never namespaced), so in the all-in-one demo
/// build the patient, provider and doctor apps share one server setting.
class ServerSettings extends ChangeNotifier {
  ServerSettings({
    required this.defaultUrl,
    required this.overrideAllowed,
    SharedPreferences? prefs,
    String? override,
  })  : _store = prefs,
        _override = overrideAllowed ? override : null;

  /// Shared-preferences key of the override (global, unprefixed).
  static const prefsKey = 'server.baseUrl.override';

  /// `--dart-define=ALLOW_SERVER_OVERRIDE=true` (demo builds).
  static const bool allowFlag = bool.fromEnvironment('ALLOW_SERVER_OVERRIDE');

  /// The rule: override allowed unless the compiled URL is https, or always
  /// when the build explicitly opts in with [allowFlag].
  static bool isOverrideAllowed({required String compiledBaseUrl, bool allowFlag = false}) =>
      allowFlag || !compiledBaseUrl.trim().toLowerCase().startsWith('https://');

  /// Reads the persisted override from [prefs] (or the shared instance). In a
  /// build where overrides are not allowed any stored value is ignored and
  /// removed.
  static Future<ServerSettings> load({
    required String defaultUrl,
    required bool overrideAllowed,
    SharedPreferences? prefs,
  }) async {
    SharedPreferences? p = prefs;
    try {
      p ??= await SharedPreferences.getInstance();
    } catch (_) {}
    String? stored;
    try {
      stored = p?.getString(prefsKey);
      if (!overrideAllowed && stored != null) {
        await p?.remove(prefsKey);
        stored = null;
      }
    } catch (_) {}
    final normalized = stored == null ? null : normalizeServerUrl(stored);
    return ServerSettings(
      defaultUrl: defaultUrl,
      overrideAllowed: overrideAllowed,
      prefs: p,
      override: normalized,
    );
  }

  /// The compiled (or platform default) base URL.
  final String defaultUrl;

  /// Whether this build may use a runtime override at all.
  final bool overrideAllowed;

  SharedPreferences? _store;
  String? _override;

  /// The active override, or null (always null when not allowed).
  String? get override => overrideAllowed ? _override : null;

  /// The base URL the API client must use.
  String get effectiveUrl => override ?? defaultUrl;

  bool get isOverridden => override != null;

  /// `host[:port]` of [effectiveUrl], for the login-screen chip.
  String get host => hostOf(effectiveUrl);

  Future<SharedPreferences> _p() async => _store ??= await SharedPreferences.getInstance();

  /// Persists [input] (normalized) and applies it immediately. Throws
  /// [StateError] when overrides are not allowed and [FormatException] when
  /// the address is not valid.
  Future<String> setOverride(String input) async {
    if (!overrideAllowed) {
      throw StateError('Server override is not available in this build');
    }
    final url = normalizeServerUrl(input);
    if (url == null) throw FormatException('Invalid server address', input);
    await (await _p()).setString(prefsKey, url);
    if (url != _override) {
      _override = url;
      notifyListeners();
    }
    return url;
  }

  /// Removes the override: back to the compiled URL.
  Future<void> reset() async {
    try {
      await (await _p()).remove(prefsKey);
    } catch (_) {}
    if (_override != null) {
      _override = null;
      notifyListeners();
    }
  }
}

final _scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');
final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
final _hostLabel = RegExp(r'^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$');
final _numeric = RegExp(r'^\d+$');

/// `/`-separated plain segments only (no empty `//`, no `:`, no `%`).
final _plainPath = RegExp(r'^(/[A-Za-z0-9._~-]+)*/*$');

/// A host is a valid IPv4 address, `localhost`, an IPv6 literal, or a DNS
/// name whose labels are letters/digits/hyphens. Something that starts like
/// an IP but isn't one (`10.10.17.http`) is rejected.
bool _validHost(String host) {
  final h = host.toLowerCase();
  if (h.contains(':')) return true; // IPv6 literal, already parsed by Uri.
  if (_ipv4.hasMatch(h)) return h.split('.').every((p) => int.parse(p) <= 255);
  if (RegExp(r'^[\d.]+$').hasMatch(h)) return false;
  final labels = h.split('.');
  if (!labels.every(_hostLabel.hasMatch)) return false;
  if (labels.length > 1 && labels.sublist(0, labels.length - 1).every(_numeric.hasMatch)) return false;
  return true;
}

/// Default port of the local API server (`npm run dev`).
const defaultServerPort = 4000;

/// Normalizes a user-entered server address to a base URL ending in `/api/v1`,
/// or returns null when it is not usable.
///
/// * `10.10.17.134` → `http://10.10.17.134:4000/api/v1` (bare IP / localhost:
///   http and the dev port 4000 unless a port is given)
/// * `http://10.10.17.134:4000` → `http://10.10.17.134:4000/api/v1`
/// * `https://xyz.trycloudflare.com/` → `https://xyz.trycloudflare.com/api/v1`
/// * `xyz.trycloudflare.com` (bare domain name) → `https://xyz.trycloudflare.com/api/v1`
///
/// Anything else (two schemes, odd host, query, `//` or `:` in the path) is
/// null: it must be `http(s)://host[:port][/path]`. Test and Save both use this.
String? normalizeServerUrl(String input) {
  var s = input.trim();
  if (s.isEmpty || s.contains(RegExp(r'\s'))) return null;
  final hasScheme = _scheme.hasMatch(s);
  var addDevPort = false;
  if (!hasScheme) {
    final hostPart = s.split(RegExp(r'[/:?#]')).first.toLowerCase();
    final local = _ipv4.hasMatch(hostPart) || hostPart == 'localhost';
    addDevPort = local;
    s = '${local ? 'http' : 'https'}://$s';
  }
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } catch (_) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  // Exactly one scheme: pasted-together addresses ("http://a.http//b:1/...")
  // are rejected instead of being saved garbled.
  if ('://'.allMatches(s).length != 1) return null;
  final host = uri.host;
  if (host.isEmpty || !_validHost(host)) return null;
  if (uri.userInfo.isNotEmpty) return null;
  if (uri.hasQuery || uri.hasFragment) return null;
  if (!_plainPath.hasMatch(uri.path)) return null;
  final port = uri.hasPort ? uri.port : (addDevPort ? defaultServerPort : null);
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (!path.endsWith('/api/v1')) path = '$path/api/v1';
  return Uri(scheme: scheme, host: host, port: port, path: path).toString();
}

/// `host[:port]` of [url] (or [url] itself when it can't be parsed).
String hostOf(String url) {
  try {
    final u = Uri.parse(url);
    if (u.host.isEmpty) return url;
    return u.hasPort ? '${u.host}:${u.port}' : u.host;
  } catch (_) {
    return url;
  }
}

/// Outcome of [checkServerHealth].
class ServerCheckResult {
  const ServerCheckResult._({required this.ok, this.version, this.statusCode, this.unreachable = false});

  const ServerCheckResult.ok(String? version) : this._(ok: true, version: version);
  const ServerCheckResult.unreachable() : this._(ok: false, unreachable: true);
  const ServerCheckResult.notCareCompanion(int statusCode) : this._(ok: false, statusCode: statusCode);

  final bool ok;
  final String? version;
  final int? statusCode;

  /// No HTTP response at all (DNS, refused, timeout, cleartext blocked...).
  final bool unreachable;
}

/// `GET <baseUrl>/health` → `{ "status": "ok", "version": "..." }`.
Future<ServerCheckResult> checkServerHealth(
  http.Client client,
  String baseUrl, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final http.Response res;
  try {
    res = await client
        .get(Uri.parse('$baseUrl/health'), headers: const {'Accept': 'application/json'})
        .timeout(timeout);
  } catch (_) {
    // SocketException, TimeoutException, ClientException, HandshakeException...
    return const ServerCheckResult.unreachable();
  }
  if (res.statusCode == 200) {
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['status'] == 'ok') {
        final v = body['version'];
        return ServerCheckResult.ok(v == null ? null : '$v');
      }
    } catch (_) {}
  }
  return ServerCheckResult.notCareCompanion(res.statusCode);
}

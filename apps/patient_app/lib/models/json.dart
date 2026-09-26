// Small, forgiving JSON readers used by the hand-written `fromJson`s.

typedef Json = Map<String, dynamic>;

Json asJson(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String str(Json j, String k, [String fallback = '']) {
  final v = j[k];
  if (v == null) return fallback;
  return v is String ? v : '$v';
}

String? strOrNull(Json j, String k) {
  final v = j[k];
  if (v == null) return null;
  return v is String ? v : '$v';
}

int intOf(Json j, String k, [int fallback = 0]) => intOrNull(j, k) ?? fallback;

int? intOrNull(Json j, String k) {
  final v = j[k];
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

double dbl(Json j, String k, [double fallback = 0]) =>
    dblOrNull(j, k) ?? fallback;

double? dblOrNull(Json j, String k) {
  final v = j[k];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool boolOf(Json j, String k, [bool fallback = false]) {
  final v = j[k];
  return v is bool ? v : fallback;
}

DateTime? dateOrNull(Json j, String k) {
  final v = j[k];
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toLocal();
}

DateTime dateOf(Json j, String k) =>
    dateOrNull(j, k) ?? DateTime.fromMillisecondsSinceEpoch(0);

List<String> strList(Json j, String k) {
  final v = j[k];
  if (v is! List) return const [];
  return v.where((e) => e != null).map((e) => '$e').toList();
}

List<T> listOf<T>(Object? v, T Function(Json) f) {
  if (v is! List) return <T>[];
  return v.whereType<Map>().map((e) => f(Map<String, dynamic>.from(e))).toList();
}

/// The standard list envelope `{ items: [...], nextCursor }`.
class Page<T> {
  Page(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;

  factory Page.fromJson(Object? body, T Function(Json) f) {
    final j = asJson(body);
    return Page(listOf(j['items'], f), strOrNull(j, 'nextCursor'));
  }
}

/// Formats a date as the contract's `YYYY-MM-DD`.
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Defensive JSON helpers so a slightly different payload never crashes the UI.
typedef Json = Map<String, dynamic>;

Json asJson(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return <String, dynamic>{};
}

String? str(Object? value) => value?.toString();

String strOr(Object? value, [String fallback = '']) => value == null ? fallback : value.toString();

num? numOrNull(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

int? intOrNull(Object? value) => numOrNull(value)?.toInt();

bool boolOr(Object? value, [bool fallback = false]) => value is bool ? value : fallback;

DateTime? dateOrNull(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

List<String> stringList(Object? value) {
  if (value is! List) return const [];
  return value.where((e) => e != null).map((e) => e.toString()).toList();
}

List<Json> jsonList(Object? value) {
  if (value is! List) return const [];
  return value.map(asJson).toList();
}

/// Helper per leggere campi dai JSON di contenuto Start.
library;

String scText(Map<String, dynamic>? json, String key, {String fallback = ''}) {
  if (json == null) return fallback;
  final v = json[key];
  if (v == null) return fallback;
  final s = '$v';
  return s.isEmpty ? fallback : s;
}

List<String> scStringList(
  Map<String, dynamic>? json,
  String key, {
  List<String> fallback = const [],
}) {
  if (json == null) return fallback;
  final raw = json[key];
  if (raw is! List || raw.isEmpty) return fallback;
  return [for (final v in raw) '$v'];
}

List<Map<String, String>> scFareRows(
  Map<String, dynamic>? json,
  String key,
) {
  if (json == null) return const [];
  final raw = json[key];
  if (raw is! List) return const [];
  return [
    for (final row in raw)
      if (row is Map)
        {
          'ticket': '${row['ticket'] ?? row['titolo'] ?? ''}',
          'price': '${row['price'] ?? row['prezzo'] ?? ''}',
          'validity': '${row['validity'] ?? row['validita'] ?? ''}',
        },
  ];
}

List<Map<String, String?>> scPrezzoRows(
  Map<String, dynamic>? json,
  String key,
) {
  if (json == null) return const [];
  final raw = json[key];
  if (raw is! List) return const [];
  return [
    for (final row in raw)
      if (row is Map)
        {
          'titolo': '${row['titolo'] ?? ''}',
          'prezzo': '${row['prezzo'] ?? ''}',
          'nota': row['nota'] == null ? null : '${row['nota']}',
        },
  ];
}

Map<String, dynamic>? scMap(Map<String, dynamic>? json, String key) {
  if (json == null) return null;
  final v = json[key];
  return v is Map<String, dynamic> ? v : null;
}

List<Map<String, dynamic>> scMapList(
  Map<String, dynamic>? json,
  String key,
) {
  if (json == null) return const [];
  final raw = json[key];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map<String, dynamic>) item,
  ];
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Nome fermata così come mostrato in UI (maiuscolo). Gli indirizzi non passano da qui.
String transitStopNameForDisplay(String raw) => raw.toUpperCase();

/// Fermata TPL da asset JSON (`fermate_fc` / `fermate_ra` / `fermate_rn`).
class TransitStopPin {
  const TransitStopPin({
    String? stopId,
    String? comune,
    String? basin,
    String? disabili,
    String? zona,
    required this.stopName,
    required this.point,
  }) : _stopId = stopId,
       _comune = comune,
       _basin = basin,
       _disabili = disabili,
       _zona = zona;

  /// Valore grezzo dal JSON; dopo hot reload può essere null su istanze obsolete.
  final String? _stopId;
  final String? _comune;
  final String? _basin;
  final String? _disabili;
  final String? _zona;

  /// Codice fermata (`id` nel JSON); mai null (evita crash post–hot reload).
  String get stopId {
    final s = _stopId;
    if (s == null || s.isEmpty) return '';
    return s.trim();
  }

  /// Località pronta da mostrare in card (es. "Cesenatico (FC)").
  String get comune {
    final s = _comune;
    if (s == null || s.isEmpty) return '';
    return s.trim();
  }

  /// Bacino sorgente (`fc`, `ra`, `rn`) con fallback sicuro post hot-reload.
  String get basin {
    final s = _basin;
    if (s == null || s.isEmpty) return 'all';
    return s.trim().toLowerCase();
  }

  /// Stato accessibilità dal JSON (`yes` / `no`), altrimenti stringa vuota.
  String get disabili {
    final s = _disabili;
    if (s == null || s.isEmpty) return '';
    final v = s.trim().toLowerCase();
    return (v == 'yes' || v == 'no') ? v : '';
  }

  /// Zona tariffaria dal JSON (es. "RIMINI (900)"), stringa vuota se assente.
  String get zona {
    final s = _zona;
    if (s == null || s.isEmpty) return '';
    return s.trim();
  }

  final String stopName;
  final LatLng point;
}

/// Fermata traghetto (dataset dedicato Ravenna).
class FerryStopPin {
  const FerryStopPin({
    required this.stopName,
    required this.comune,
    required this.provincia,
    required this.point,
  });

  final String stopName;
  final String comune;
  final String provincia;
  final LatLng point;

  String get id =>
      '${stopName.trim().toLowerCase()}|${comune.trim().toLowerCase()}|${provincia.trim().toUpperCase()}';
}

/// Asset da cui leggere fermate (stesso elenco di `pubspec.yaml`).
const List<String> kTransitLineStopAssetPaths = <String>[
  'assets/data/fermate_fc.json',
  'assets/data/fermate_ra.json',
  'assets/data/fermate_rn.json',
];

String _basinFromAssetPath(String path) {
  final p = path.toLowerCase();
  if (p.contains('fermate_fc')) return 'fc';
  if (p.contains('fermate_ra')) return 'ra';
  if (p.contains('fermate_rn')) return 'rn';
  return 'all';
}

String _dedupeKey(LatLng p) =>
    '${p.latitude.toStringAsFixed(6)}_${p.longitude.toStringAsFixed(6)}';

/// Per la ricerca: ignora `/` negli id (es. `3011/0` equivale a `30110`).
String _normalizeStopIdForSearch(String s) =>
    s.toLowerCase().replaceAll('/', '');

/// Query fermata con filtri opzionali «Metromare» (solo ID `TRC…`) e «traghetto».
class TransitStopSearchParsed {
  const TransitStopSearchParsed({
    this.matchTokens = const [],
    this.metromareOnly = false,
    this.traghettoOnly = false,
  });

  /// Token nome / ID (parola chiave di servizio escluse).
  final List<String> matchTokens;
  final bool metromareOnly;
  final bool traghettoOnly;
}

bool _isTrcStopId(String stopId) =>
    stopId.trim().toUpperCase().startsWith('TRC');

/// Analizza la barra ricerca: rimuove «metromare» / «traghetto» e restituisce i token utili.
TransitStopSearchParsed parseTransitStopSearchQuery(String rawQuery) {
  var q = rawQuery.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (q.isEmpty) {
    return const TransitStopSearchParsed();
  }
  if (q.startsWith('fermata ')) {
    q = q.substring('fermata '.length).trim();
  }
  q = q.replaceFirst(RegExp(r'^(stop|id)\s*[:#-]?\s*'), '').trim();

  var metromareOnly = false;
  var traghettoOnly = false;

  if (q.replaceAll(' ', '').contains('metromare')) {
    metromareOnly = true;
    q = q.replaceAll('metromare', ' ').replaceAll(RegExp(r'metro\s+mare'), ' ');
  }
  if (q.replaceAll(' ', '').contains('traghetto')) {
    traghettoOnly = true;
    q = q.replaceAll('traghetto', ' ');
  }

  var parts =
      q
          .split(RegExp(r'\s+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(growable: false);

  final matchTokens = <String>[];
  for (var i = 0; i < parts.length; i++) {
    final t = parts[i];
    if (t == 'metromare') {
      metromareOnly = true;
      continue;
    }
    if (t == 'traghetto') {
      traghettoOnly = true;
      continue;
    }
    if (t == 'metro' && i + 1 < parts.length && parts[i + 1] == 'mare') {
      metromareOnly = true;
      i++;
      continue;
    }
    if (t.length >= 2) {
      matchTokens.add(t);
    }
  }

  final remaining = q.trim();
  if (matchTokens.isEmpty &&
      remaining.length >= 2 &&
      !metromareOnly &&
      !traghettoOnly) {
    matchTokens.add(remaining);
  }

  return TransitStopSearchParsed(
    matchTokens: matchTokens,
    metromareOnly: metromareOnly,
    traghettoOnly: traghettoOnly,
  );
}

/// Token di ricerca fermata (nome e/o ID, anche combinati: «Fiabilandia TRC026»).
List<String> transitStopSearchTokens(String rawQuery) =>
    parseTransitStopSearchQuery(rawQuery).matchTokens;

bool transitStopMatchesSearchTokens({
  required String nameLower,
  required String idNorm,
  required List<String> tokens,
}) {
  if (tokens.isEmpty) return false;
  for (final token in tokens) {
    final tId = _normalizeStopIdForSearch(token);
    final nameOk = nameLower.contains(token);
    final idOk = tId.isNotEmpty && idNorm.isNotEmpty && idNorm.contains(tId);
    if (!nameOk && !idOk) return false;
  }
  return true;
}

void _mergeStopsFromList(List<dynamic> stops, String basin, Map<String, TransitStopPin> byKey) {
  for (final s in stops) {
    if (s is! Map<String, dynamic>) continue;
    final name = s['name'];
    final lat = s['lat'];
    final lon = s['long'];
    if (name is! String || lat is! num || lon is! num) continue;
    final idRaw = s['id'];
    final comuneRaw = s['comune'];
    final disabiliRaw = s['disabili'];
    final zonaRaw = s['zona'];
    final String? stopId =
        idRaw is String
            ? (idRaw.trim().isEmpty ? null : idRaw.trim())
            : idRaw is num
            ? idRaw.toString()
            : null;
    final String? comune =
        comuneRaw is String
            ? (comuneRaw.trim().isEmpty ? null : comuneRaw.trim())
            : null;
    final String? disabili =
        disabiliRaw is String
            ? (disabiliRaw.trim().isEmpty ? null : disabiliRaw.trim())
            : null;
    final String? zona =
        zonaRaw is String ? (zonaRaw.trim().isEmpty ? null : zonaRaw.trim()) : null;
    final p = LatLng(lat.toDouble(), lon.toDouble());
    if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) continue;
    final k = _dedupeKey(p);
    final incoming = TransitStopPin(
      stopId: stopId,
      comune: comune,
      basin: basin,
      disabili: disabili,
      zona: zona,
      stopName: name,
      point: p,
    );
    final existing = byKey[k];
    if (existing == null) {
      byKey[k] = incoming;
      continue;
    }
    if (existing.comune.isEmpty && incoming.comune.isNotEmpty) {
      byKey[k] = incoming;
    }
  }
}

/// Carica le fermate da un solo bacino (`FC` / `RA` / `RN`), deduplicando per coordinate.
Future<List<TransitStopPin>> loadTransitStopsForBasin(String bacinoUpper) async {
  final code = bacinoUpper.trim().toUpperCase();
  final path =
      code == 'FC'
          ? 'assets/data/fermate_fc.json'
          : code == 'RA'
          ? 'assets/data/fermate_ra.json'
          : code == 'RN'
          ? 'assets/data/fermate_rn.json'
          : null;
  if (path == null) return const [];
  final basin = code.toLowerCase();
  String raw;
  try {
    raw = await rootBundle.loadString(path);
  } catch (_) {
    return const [];
  }
  Map<String, dynamic>? root;
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic>) root = d;
  } catch (_) {
    return const [];
  }
  final stops = root!['stops'];
  if (stops is! List) return const [];
  final byKey = <String, TransitStopPin>{};
  _mergeStopsFromList(stops, basin, byKey);
  return byKey.values.toList(growable: false);
}

List<TransitStopPin>? _cachedTransitStopsFromAssets;
Future<List<TransitStopPin>>? _loadingTransitStopsFromAssets;

/// Carica le fermate da `fermate_fc.json` (lista piatta) e deduplica per coordinate.
Future<List<TransitStopPin>> loadTransitStopsFromAssets() async {
  final cached = _cachedTransitStopsFromAssets;
  if (cached != null) return cached;
  return _loadingTransitStopsFromAssets ??= _loadTransitStopsFromAssetsInternal()
      .then((list) {
        _cachedTransitStopsFromAssets = list;
        return list;
      });
}

Future<List<TransitStopPin>> _loadTransitStopsFromAssetsInternal() async {
  final byKey = <String, TransitStopPin>{};
  for (final path in kTransitLineStopAssetPaths) {
    final basin = _basinFromAssetPath(path);
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      continue;
    }
    Map<String, dynamic>? root;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) root = d;
    } catch (_) {
      continue;
    }
    final stops = root!['stops'];
    if (stops is! List) continue;
    _mergeStopsFromList(stops, basin, byKey);
  }
  return byKey.values.toList(growable: false);
}

/// `stop_id` → nome fermata in maiuscolo (come in UI), da tutti i `fermate_*.json`.
Future<Map<String, String>> loadTransitStopIdToDisplayNameMap() async {
  final out = <String, String>{};
  for (final path in kTransitLineStopAssetPaths) {
    String raw;
    try {
      raw = await rootBundle.loadString(path);
    } catch (_) {
      continue;
    }
    Map<String, dynamic>? root;
    try {
      final d = jsonDecode(raw);
      if (d is Map<String, dynamic>) root = d;
    } catch (_) {
      continue;
    }
    final stops = root!['stops'];
    if (stops is! List) continue;
    for (final s in stops) {
      if (s is! Map<String, dynamic>) continue;
      final idRaw = s['id'];
      final nameRaw = s['name'];
      if (nameRaw is! String) continue;
      final name = nameRaw.trim();
      if (name.isEmpty) continue;
      final String id =
          idRaw is String
              ? idRaw.trim()
              : idRaw is num
              ? idRaw.toString().trim()
              : '';
      if (id.isEmpty) continue;
      out[id] = transitStopNameForDisplay(name);
    }
  }
  return out;
}

/// Carica fermate traghetto da asset dedicato.
Future<List<FerryStopPin>> loadFerryStopsFromAsset() async {
  const path = 'assets/data/traghetto_ra.json';
  String raw;
  try {
    raw = await rootBundle.loadString(path);
  } catch (_) {
    return const [];
  }
  Map<String, dynamic>? root;
  try {
    final d = jsonDecode(raw);
    if (d is Map<String, dynamic>) root = d;
  } catch (_) {
    return const [];
  }
  final stops = root!['stops'];
  if (stops is! List) return const [];
  final out = <FerryStopPin>[];
  for (final s in stops) {
    if (s is! Map<String, dynamic>) continue;
    final nameRaw = s['nome_fermata'];
    final comuneRaw = s['comune'];
    final provinciaRaw = s['provincia'];
    final latRaw = s['lat'];
    final lonRaw = s['long'];
    if (nameRaw is! String ||
        comuneRaw is! String ||
        provinciaRaw is! String ||
        latRaw is! num ||
        lonRaw is! num) {
      continue;
    }
    final name = nameRaw.trim();
    final comune = comuneRaw.trim();
    final provincia = provinciaRaw.trim().toUpperCase();
    if (name.isEmpty || comune.isEmpty || provincia.isEmpty) continue;
    final p = LatLng(latRaw.toDouble(), lonRaw.toDouble());
    if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
    if (p.latitude.abs() > 90 || p.longitude.abs() > 180) continue;
    out.add(
      FerryStopPin(
        stopName: name,
        comune: comune,
        provincia: provincia,
        point: p,
      ),
    );
  }
  return out;
}

/// Fermate il cui nome e/o ID contengono tutti i token della query (≥2 caratteri),
/// ordinate per rilevanza. Supporta ricerche combinate (es. «Kennedy TRC», «Fiabilandia TRC026»).
List<TransitStopPin> filterAndRankTransitStops(
  List<TransitStopPin> pins,
  String rawQuery,
) {
  final parsed = parseTransitStopSearchQuery(rawQuery);
  if (parsed.traghettoOnly) return const [];

  final tokens = parsed.matchTokens;
  if (tokens.isEmpty) {
    if (parsed.metromareOnly) {
      return pins
          .where((p) => _isTrcStopId(p.stopId))
          .take(18)
          .toList(growable: false);
    }
    return const [];
  }

  final scored = <({TransitStopPin pin, int score})>[];
  for (final pin in pins) {
    if (parsed.metromareOnly && !_isTrcStopId(pin.stopId)) continue;

    final n = pin.stopName.toLowerCase();
    final idNorm = _normalizeStopIdForSearch(pin.stopId);
    if (!transitStopMatchesSearchTokens(
      nameLower: n,
      idNorm: idNorm,
      tokens: tokens,
    )) {
      continue;
    }

    var score = 200;
    var nameTokenHits = 0;
    var idTokenHits = 0;

    for (final token in tokens) {
      final tId = _normalizeStopIdForSearch(token);
      final nameMatch = n.contains(token);
      final idMatch =
          tId.isNotEmpty && idNorm.isNotEmpty && idNorm.contains(tId);

      if (nameMatch) {
        nameTokenHits++;
        if (n.startsWith(token)) score -= 50;
        score += n.indexOf(token);
        if (n == token) score -= 40;
        score += (n.length - token.length) ~/ 4;
      } else {
        score += 8;
      }
      if (idMatch) {
        idTokenHits++;
        if (idNorm == tId) score -= 85;
        if (idNorm.startsWith(tId)) score -= 60;
        score += idNorm.indexOf(tId);
        score += (idNorm.length - tId.length) ~/ 6;
      }
    }

    if (tokens.length >= 2 && nameTokenHits > 0 && idTokenHits > 0) {
      score -= 45;
    }

    scored.add((pin: pin, score: score));
  }
  scored.sort((a, b) => a.score.compareTo(b.score));
  return scored.map((e) => e.pin).toList(growable: false);
}

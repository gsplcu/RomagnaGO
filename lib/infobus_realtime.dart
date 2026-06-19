// Parsing orari in tempo reale da infobus.startromagna.it (InfoFermata + FermateService).
// Uso: match su stop_id (palina), linea e orario programmato come sul sito.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:html/dom.dart' as hdom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'romagna_brand.dart';
import 'stop_transit_schedule.dart';
import 'transiti_at_stop.dart';

const _kInfobusBase = 'https://infobus.startromagna.it';

/// Intervallo refresh: allineato al meta refresh HTML del sito (~60 s).
const Duration kInfobusPollInterval = Duration(seconds: 58);

const Duration _kHttpTimeout = Duration(seconds: 14);

/// Cache elenco fermate per bacino (POST molto pesante): evita di riscaricarlo a ogni pinpoint.
const Duration _kBacinoFermateTtl = Duration(minutes: 30);

final Map<String, String> _targetIdByBasinPalina = {};

final http.Client _infobusHttp = http.Client();

class _BacinoFermatePayload {
  _BacinoFermatePayload(this.rows, this.fetchedAt);

  final List<dynamic> rows;
  final DateTime fetchedAt;
}

final Map<String, _BacinoFermatePayload> _bacinoFermateCache = {};
final Map<String, Future<List<dynamic>>> _bacinoFermateInflight = {};
final Map<String, Future<List<InfobusArrivalCard>?>> _arrivalsInflight = {};

class _ArrivalsCacheEntry {
  _ArrivalsCacheEntry(this.cards, this.fetchedAt);

  final List<InfobusArrivalCard> cards;
  final DateTime fetchedAt;
}

/// Ultimo elenco InfoFermata per palina (prefetch al tap sul pinpoint → foglio immediato).
final Map<String, _ArrivalsCacheEntry> _arrivalsCache = {};
const Duration _kArrivalsCacheTtl = Duration(seconds: 55);

/// Svuota cache runtime InfoBus (impostazioni → Svuota cache).
void clearInfobusRuntimeCache() {
  _bacinoFermateCache.clear();
  _arrivalsCache.clear();
  _bacinoFermateInflight.clear();
  _arrivalsInflight.clear();
  _targetIdByBasinPalina.clear();
}

String _cacheKey(String basinLower, String palina) =>
    '${basinLower.trim().toLowerCase()}|${palina.trim().toUpperCase()}';

/// Decodifica JSON in isolate per risposte molto grandi (lista fermate bacino).
dynamic _decodeJsonBg(String body) => json.decode(body);

void _fillTargetIdsFromRows(String basinLower, List<dynamic> rows) {
  for (final item in rows) {
    if (item is! Map) continue;
    final pal = item['palina']?.toString().trim().toUpperCase() ?? '';
    final tid = item['targetID']?.toString().trim() ?? '';
    if (pal.isEmpty || tid.isEmpty) continue;
    _targetIdByBasinPalina[_cacheKey(basinLower, pal)] = tid;
  }
}

Future<List<dynamic>> _downloadBacinoFermateRows(String b) async {
  final uri = Uri.parse('$_kInfobusBase/FermateService.asmx/GetFermateByBacino');
  final res = await _infobusHttp
      .post(
        uri,
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: json.encode({'bacino': b}),
      )
      .timeout(_kHttpTimeout);
  if (res.statusCode != 200) {
    throw StateError('GetFermateByBacino HTTP ${res.statusCode}');
  }
  final body = res.body;
  final dynamic decoded =
      body.length > 100000
          ? await compute(_decodeJsonBg, body)
          : json.decode(body);
  final d = decoded['d'];
  if (d is! List) {
    throw StateError('GetFermateByBacino: campo d assente');
  }
  return d;
}

Future<List<dynamic>> _ensureBacinoFermateRows(String b) async {
  final now = DateTime.now();
  final cached = _bacinoFermateCache[b];
  if (cached != null && now.difference(cached.fetchedAt) < _kBacinoFermateTtl) {
    return cached.rows;
  }

  final infl = _bacinoFermateInflight[b];
  if (infl != null) return infl;

  final fut = () async {
    final rows = await _downloadBacinoFermateRows(b);
    _bacinoFermateCache[b] = _BacinoFermatePayload(rows, DateTime.now());
    _fillTargetIdsFromRows(b, rows);
    return rows;
  }();

  _bacinoFermateInflight[b] = fut;
  try {
    return await fut;
  } finally {
    _bacinoFermateInflight.remove(b);
  }
}

Future<String?> infobusResolveTargetId({
  required String basinLower,
  required String palina,
}) async {
  final b = basinLower.trim().toLowerCase();
  final p = palina.trim().toUpperCase();
  if (b.isEmpty || p.isEmpty) return null;
  if (b != 'fc' && b != 'ra' && b != 'rn') return null;

  final ck = _cacheKey(b, p);
  final hit = _targetIdByBasinPalina[ck];
  if (hit != null) return hit;

  try {
    await _ensureBacinoFermateRows(b);
  } catch (_) {
    return null;
  }
  return _targetIdByBasinPalina[ck];
}

/// Avvia in background il fetch RT (stesso [infobusFetchArrivalsForStop]): utile al tap sul pinpoint
/// così la richiesta parte prima che il foglio sia montato.
void infobusPrefetchArrivalsForStop({
  required String basinLower,
  required String palina,
}) {
  final b = basinLower.trim().toLowerCase();
  final p = palina.trim();
  if (p.isEmpty || (b != 'fc' && b != 'ra' && b != 'rn')) return;
  unawaited(infobusFetchArrivalsForStop(basinLower: b, palina: p));
}

/// Una corsa mostrata in InfoFermata (dopo filtro NON DISP; le soppressa restano nel modello).
class InfobusArrivalCard {
  const InfobusArrivalCard({
    required this.lineLabel,
    required this.scheduledHm,
    required this.destination,
    required this.badgeText,
    required this.classes,
    this.tripId,
  });

  /// Etichetta linea normalizzata (es. `1`, `94`, `Metromare`).
  final String lineLabel;
  final String scheduledHm;
  final String destination;
  final String badgeText;
  final Set<String> classes;
  final String? tripId;
}

enum InfobusRtKind {
  punctual,
  earlyMinutes,
  delayMinutes,
  delayClock,
  arriving,
  suppressed,
  unknown,
}

InfobusRtKind classifyInfobusBadge({
  required String scheduledHm,
  required String badgeText,
  required Set<String> classes,
}) {
  final t = badgeText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (classes.contains('sopp') || t.contains('SOPPRESS')) {
    return InfobusRtKind.suppressed;
  }
  if (t.contains('NON DISP')) return InfobusRtKind.unknown;

  if (classes.contains('arriving') || t.contains('IN ARRIVO')) {
    return InfobusRtKind.arriving;
  }
  if (RegExp(r'-\s*\d+').hasMatch(t) && t.contains('MINUT')) {
    return InfobusRtKind.earlyMinutes;
  }
  if (RegExp(r'\+\s*\d+').hasMatch(t) && t.contains('MINUT')) {
    return InfobusRtKind.delayMinutes;
  }
  if (classes.contains('delayed') && _looksLikeHm(badgeText.trim())) {
    return InfobusRtKind.delayClock;
  }
  if (classes.contains('on-time')) {
    final b = badgeText.trim();
    if (_looksLikeHm(b) && b == scheduledHm) return InfobusRtKind.punctual;
    if (t.contains('MINUT') && t.contains('-')) return InfobusRtKind.earlyMinutes;
  }
  if (classes.contains('delayed')) {
    return InfobusRtKind.delayMinutes;
  }
  if (_looksLikeHm(badgeText.trim())) {
    return InfobusRtKind.delayClock;
  }
  return InfobusRtKind.unknown;
}

bool _looksLikeHm(String s) {
  return RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s.trim());
}

String _lineLabelFromBusHeader(hdom.Element? header) {
  if (header == null) return '';
  final html = header.innerHtml;
  final m1 = RegExp(
    r'Linea\s*</span>\s*([^<\n\r]+)',
    caseSensitive: false,
  ).firstMatch(html);
  if (m1 != null) {
    return m1.group(1)!.trim();
  }
  final m2 = RegExp(
    r'>\s*Linea\s+([^<\n\r]+)',
    caseSensitive: false,
  ).firstMatch(html);
  if (m2 != null) {
    return m2.group(1)!.trim();
  }
  final flat = header.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final m3 = RegExp(
    r'Linea\s+([A-Za-z0-9/]+)',
    caseSensitive: false,
  ).firstMatch(flat);
  if (m3 != null) return m3.group(1)!.trim();
  if (flat.toLowerCase().contains('metromare')) return 'Metromare';
  return '';
}

List<InfobusArrivalCard> parseInfobusInfoFermataHtml(String body) {
  final doc = html_parser.parse(body);
  final out = <InfobusArrivalCard>[];
  for (final card in doc.querySelectorAll('div.bus-card')) {
    final dest = card.querySelector('.bus-destination')?.text.trim() ?? '';
    final times = card.querySelectorAll('.bus-times span');
    if (times.length < 2) continue;
    final sched = times[0].text.trim();
    final statusEl = times[1];
    final badgeText = statusEl.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final classes = statusEl.classes.toSet();

    final uBadge = badgeText.toUpperCase();
    if (uBadge.contains('NON DISP')) continue;

    final header = card.querySelector('.bus-header');
    final lineRaw = _lineLabelFromBusHeader(header);
    if (lineRaw.isEmpty) continue;

    final trip =
        card.querySelector('a.dettaglio-btn')?.attributes['data-trip'];

    out.add(
      InfobusArrivalCard(
        lineLabel: lineRaw,
        scheduledHm: sched,
        destination: dest,
        badgeText: badgeText,
        classes: classes,
        tripId: trip,
      ),
    );
  }
  return out;
}

Future<List<InfobusArrivalCard>?> infobusFetchArrivalsForStop({
  required String basinLower,
  required String palina,
}) async {
  final key = _cacheKey(basinLower, palina);
  final cached = _arrivalsCache[key];
  if (cached != null &&
      DateTime.now().difference(cached.fetchedAt) < _kArrivalsCacheTtl) {
    return cached.cards;
  }

  final infl = _arrivalsInflight[key];
  if (infl != null) return infl;

  final fut = _fetchArrivalsForStopImpl(basinLower: basinLower, palina: palina);
  _arrivalsInflight[key] = fut;
  try {
    final list = await fut;
    if (list != null) {
      _arrivalsCache[key] = _ArrivalsCacheEntry(list, DateTime.now());
    }
    return list;
  } finally {
    _arrivalsInflight.remove(key);
  }
}

Future<List<InfobusArrivalCard>?> _fetchArrivalsForStopImpl({
  required String basinLower,
  required String palina,
}) async {
  final tid = await infobusResolveTargetId(basinLower: basinLower, palina: palina);
  if (tid == null) return null;

  final b = basinLower.trim().toLowerCase();
  final uri = Uri.parse(
    '$_kInfobusBase/InfoFermata.aspx?param=${Uri.encodeQueryComponent(tid)}'
    '&param2=${Uri.encodeQueryComponent(b)}'
    '&palina=${Uri.encodeQueryComponent(palina.trim())}',
  );
  try {
    final res = await _infobusHttp.get(uri).timeout(_kHttpTimeout);
    if (res.statusCode != 200) return null;
    return parseInfobusInfoFermataHtml(res.body);
  } catch (_) {
    return null;
  }
}

/// Una fermata del percorso corsa (InfoBus `PercorsoService.asmx/GetPercorso`).
class InfobusPercorsoStop {
  const InfobusPercorsoStop({
    required this.stopId,
    required this.stopName,
    required this.arrivalHm,
    required this.sequence,
    this.rowClass = '',
  });

  final String stopId;
  final String stopName;
  final String arrivalHm;
  final int sequence;
  final String rowClass;
}

List<InfobusPercorsoStop> parseInfobusPercorsoPayload(dynamic decoded) {
  if (decoded is! List) return const [];
  final out = <InfobusPercorsoStop>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final sid = item['stop_id']?.toString().trim() ?? '';
    if (sid.isEmpty) continue;
    final name = item['stop_name']?.toString().trim() ?? '';
    final arr =
        item['arrival_time']?.toString().trim() ??
        item['departure_time']?.toString().trim() ??
        '';
    if (arr.isEmpty) continue;
    final seq = int.tryParse(item['stop_sequence']?.toString() ?? '') ?? 0;
    out.add(
      InfobusPercorsoStop(
        stopId: sid,
        stopName: name,
        arrivalHm: arr,
        sequence: seq,
        rowClass: item['rowClass']?.toString().trim() ?? '',
      ),
    );
  }
  out.sort((a, b) {
    if (a.sequence != 0 || b.sequence != 0) {
      return a.sequence.compareTo(b.sequence);
    }
    return a.arrivalHm.compareTo(b.arrivalHm);
  });
  return out;
}

/// Tabellone fermate da percorso InfoBus (ordine di marcia, sequence crescente).
List<TransitTripStopRow> transitTripRowsFromInfobusPercorso(
  List<InfobusPercorsoStop> stops,
) {
  return [
    for (final s in stops)
      TransitTripStopRow(
        stopId: s.stopId,
        depRaw: s.arrivalHm.contains(':') && s.arrivalHm.split(':').length == 2
            ? '${s.arrivalHm}:00'
            : s.arrivalHm,
        seq: s.sequence,
      ),
  ];
}

Map<String, String> stopNamesFromInfobusPercorso(List<InfobusPercorsoStop> stops) {
  final out = <String, String>{};
  for (final s in stops) {
    final id = s.stopId.trim();
    final name = s.stopName.trim();
    if (id.isNotEmpty && name.isNotEmpty) {
      out[id] = name;
    }
  }
  return out;
}

/// Percorso programmato di una corsa (come «Dettaglio» su InfoFermata).
Future<List<InfobusPercorsoStop>?> infobusFetchTripPercorso({
  required String tripId,
  required String palina,
}) async {
  final tid = tripId.trim();
  final pal = palina.trim().toUpperCase();
  if (tid.isEmpty || pal.isEmpty) return null;

  final uri = Uri.parse('$_kInfobusBase/PercorsoService.asmx/GetPercorso');
  try {
    final res = await _infobusHttp
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: json.encode({'trip_id': tid, 'palina': pal}),
        )
        .timeout(_kHttpTimeout);
    if (res.statusCode != 200) return null;
    final outer = json.decode(res.body);
    if (outer is! Map) return null;
    final d = outer['d'];
    if (d == null) return null;
    final dynamic inner = d is String ? json.decode(d) : d;
    return parseInfobusPercorsoPayload(inner);
  } catch (_) {
    return null;
  }
}

String _hmFromDateTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Confronto destinazioni InfoBus ↔ testo catalogo (tollerante).
bool infobusDestSoftMatch(String appTowards, String siteDest) =>
    transitDestinationsMatch(appTowards, siteDest);

int? _intIfAllDigits(String x) {
  final t = x.trim();
  if (t.isEmpty || !RegExp(r'^\d+$').hasMatch(t)) return null;
  return int.tryParse(t);
}

/// Suffisso numerico finale (es. `CE01` → 1, `FO13` → 13).
int? _trailingIntToken(String x) {
  final m = RegExp(r'(\d+)\s*$').firstMatch(x.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// `S091` / `s094` → 91 / 94 (suburbane FC).
int? _sPrefixedRouteNumber(String x) {
  final m = RegExp(r'^[Ss](\d+)$').firstMatch(x.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// `SA96` → 96 (varianti lettera dopo S).
int? _sAlphaNumericRouteNumber(String x) {
  final m = RegExp(r'^[Ss][A-Za-z]?(\d+)$').firstMatch(x.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// Leading digit block (es. `1CO` → 1, `10` → 10).
int? _leadingIntToken(String x) {
  final m = RegExp(r'^(\d+)').firstMatch(x.trim());
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

bool _lineMatchesBubble(String siteLine, String appLineLabel) {
  final s = siteLine.trim();
  final a = appLineLabel.trim();
  if (s.isEmpty || a.isEmpty) return false;
  if (s.toLowerCase() == a.toLowerCase()) return true;

  // Solo cifre: «04» ↔ «4»
  final si = _intIfAllDigits(s);
  final ai = _intIfAllDigits(a);
  if (si != null && ai != null && si == ai) return true;

  // S094 ↔ 94
  final sTrain = _sPrefixedRouteNumber(s);
  if (sTrain != null && ai != null && sTrain == ai) return true;
  final aTrain = _sPrefixedRouteNumber(a);
  if (aTrain != null && si != null && aTrain == si) return true;

  // SA96 ↔ 96A / 96
  final sSa = _sAlphaNumericRouteNumber(s);
  final aLead = _leadingIntToken(a);
  if (sSa != null && aLead != null && sSa == aLead) return true;
  final aSa = _sAlphaNumericRouteNumber(a);
  final sLead = _leadingIntToken(s);
  if (aSa != null && sLead != null && aSa == sLead) return true;

  // CE01, FO13… (lettere + cifre sul sito) ↔ numero linea in catalogo (es. «1», «13»)
  if (ai != null &&
      RegExp(r'^[A-Za-z]{1,4}\d+$').hasMatch(s) &&
      _trailingIntToken(s) == ai) {
    return true;
  }
  if (si != null &&
      RegExp(r'^[A-Za-z]{1,4}\d+$').hasMatch(a) &&
      _trailingIntToken(a) == si) {
    return true;
  }

  // Catalogo «1» ↔ sito «1CO», «1A»…
  if (ai != null) {
    final head = _leadingIntToken(s);
    if (head != null && head == ai) {
      final rest = s.substring(RegExp(r'^\d+').firstMatch(s)!.end);
      if (rest.isEmpty || RegExp(r'^[A-Za-z]').hasMatch(rest)) return true;
    }
  }
  if (si != null) {
    final head = _leadingIntToken(a);
    if (head != null && head == si) {
      final rest = a.substring(RegExp(r'^\d+').firstMatch(a)!.end);
      if (rest.isEmpty || RegExp(r'^[A-Za-z]').hasMatch(rest)) return true;
    }
  }

  if (a.contains('/')) {
    for (final p in a.split('/')) {
      final t = p.trim();
      if (t.isNotEmpty && _lineMatchesBubble(s, t)) return true;
    }
  }
  if (s.contains('/')) {
    for (final p in s.split('/')) {
      final t = p.trim();
      if (t.isNotEmpty && _lineMatchesBubble(t, a)) return true;
    }
  }

  return false;
}

/// Etichetta linea dal sito InfoBus vs [StopTransitLineBubble.lineaLabel] in app.
bool infobusSiteLineMatchesBubbleLine(
  String siteLine,
  String bubbleLineaLabel,
) =>
    _lineMatchesBubble(siteLine, bubbleLineaLabel);

/// Token linea InfoBus: etichetta + suffisso località (CO, CE, FO, FC, RA…).
class InfobusSiteLineToken {
  const InfobusSiteLineToken({required this.lineLabel, this.siteLocality});

  final String lineLabel;
  final String? siteLocality;

  String get displayLabel {
    final line = lineLabel.trim();
    final loc = siteLocality?.trim();
    if (line.isEmpty) return '';
    if (loc == null || loc.isEmpty) return line;
    return '$line ${loc.toUpperCase()}';
  }

  static InfobusSiteLineToken? tryParseDisplay(String raw) {
    final part = raw.trim();
    if (part.isEmpty) return null;
    final m = RegExp(
      r'^(.+?)\s+(CO|CE|FO|FC|RA|RN)$',
      caseSensitive: false,
    ).firstMatch(part);
    if (m == null) return InfobusSiteLineToken(lineLabel: part);
    return InfobusSiteLineToken(
      lineLabel: m.group(1)!.trim(),
      siteLocality: m.group(2)!.trim().toUpperCase(),
    );
  }
}

/// Riga catalogo minima per risolvere token avvisi → route_id.
class InfobusCatalogLine {
  const InfobusCatalogLine({
    required this.linea,
    required this.bacino,
    required this.area,
    required this.routeId,
  });

  final String linea;
  final String bacino;
  final String area;
  final String routeId;
}

/// Indice linee per matching avvisi InfoBus (distinzione Cesena / Cesenatico / Forlì…).
class InfobusLineCatalog {
  InfobusLineCatalog(List<InfobusCatalogLine> rows)
    : _rows = List<InfobusCatalogLine>.from(rows),
      _byRouteId = {
        for (final r in rows) r.routeId.toUpperCase(): r,
      };

  final List<InfobusCatalogLine> _rows;
  final Map<String, InfobusCatalogLine> _byRouteId;

  InfobusCatalogLine? rowForRouteId(String routeId) =>
      _byRouteId[routeId.trim().toUpperCase()];

  Iterable<InfobusCatalogLine> rowsInBasin(String basin) sync* {
    final b = basin.trim().toUpperCase();
    for (final r in _rows) {
      if (r.bacino.trim().toUpperCase() == b) yield r;
    }
  }
}

/// Suffisso località Start Romagna (grigio accanto al numero linea sul sito).
String? infobusSiteLocalityForCatalogLine(InfobusCatalogLine row) {
  final rid = row.routeId.trim().toUpperCase();
  if (rid.endsWith('CO')) return 'CO';
  if (rid.startsWith('CE')) return 'CE';
  if (rid.startsWith('FO')) return 'FO';
  if (row.bacino.trim().toUpperCase() == 'RA' && row.area == 'Ravenna') {
    return 'RA';
  }
  if (row.bacino.trim().toUpperCase() == 'RN') return 'RN';
  if (row.area == 'Suburbano' || row.area == 'Extraurbano') return 'FC';
  return null;
}

/// Da titolo/sottotitolo avviso (es. «FC extraurbano ∙ Cesenatico»).
String? inferInfobusAvvisoLocalityHint(String title, String subtitle) {
  final t = '${title.toLowerCase()} ${subtitle.toLowerCase()}';
  if (t.contains('cesenatico')) return 'CO';
  if (RegExp(r'\bcesena\b').hasMatch(t)) return 'CE';
  if (t.contains('forlì') || t.contains('forli')) return 'FO';
  if (RegExp(r'\bravenna\b').hasMatch(t) &&
      !t.contains('extraurbano') &&
      !t.contains('fc extraurbano')) {
    return 'RA';
  }
  if (RegExp(r'\brimini\b').hasMatch(t) && !t.contains('extraurbano')) {
    return 'RN';
  }
  return null;
}

/// Confronto etichette linea per avvisi (senza falsi positivi 1↔1A↔10↔1CO).
bool infobusSiteLineLabelMatches(String siteLabel, String catalogLinea) {
  final s = siteLabel.trim();
  final a = catalogLinea.trim();
  if (s.isEmpty || a.isEmpty) return false;
  if (s.toLowerCase() == a.toLowerCase()) return true;

  final si = _intIfAllDigits(s);
  final ai = _intIfAllDigits(a);
  if (si != null && ai != null && si == ai) return true;

  final sTrain = _sPrefixedRouteNumber(s);
  if (sTrain != null && ai != null && sTrain == ai) return true;
  final aTrain = _sPrefixedRouteNumber(a);
  if (aTrain != null && si != null && aTrain == si) return true;

  final sSa = _sAlphaNumericRouteNumber(s);
  final aLead = _leadingIntToken(a);
  if (sSa != null && aLead != null && sSa == aLead) return true;
  final aSa = _sAlphaNumericRouteNumber(a);
  final sLead = _leadingIntToken(s);
  if (aSa != null && sLead != null && aSa == sLead) return true;

  if (ai != null &&
      RegExp(r'^[A-Za-z]{1,4}\d+$').hasMatch(s) &&
      _trailingIntToken(s) == ai) {
    return true;
  }
  if (si != null &&
      RegExp(r'^[A-Za-z]{1,4}\d+$').hasMatch(a) &&
      _trailingIntToken(a) == si) {
    return true;
  }

  if (a.contains('/')) {
    for (final p in a.split('/')) {
      final t = p.trim();
      if (t.isNotEmpty && infobusSiteLineLabelMatches(s, t)) return true;
    }
  }
  if (s.contains('/')) {
    for (final p in s.split('/')) {
      final t = p.trim();
      if (t.isNotEmpty && infobusSiteLineLabelMatches(t, a)) return true;
    }
  }

  return false;
}

List<String> _resolveInfobusSiteTokenRouteIds({
  required InfobusSiteLineToken token,
  required String requiredBasin,
  required InfobusLineCatalog catalog,
  String? avvisoLocalityHint,
}) {
  final basin = requiredBasin.trim().toUpperCase();
  final label = token.lineLabel.trim();
  if (label.isEmpty) return const [];

  final matching =
      catalog.rowsInBasin(basin).where((r) {
        return infobusSiteLineLabelMatches(label, r.linea);
      }).toList();
  if (matching.isEmpty) return const [];

  String? normLoc(String? v) {
    final t = v?.trim().toUpperCase();
    return t == null || t.isEmpty ? null : t;
  }

  final explicitLoc = normLoc(token.siteLocality);
  final hintLoc = normLoc(avvisoLocalityHint);

  List<InfobusCatalogLine> pickByLocality(String? loc) {
    if (loc == null) return const [];
    return matching
        .where((r) => infobusSiteLocalityForCatalogLine(r) == loc)
        .toList();
  }

  for (final loc in [explicitLoc, hintLoc]) {
    final picked = pickByLocality(loc);
    if (picked.isNotEmpty) {
      return picked.map((r) => r.routeId).toList();
    }
  }

  if (matching.length == 1) return [matching.single.routeId];

  final suburban =
      matching
          .where(
            (r) =>
                r.area == 'Suburbano' ||
                r.area == 'Extraurbano' ||
                infobusSiteLocalityForCatalogLine(r) == 'FC',
          )
          .toList();
  if (suburban.length == 1 && matching.length > 1) {
    return [suburban.single.routeId];
  }

  return const [];
}

/// Etichetta filtro avvisi quando lo stesso numero compare in più aree (es. «1 Cesena»).
String infobusAvvisiFilterDisplayLabel(
  InfobusCatalogLine row, {
  required bool ambiguousInBasin,
}) {
  if (!ambiguousInBasin) return row.linea;
  switch (infobusSiteLocalityForCatalogLine(row)) {
    case 'CO':
      return '${row.linea} Cesenatico';
    case 'CE':
      return '${row.linea} Cesena';
    case 'FO':
      return '${row.linea} Forlì';
    case 'RA':
      return '${row.linea} Ravenna';
    case 'RN':
      return '${row.linea} Rimini';
    default:
      return '${row.linea} (${row.area})';
  }
}

/// True se l'avviso riguarda [filterRouteId] nel bacino [requiredBasin].
bool infobusAvvisoMatchesRouteId({
  required List<InfobusSiteLineToken> lineTokens,
  required String? avvisoLocalityHint,
  required Set<String> avvisoBasins,
  required String requiredBasin,
  required String filterRouteId,
  required InfobusLineCatalog catalog,
}) {
  final routeId = filterRouteId.trim();
  if (routeId.isEmpty) return true;

  final basin = requiredBasin.trim().toUpperCase();
  if (basin.isEmpty) return false;
  final basinsUpper = avvisoBasins.map((b) => b.trim().toUpperCase()).toSet();
  if (!basinsUpper.contains(basin)) return false;

  final filterRow = catalog.rowForRouteId(routeId);
  if (filterRow == null) return false;
  if (filterRow.bacino.trim().toUpperCase() != basin) return false;

  for (final tok in lineTokens) {
    final resolved = _resolveInfobusSiteTokenRouteIds(
      token: tok,
      requiredBasin: basin,
      catalog: catalog,
      avvisoLocalityHint: avvisoLocalityHint,
    );
    if (resolved.any((id) => id.toUpperCase() == routeId.toUpperCase())) {
      return true;
    }
  }
  return false;
}

/// Token linea dal campo InfoBus «Linee interessate» (separatori `·` in elenco app).
List<String> infobusLineeInteressateTokens(String lineeInteressate) {
  if (lineeInteressate.trim().isEmpty) return const [];
  return lineeInteressate
      .split('·')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

List<InfobusSiteLineToken> infobusLineeInteressateParsed(String lineeInteressate) {
  return infobusLineeInteressateTokens(lineeInteressate)
      .map(InfobusSiteLineToken.tryParseDisplay)
      .whereType<InfobusSiteLineToken>()
      .toList();
}

/// True se l’avviso riguarda [lineLabel] nel bacino [requiredBasin] (FC / RA / RN).
bool infobusAvvisoMatchesLineLabel(
  String lineeInteressate,
  String lineLabel, {
  required Set<String> avvisoBasins,
  required String requiredBasin,
  InfobusLineCatalog? catalog,
  String? avvisoLocalityHint,
  String? filterRouteId,
}) {
  final label = lineLabel.trim();
  if (label.isEmpty) return true;

  final basin = requiredBasin.trim().toUpperCase();
  if (basin.isEmpty) return false;
  final basinsUpper = avvisoBasins.map((b) => b.trim().toUpperCase()).toSet();
  if (!basinsUpper.contains(basin)) return false;

  final tokens = infobusLineeInteressateParsed(lineeInteressate);
  if (catalog != null &&
      filterRouteId != null &&
      filterRouteId.trim().isNotEmpty) {
    return infobusAvvisoMatchesRouteId(
      lineTokens: tokens,
      avvisoLocalityHint: avvisoLocalityHint,
      avvisoBasins: avvisoBasins,
      requiredBasin: requiredBasin,
      filterRouteId: filterRouteId,
      catalog: catalog,
    );
  }

  for (final tok in tokens) {
    if (infobusSiteLineLabelMatches(tok.lineLabel, label)) return true;
  }
  return false;
}

/// Testo linea in elenco quando InfoBus usa «4» per la linea Cesenatico 1+2 (bubble «4 CO»).
String infobusSiteLineLabelForUi(
  String siteLineLabel,
  List<StopTransitLineBubble> bubbles,
) {
  final s = siteLineLabel.trim();
  if (s == '4' &&
      bubbles.any(
        (b) =>
            b.lineaLabel.trim() == '4' &&
            b.bacinoUpper.trim().toUpperCase() == 'CO',
      )) {
    return '4';
  }
  return siteLineLabel;
}

/// Assegna ogni carta del sito al massimo a una riga app (linea + orario programmato + destinazione).
Map<int, InfobusArrivalCard> matchInfobusToDepartures({
  required List<UpcomingTransitDepartureUi> rows,
  required List<InfobusArrivalCard> site,
}) {
  final pool = List<InfobusArrivalCard>.from(site);
  final out = <int, InfobusArrivalCard>{};

  for (var i = 0; i < rows.length; i++) {
    final u = rows[i];
    final wantHm = _hmFromDateTime(u.when);
    InfobusArrivalCard? best;
    var bestScore = 0;
    for (final c in pool) {
      if (!_lineMatchesBubble(c.lineLabel, u.lineLabel)) continue;
      if (!_scheduledHmEquals(c.scheduledHm, wantHm)) continue;
      var score = 50;
      if (infobusDestSoftMatch(u.towards, c.destination)) score += 40;
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    if (best != null) {
      out[i] = best;
      pool.remove(best);
    }
  }

  // Seconda passata: linea + orario univoci nel pool (stesso HH:MM).
  for (var i = 0; i < rows.length; i++) {
    if (out.containsKey(i)) continue;
    final u = rows[i];
    final wantHm = _hmFromDateTime(u.when);
    final candidates =
        pool
            .where(
              (c) =>
                  _lineMatchesBubble(c.lineLabel, u.lineLabel) &&
                  _scheduledHmEquals(c.scheduledHm, wantHm),
            )
            .toList();
    if (candidates.length == 1) {
      final c = candidates.first;
      out[i] = c;
      pool.remove(c);
    }
  }

  // Terza passata: linea + destinazione e orario programmato entro ±2 min (una sola carta candidata).
  for (var i = 0; i < rows.length; i++) {
    if (out.containsKey(i)) continue;
    final u = rows[i];
    final wantMin = _hmToMinutesSinceMidnight(_hmFromDateTime(u.when));
    if (wantMin == null) continue;
    final near = <InfobusArrivalCard>[];
    for (final c in pool) {
      if (!_lineMatchesBubble(c.lineLabel, u.lineLabel)) continue;
      if (!infobusDestSoftMatch(u.towards, c.destination)) continue;
      final sm = _hmToMinutesSinceMidnight(_normalizeHm(c.scheduledHm));
      if (sm == null) continue;
      var diff = sm - wantMin;
      if (diff > 12 * 60) diff -= 24 * 60;
      if (diff < -12 * 60) diff += 24 * 60;
      if (diff.abs() <= 2) near.add(c);
    }
    if (near.length == 1) {
      final c = near.first;
      out[i] = c;
      pool.remove(c);
    }
  }

  return out;
}

/// Alias per le prime partenze in home sheet.
Map<int, InfobusArrivalCard> matchInfobusToUpcoming({
  required List<UpcomingTransitDepartureUi> upcoming,
  required List<InfobusArrivalCard> site,
}) => matchInfobusToDepartures(rows: upcoming, site: site);

/// Istante su giornata di servizio vicina a [reference] (gestisce cambio data).
DateTime wallClockInstantNearReference({
  required int minutesSinceMidnight,
  required DateTime reference,
}) {
  final day = DateTime(reference.year, reference.month, reference.day);
  var inst = DateTime(
    day.year,
    day.month,
    day.day,
    (minutesSinceMidnight ~/ 60) % 24,
    minutesSinceMidnight % 60,
  );
  if (inst.isAfter(reference.add(const Duration(hours: 3)))) {
    inst = inst.subtract(const Duration(days: 1));
  } else if (inst.isBefore(reference.subtract(const Duration(hours: 21)))) {
    inst = inst.add(const Duration(days: 1));
  }
  return inst;
}

/// Orario stimato di partenza dalla fermata (RT InfoBus), null se non calcolabile.
DateTime? infobusEffectiveDepartureInstant(
  InfobusArrivalCard card,
  DateTime now,
) {
  final kind = classifyInfobusBadge(
    scheduledHm: card.scheduledHm,
    badgeText: card.badgeText,
    classes: card.classes,
  );
  if (kind == InfobusRtKind.suppressed) return null;

  final head = infobusTripTimetableHeadUi(card);
  final min = _hmToMinutesSinceMidnight(head.arrivalClock);
  if (min == null) return null;
  return wallClockInstantNearReference(minutesSinceMidnight: min, reference: now);
}

/// True se la corsa non è ancora partita dalla fermata (ritardo futuro, in arrivo, …).
bool infobusDepartureStillPendingAtStop(InfobusArrivalCard card, DateTime now) {
  final kind = classifyInfobusBadge(
    scheduledHm: card.scheduledHm,
    badgeText: card.badgeText,
    classes: card.classes,
  );
  if (kind == InfobusRtKind.arriving) return true;
  if (kind == InfobusRtKind.suppressed) return false;

  final eff = infobusEffectiveDepartureInstant(card, now);
  if (eff == null) {
    final sm = _hmToMinutesSinceMidnight(_normalizeHm(card.scheduledHm));
    if (sm == null) return true;
    return wallClockInstantNearReference(
      minutesSinceMidnight: sm,
      reference: now,
    ).isAfter(now);
  }
  return eff.isAfter(now);
}

/// Partenza già avvenuta (≤30 min fa) con orario effettivo RT o programmato.
class RecentPastDepartureUi {
  const RecentPastDepartureUi({
    required this.departure,
    required this.bubble,
    required this.effectiveDeparture,
    required this.effectiveClockLabel,
    required this.departedWithRt,
    this.infobusCard,
  });

  final UpcomingTransitDepartureUi departure;
  final StopTransitLineBubble bubble;
  final DateTime effectiveDeparture;
  final String effectiveClockLabel;
  final bool departedWithRt;
  final InfobusArrivalCard? infobusCard;
}

String _recentPastDedupeKey(RecentPastDepartureUi r) {
  final eff = r.effectiveDeparture;
  final slot = DateTime(eff.year, eff.month, eff.day, eff.hour, eff.minute);
  return '${r.bubble.lineaLabel}|${r.departure.towards}|${slot.millisecondsSinceEpoch}';
}

String _upcomingRowKey(UpcomingTransitDepartureUi u) {
  final slot = DateTime(
    u.when.year,
    u.when.month,
    u.when.day,
    u.when.hour,
    u.when.minute,
  );
  return '${u.lineLabel}|${u.secondaryLabel}|${slot.millisecondsSinceEpoch}|${u.towards.trim()}';
}

/// Fino a 3 partenze più recenti già partite (finestra 30 min dall’orario effettivo).
List<RecentPastDepartureUi> computeRecentPastDeparturesUi({
  required String rawStopId,
  required List<StopTransitLineBubble> bubbles,
  required StopTransitScheduleIndex schedule,
  List<InfobusArrivalCard> siteCards = const [],
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);

  final upcoming = computeUpcomingDeparturesUi(
    rawStopId: rawStopId,
    bubbles: bubbles,
    schedule: schedule,
    now: t,
  );
  final upcomingKeys = upcoming.map(_upcomingRowKey).toSet();

  final allToday = computeDeparturesForStopOnLocalDay(
    rawStopId: rawStopId,
    bubbles: bubbles,
    schedule: schedule,
    onLocalDay: today,
  );

  // Finestra ampia su programmato per catturare ritardi poi partiti.
  final coarse =
      allToday
          .where(
            (u) =>
                !u.when.isAfter(t) &&
                t.difference(u.when) <= const Duration(minutes: 90),
          )
          .toList();

  final ibMatch = matchInfobusToDepartures(rows: coarse, site: siteCards);
  final candidates = <RecentPastDepartureUi>[];

  for (var i = 0; i < coarse.length; i++) {
    final u = coarse[i];
    if (upcomingKeys.contains(_upcomingRowKey(u))) continue;

    final card = ibMatch[i];
    if (card != null && infobusDepartureStillPendingAtStop(card, t)) continue;

    final DateTime effective;
    final String effectiveHm;
    final bool usedRt;

    if (card != null) {
      final eff = infobusEffectiveDepartureInstant(card, t);
      if (eff == null) continue;
      effective = eff;
      effectiveHm = _hmFromDateTime(eff);
      usedRt = true;
    } else {
      effective = u.when;
      effectiveHm = u.clockLabel;
      usedRt = false;
    }

    if (effective.isAfter(t)) continue;
    if (t.difference(effective) > const Duration(minutes: 30)) continue;

    StopTransitLineBubble? bubble;
    for (final b in bubbles) {
      if (b.lineaLabel != u.lineLabel) continue;
      if ((b.secondaryGrey ?? b.bacinoUpper) == u.secondaryLabel) {
        bubble = b;
        break;
      }
    }
    bubble ??= () {
      for (final b in bubbles) {
        if (b.lineaLabel == u.lineLabel) return b;
      }
      return null;
    }();
    if (bubble == null || bubble.scheduleRouteKeys.isEmpty) continue;

    candidates.add(
      RecentPastDepartureUi(
        departure: u,
        bubble: bubble,
        effectiveDeparture: effective,
        effectiveClockLabel: effectiveHm,
        departedWithRt: usedRt,
        infobusCard: card,
      ),
    );
  }

  candidates.sort(
    (a, b) => b.effectiveDeparture.compareTo(a.effectiveDeparture),
  );

  final seen = <String>{};
  final out = <RecentPastDepartureUi>[];
  for (final c in candidates) {
    if (seen.add(_recentPastDedupeKey(c))) {
      out.add(c);
      if (out.length >= 3) break;
    }
  }
  return out;
}

bool _scheduledHmEquals(String siteHm, String wantHm) {
  final a = _normalizeHm(siteHm.trim());
  final b = _normalizeHm(wantHm.trim());
  return a == b;
}

/// Confronta l’orario mostrato da InfoBus (HH:MM) con `depRaw` GTFS.
bool infobusScheduledMatchesGtfsDep(String cardScheduledHm, String gtfsDepRaw) {
  final p = gtfsDepRaw.trim().split(':');
  if (p.length < 2) return false;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  if (h == null || m == null) return false;
  final norm =
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  return _scheduledHmEquals(cardScheduledHm, norm);
}

String _normalizeHm(String hm) {
  final p = hm.split(':');
  if (p.length != 2) return hm;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  if (h == null || m == null) return hm;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

int? _hmToMinutesSinceMidnight(String hm) {
  final p = hm.trim().split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  if (h == null || m == null) return null;
  return h * 60 + m;
}

String _hmFromTotalMinutesWrapped(int totalMinutes) {
  var m = totalMinutes % 1440;
  if (m < 0) m += 1440;
  final h = m ~/ 60;
  final min = m % 60;
  return '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}

/// Sfondo pill nella chip orario (+ ritardo, − anticipo, > in arrivo, SOPPRESSA).
class InfobusChipRt {
  const InfobusChipRt(
    this.suffix,
    this.background, {
    this.foreground,
  });

  final String suffix;
  final Color background;

  /// Testo sulla pill; null = bianco (su rosso saturo).
  final Color? foreground;
}

InfobusChipRt? infobusChipRtForCard(InfobusArrivalCard card) {
  final k = classifyInfobusBadge(
    scheduledHm: card.scheduledHm,
    badgeText: card.badgeText,
    classes: card.classes,
  );
  final t = card.badgeText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  switch (k) {
    case InfobusRtKind.earlyMinutes:
      final n = _signedMinutesFromMinutiPhrase(t);
      if (n == null) return null;
      return InfobusChipRt(
        _formatSignedMinutes(n),
        const Color(0xFFFFC107),
        foreground: kRomagnaDarkGray,
      );
    case InfobusRtKind.delayMinutes:
      final n = _signedMinutesFromMinutiPhrase(t);
      if (n == null) return null;
      return InfobusChipRt(_formatSignedMinutes(n), const Color(0xFFDC3545));
    case InfobusRtKind.delayClock:
      final act = card.badgeText.trim();
      if (!_looksLikeHm(act)) return null;
      final sMin = _hmToMinutesSinceMidnight(card.scheduledHm);
      final aMin = _hmToMinutesSinceMidnight(act);
      if (sMin == null || aMin == null) return null;
      var d = aMin - sMin;
      if (d > 12 * 60) d -= 24 * 60;
      if (d < -12 * 60) d += 24 * 60;
      if (d == 0) return null;
      if (d > 0) {
        return InfobusChipRt(_formatSignedMinutes(d), const Color(0xFFDC3545));
      }
      return InfobusChipRt(
        _formatSignedMinutes(d),
        const Color(0xFFFFC107),
        foreground: kRomagnaDarkGray,
      );
    case InfobusRtKind.arriving:
      return InfobusChipRt(
        '>',
        kRomagnaPrimary,
        foreground: kRomagnaDarkGray,
      );
    case InfobusRtKind.suppressed:
      return const InfobusChipRt('SOPPRESSA', Color(0xFFDC3545));
    case InfobusRtKind.punctual:
    case InfobusRtKind.unknown:
      return null;
  }
}

/// Colore bubble orario in « Prossime partenze » (foglio mappa con InfoBus RT).
Color infobusProssimePartenzeBubbleTint(InfobusArrivalCard m) {
  final kind = classifyInfobusBadge(
    scheduledHm: m.scheduledHm,
    badgeText: m.badgeText,
    classes: m.classes,
  );
  const green = Color(0xFF2E7D32);
  const yellow = Color(0xFFFFC107);
  const red = Color(0xFFDC3545);

  switch (kind) {
    case InfobusRtKind.punctual:
      return green;
    case InfobusRtKind.earlyMinutes:
      return yellow;
    case InfobusRtKind.delayMinutes:
    case InfobusRtKind.suppressed:
      return red;
    case InfobusRtKind.delayClock:
      final act = m.badgeText.trim();
      if (!_looksLikeHm(act)) return kRomagnaPrimary;
      final sNorm = _normalizeHm(m.scheduledHm);
      final aNorm = _normalizeHm(act);
      final sMin = _hmToMinutesSinceMidnight(sNorm);
      final aMin = _hmToMinutesSinceMidnight(aNorm);
      if (sMin == null || aMin == null) return kRomagnaPrimary;
      var d = aMin - sMin;
      if (d > 12 * 60) d -= 24 * 60;
      if (d < -12 * 60) d += 24 * 60;
      if (d > 0) return red;
      if (d < 0) return yellow;
      return green;
    case InfobusRtKind.arriving:
    case InfobusRtKind.unknown:
      return kRomagnaPrimary;
  }
}

String _formatSignedMinutes(int n) {
  if (n > 0) return '+$n';
  if (n < 0) return '$n';
  return '';
}

/// Estrae il valore con segno da stringhe tipo `+ 2 MINUTI` / `- 6 MINUTI`.
int? _signedMinutesFromMinutiPhrase(String tUpper) {
  final m = RegExp(r'([+-])\s*(\d+)').firstMatch(tUpper);
  if (m == null) return null;
  final sign = m.group(1) == '-' ? -1 : 1;
  final v = int.tryParse(m.group(2)!);
  if (v == null) return null;
  return sign * v;
}

/// Testata tabellone corsa: orario stimato in RT, tint bubble, didascalia sotto (vuota se neutro).
class InfobusTripTimetableHeadUi {
  const InfobusTripTimetableHeadUi({
    required this.arrivalClock,
    required this.bubbleTint,
    required this.footerLabel,
    this.isSuppressed = false,
  });

  /// Orario «in arrivo» (HH:MM), comprensivo di ritardo/anticipo quando calcolabile.
  final String arrivalClock;

  /// Rosso ritardo, giallo anticipo, verde orario, azzurro tema negli altri casi.
  final Color bubbleTint;

  /// `IN ORARIO` / `IN ANTICIPO` / `IN RITARDO`; stringa vuota se non applicabile.
  final String footerLabel;

  /// Corsa soppressa secondo InfoBus: mostrare «SOPPRESSA» accanto alla bubble orario.
  final bool isSuppressed;
}

/// Orario in bubble + colori + stato per la card « Alla tua fermata » del tabellone corsa.
InfobusTripTimetableHeadUi infobusTripTimetableHeadUi(InfobusArrivalCard card) {
  final kind = classifyInfobusBadge(
    scheduledHm: card.scheduledHm,
    badgeText: card.badgeText,
    classes: card.classes,
  );
  final t = card.badgeText.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final schedNorm = _normalizeHm(card.scheduledHm);
  final schedMin = _hmToMinutesSinceMidnight(schedNorm);

  const kGreen = Color(0xFF2E7D32);
  const kRed = Color(0xFFDC3545);
  const kYellow = Color(0xFFFFC107);

  InfobusTripTimetableHeadUi neutral() => InfobusTripTimetableHeadUi(
    arrivalClock: schedNorm,
    bubbleTint: kRomagnaPrimary,
    footerLabel: '',
  );

  switch (kind) {
    case InfobusRtKind.suppressed:
      return InfobusTripTimetableHeadUi(
        arrivalClock: schedNorm,
        bubbleTint: kRomagnaPrimary,
        footerLabel: '',
        isSuppressed: true,
      );
    case InfobusRtKind.punctual:
      return InfobusTripTimetableHeadUi(
        arrivalClock: schedNorm,
        bubbleTint: kGreen,
        footerLabel: 'IN ORARIO',
      );
    case InfobusRtKind.earlyMinutes:
      final n = _signedMinutesFromMinutiPhrase(t);
      if (n == null || schedMin == null) return neutral();
      return InfobusTripTimetableHeadUi(
        arrivalClock: _hmFromTotalMinutesWrapped(schedMin + n),
        bubbleTint: kYellow,
        footerLabel: 'IN ANTICIPO',
      );
    case InfobusRtKind.delayMinutes:
      final n = _signedMinutesFromMinutiPhrase(t);
      if (n == null || schedMin == null) return neutral();
      return InfobusTripTimetableHeadUi(
        arrivalClock: _hmFromTotalMinutesWrapped(schedMin + n),
        bubbleTint: kRed,
        footerLabel: 'IN RITARDO',
      );
    case InfobusRtKind.delayClock:
      final act = card.badgeText.trim();
      if (!_looksLikeHm(act)) return neutral();
      final actNorm = _normalizeHm(act);
      final aMin = _hmToMinutesSinceMidnight(actNorm);
      if (schedMin == null || aMin == null) {
        return InfobusTripTimetableHeadUi(
          arrivalClock: actNorm,
          bubbleTint: kRomagnaPrimary,
          footerLabel: '',
        );
      }
      var d = aMin - schedMin;
      if (d > 12 * 60) d -= 24 * 60;
      if (d < -12 * 60) d += 24 * 60;
      if (d == 0) {
        return InfobusTripTimetableHeadUi(
          arrivalClock: actNorm,
          bubbleTint: kGreen,
          footerLabel: 'IN ORARIO',
        );
      }
      if (d > 0) {
        return InfobusTripTimetableHeadUi(
          arrivalClock: actNorm,
          bubbleTint: kRed,
          footerLabel: 'IN RITARDO',
        );
      }
      return InfobusTripTimetableHeadUi(
        arrivalClock: actNorm,
        bubbleTint: kYellow,
        footerLabel: 'IN ANTICIPO',
      );
    case InfobusRtKind.arriving:
    case InfobusRtKind.unknown:
      return neutral();
  }
}

/// Tap sulla chip orario « Prossime partenze » (tabellone corsa + RT); [bubble] è la linea abbinata.
typedef InfobusTripTimeChipTap =
    Future<void> Function(
      BuildContext context,
      UpcomingTransitDepartureUi departure,
      InfobusArrivalCard? matchedSiteCard,
      StopTransitLineBubble bubble,
    );

/// Tap chip « Partenze precedenti ».
typedef InfobusPastTripTimeChipTap =
    Future<void> Function(
      BuildContext context,
      RecentPastDepartureUi past,
      StopTransitLineBubble bubble,
    );

/// Prossime partenze con polling leggero verso InfoBus.
class InfobusUpcomingDeparturesBlock extends StatefulWidget {
  const InfobusUpcomingDeparturesBlock({
    super.key,
    required this.rawStopId,
    required this.basinLower,
    required this.bubbles,
    required this.schedule,
    this.onTripTimeChipTap,
    this.onPastTripTimeChipTap,
  });

  final String rawStopId;
  final String basinLower;
  final List<StopTransitLineBubble> bubbles;
  final StopTransitScheduleIndex schedule;

  /// Se non null, tap sulla chip orario apre il tabellone corsa (implementazione in `main` / `transit_trip_open`).
  final InfobusTripTimeChipTap? onTripTimeChipTap;
  final InfobusPastTripTimeChipTap? onPastTripTimeChipTap;

  @override
  State<InfobusUpcomingDeparturesBlock> createState() =>
      _InfobusUpcomingDeparturesBlockState();
}

class _InfobusUpcomingDeparturesBlockState
    extends State<InfobusUpcomingDeparturesBlock> {
  Timer? _timer;
  List<InfobusArrivalCard> _site = const [];
  bool _loading = false;
  bool _hadError = false;

  @override
  void initState() {
    super.initState();
    _hydrateSiteFromCache();
    unawaited(_tick());
    _timer = Timer.periodic(kInfobusPollInterval, (_) => _tick());
  }

  void _hydrateSiteFromCache() {
    final sid = widget.rawStopId.trim();
    final b = widget.basinLower.trim().toLowerCase();
    if (sid.isEmpty || (b != 'fc' && b != 'ra' && b != 'rn')) return;
    final cached = _arrivalsCache[_cacheKey(b, sid)];
    if (cached == null) return;
    if (DateTime.now().difference(cached.fetchedAt) >= _kArrivalsCacheTtl) {
      return;
    }
    _site = cached.cards;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InfobusUpcomingDeparturesBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawStopId != widget.rawStopId ||
        oldWidget.basinLower != widget.basinLower) {
      _site = const [];
      _hydrateSiteFromCache();
      unawaited(_tick());
    }
  }

  Future<void> _tick() async {
    final sid = widget.rawStopId.trim();
    final b = widget.basinLower.trim().toLowerCase();
    if (sid.isEmpty || (b != 'fc' && b != 'ra' && b != 'rn')) return;

    if (mounted && _site.isEmpty) setState(() => _loading = true);
    final list = await infobusFetchArrivalsForStop(basinLower: b, palina: sid);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (list == null) {
        _hadError = true;
      } else {
        _hadError = false;
        _site = list;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = computeUpcomingDeparturesUi(
      rawStopId: widget.rawStopId.trim(),
      bubbles: widget.bubbles,
      schedule: widget.schedule,
      now: DateTime.now(),
    );

    final showSite = _site.isNotEmpty;

    if (!showSite && !_loading && upcoming.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_hadError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Orari in tempo reale non disponibili.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: kRomagnaDarkGray.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                Text(
                  'Non ci sono partenze imminenti con i dati attuali.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: kRomagnaDarkGray.withValues(alpha: 0.42),
                  ),
                ),
              ],
            ),
          ),
          RecentPastDeparturesExpansion(
            rawStopId: widget.rawStopId,
            bubbles: widget.bubbles,
            schedule: widget.schedule,
            siteCards: _site,
            onPastTripTimeChipTap: widget.onPastTripTimeChipTap,
          ),
        ],
      );
    }

    final match =
        showSite
            ? const <int, InfobusArrivalCard>{}
            : matchInfobusToUpcoming(upcoming: upcoming, site: _site);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading && _site.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(
              minHeight: 2,
              borderRadius: BorderRadius.circular(2),
              color: kRomagnaPrimary.withValues(alpha: 0.65),
              backgroundColor: kRomagnaPrimary.withValues(alpha: 0.1),
            ),
          )
        else if (_hadError && _site.isEmpty && upcoming.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Orari in tempo reale non disponibili.',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: kRomagnaDarkGray.withValues(alpha: 0.38),
              ),
            ),
          ),
        if (showSite)
          for (final c in _site) _siteDepartureRow(c)
        else
          for (var i = 0; i < upcoming.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 2,
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.4,
                          color: kRomagnaDarkGray,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(text: upcoming[i].lineLabel),
                          TextSpan(
                            text: ' ${upcoming[i].secondaryLabel}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: kRomagnaDarkGray.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Text(
                      upcoming[i].towards,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaDarkGray.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _timeChipWithRt(
                    upcoming[i],
                    match[i],
                    _bubbleForLineLabel(upcoming[i].lineLabel),
                  ),
                ],
              ),
            ),
          ],
        RecentPastDeparturesExpansion(
          rawStopId: widget.rawStopId,
          bubbles: widget.bubbles,
          schedule: widget.schedule,
          siteCards: _site,
          onPastTripTimeChipTap: widget.onPastTripTimeChipTap,
        ),
      ],
    );
  }

  Widget _siteDepartureRow(InfobusArrivalCard card) {
    final lineUi = infobusSiteLineLabelForUi(card.lineLabel, widget.bubbles);
    final bubble = _bubbleForLineLabel(card.lineLabel);
    final secondary = bubble?.secondaryGrey ?? bubble?.bacinoUpper ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: kRomagnaDarkGray,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: lineUi),
                  if (secondary.isNotEmpty)
                    TextSpan(
                      text: ' $secondary',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              card.destination,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: kRomagnaDarkGray.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _infobusSiteTimeChip(card, bubble),
        ],
      ),
    );
  }

  Widget _infobusSiteTimeChip(
    InfobusArrivalCard card,
    StopTransitLineBubble? bubble,
  ) {
    final rt = infobusChipRtForCard(card);
    final tint = infobusProssimePartenzeBubbleTint(card);
    VoidCallback? onTap;
    if (widget.onTripTimeChipTap != null &&
        bubble != null &&
        bubble.scheduleRouteKeys.isNotEmpty) {
      onTap = () {
        final u = _upcomingFromInfobusCard(card, bubble);
        unawaited(widget.onTripTimeChipTap!(context, u, card, bubble));
      };
    }
    return TransitScheduleTimeChip(
      timeLabel: card.scheduledHm,
      tint: tint,
      timeTextColor: transitChipTimeTextColor(tint),
      realtimeSuffix: rt?.suffix,
      realtimeSuffixBackground: rt?.background,
      realtimeSuffixForeground: rt?.foreground,
      timeFontSize: 13.5,
      verticalPadding: 6,
      onTripTimetableTap: onTap,
    );
  }

  UpcomingTransitDepartureUi _upcomingFromInfobusCard(
    InfobusArrivalCard card,
    StopTransitLineBubble bubble,
  ) {
    final hm = _normalizeHm(card.scheduledHm);
    final parts = hm.split(':');
    final now = DateTime.now();
    var when = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return UpcomingTransitDepartureUi(
      lineLabel: infobusSiteLineLabelForUi(card.lineLabel, widget.bubbles),
      secondaryLabel: bubble.secondaryGrey ?? bubble.bacinoUpper,
      towards: card.destination,
      clockLabel: hm,
      when: when,
      dayPrefix: italianDayCue(now, when),
    );
  }

  StopTransitLineBubble? _bubbleForLineLabel(String lineLabel) {
    for (final b in widget.bubbles) {
      if (infobusSiteLineMatchesBubbleLine(lineLabel, b.lineaLabel)) {
        return b;
      }
    }
    return null;
  }

  Widget _timeChipWithRt(
    UpcomingTransitDepartureUi u,
    InfobusArrivalCard? m,
    StopTransitLineBubble? bubble,
  ) {
    final rt = m != null ? infobusChipRtForCard(m) : null;
    final tint =
        m == null ? kRomagnaPrimary : infobusProssimePartenzeBubbleTint(m);
    final onTap =
        widget.onTripTimeChipTap != null &&
                bubble != null &&
                bubble.scheduleRouteKeys.isNotEmpty
            ? () => unawaited(
              widget.onTripTimeChipTap!(context, u, m, bubble),
            )
            : null;
    return TransitScheduleTimeChip(
      timeLabel:
          u.dayPrefix.isEmpty ? u.clockLabel : '${u.dayPrefix}${u.clockLabel}',
      tint: tint,
      timeTextColor: transitChipTimeTextColor(tint),
      isPrenotazione: u.isPrenotazione,
      realtimeSuffix: rt?.suffix,
      realtimeSuffixBackground: rt?.background,
      realtimeSuffixForeground: rt?.foreground,
      timeFontSize: 13.5,
      verticalPadding: 6,
      onTripTimetableTap: onTap,
    );
  }
}

/// Sezione espandibile « Partenze precedenti » (max 3, ultimi 30 min da partenza effettiva).
class RecentPastDeparturesExpansion extends StatefulWidget {
  const RecentPastDeparturesExpansion({
    super.key,
    required this.rawStopId,
    required this.bubbles,
    required this.schedule,
    this.siteCards = const [],
    this.onPastTripTimeChipTap,
  });

  final String rawStopId;
  final List<StopTransitLineBubble> bubbles;
  final StopTransitScheduleIndex schedule;
  final List<InfobusArrivalCard> siteCards;
  final InfobusPastTripTimeChipTap? onPastTripTimeChipTap;

  @override
  State<RecentPastDeparturesExpansion> createState() =>
      _RecentPastDeparturesExpansionState();
}

class _RecentPastDeparturesExpansionState
    extends State<RecentPastDeparturesExpansion> {
  bool _expanded = false;

  static final _titleStyle = GoogleFonts.inter(
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: kRomagnaDarkGray.withValues(alpha: 0.5),
    letterSpacing: 0.2,
  );

  @override
  Widget build(BuildContext context) {
    final past =
        _expanded
            ? computeRecentPastDeparturesUi(
              rawStopId: widget.rawStopId,
              bubbles: widget.bubbles,
              schedule: widget.schedule,
              siteCards: widget.siteCards,
            )
            : const <RecentPastDepartureUi>[];

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text('Partenze precedenti', style: _titleStyle)),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                      color: kRomagnaPrimary.withValues(alpha: 0.78),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            if (past.isEmpty)
              Text(
                'Nessuna partenza recente da mostrare',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.45,
                  color: kRomagnaDarkGray.withValues(alpha: 0.42),
                ),
              )
            else
              for (final p in past) _pastRow(context, p),
          ],
        ],
      ),
    );
  }

  Widget _pastRow(BuildContext context, RecentPastDepartureUi p) {
    final u = p.departure;
    final card = p.infobusCard;
    final rt = card != null ? infobusChipRtForCard(card) : null;
    final tint =
        card != null
            ? infobusProssimePartenzeBubbleTint(card)
            : kRomagnaDarkGray.withValues(alpha: 0.55);
    final bubble = p.bubble;
    VoidCallback? onTap;
    if (widget.onPastTripTimeChipTap != null &&
        bubble.scheduleRouteKeys.isNotEmpty) {
      onTap =
          () => unawaited(
            widget.onPastTripTimeChipTap!(context, p, bubble),
          );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: kRomagnaDarkGray,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(text: u.lineLabel),
                  TextSpan(
                    text: ' ${u.secondaryLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaDarkGray.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              u.towards,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: kRomagnaDarkGray.withValues(alpha: 0.82),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TransitScheduleTimeChip(
            timeLabel: p.effectiveClockLabel,
            tint: tint,
            timeTextColor: transitChipTimeTextColor(tint),
            realtimeSuffix: rt?.suffix,
            realtimeSuffixBackground: rt?.background,
            realtimeSuffixForeground: rt?.foreground,
            isPrenotazione: u.isPrenotazione,
            timeFontSize: 13.5,
            verticalPadding: 6,
            onTripTimetableTap: onTap,
          ),
        ],
      ),
    );
  }
}

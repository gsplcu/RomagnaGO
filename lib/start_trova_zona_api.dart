// API «Trova zona / tariffa» come su startromagna.it/trova-zona-3/ (admin-ajax).

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;

import 'start_trova_zona_cache_accessor_stub.dart'
    if (dart.library.html) 'start_trova_zona_cache_accessor_web.dart';
import 'start_trova_zona_platform_stub.dart'
    if (dart.library.io) 'start_trova_zona_platform_io.dart'
    if (dart.library.html) 'start_trova_zona_platform_web.dart';
import 'start_trova_zona_prezzi_local.dart';

const String kStartTrovaZonaPageUrl = 'https://www.startromagna.it/trova-zona-3/';
const String kStartRomagnaAjaxUrl =
    'https://www.startromagna.it/wp-admin/admin-ajax.php';

Map<String, String> get kStartTrovaZonaHeaders => const {
  'User-Agent': 'RomagnaGO/1.0 (+https://startromagna.it)',
  'Referer': kStartTrovaZonaPageUrl,
};

/// Bacino come sul sito: `data-id-bacino` per le chiamate AJAX.
enum TrovaZonaBacino {
  fc(4, 'select_trova_zona_fc', 'Forlì-Cesena'),
  ra(5, 'select_trova_zona_ra', 'Ravenna'),
  rn(6, 'select_trova_zona_rn', 'Rimini');

  const TrovaZonaBacino(this.ajaxId, this.selectElementId, this.label);

  final int ajaxId;
  final String selectElementId;
  final String label;
}

class TrovaZonaOption {
  const TrovaZonaOption({required this.code, required this.label});

  final String code;
  final String label;
}

class TrovaZonaPrezzoRow {
  const TrovaZonaPrezzoRow({
    required this.descrizione,
    required this.validita,
    required this.prezzo,
    this.infoUrl,
  });

  final String descrizione;
  final String validita;
  final String prezzo;
  final Uri? infoUrl;
}

class TrovaZonaPrezziResult {
  const TrovaZonaPrezziResult({
    required this.zoneAttraversate,
    required this.righe,
  });

  final int zoneAttraversate;
  final List<TrovaZonaPrezzoRow> righe;

  bool get hasRows => righe.isNotEmpty;
}

class TrovaZonaNessunRisultato implements Exception {
  TrovaZonaNessunRisultato(this.messaggio);
  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Dati Trova Zona da asset (Flutter Web).
class TrovaZonaOfflineData {
  const TrovaZonaOfflineData({
    required this.partenze,
    required this.arrivi,
    required this.zonePairs,
  });

  final Map<TrovaZonaBacino, List<TrovaZonaOption>> partenze;
  final Map<TrovaZonaBacino, Map<String, List<TrovaZonaOption>>> arrivi;
  final Map<TrovaZonaBacino, Map<String, int>> zonePairs;

  int? zoneCount(TrovaZonaBacino bacino, String partenza, String arrivo) {
    return zonePairs[bacino]?['$partenza-$arrivo'];
  }
}

String decodeHtmlEntitiesMinimal(String input) {
  var s = input;
  s = s.replaceAll('&nbsp;', ' ');
  s = s.replaceAll('&amp;', '&');
  s = s.replaceAll('&lt;', '<');
  s = s.replaceAll('&gt;', '>');
  s = s.replaceAll('&quot;', '"');
  s = s.replaceAll('&apos;', "'");
  s = s.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );
  s = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );
  return s;
}

List<TrovaZonaOption> _parseOptionElements(Iterable<dom.Element> options) {
  final out = <TrovaZonaOption>[];
  for (final o in options) {
    final rawVal = (o.attributes['value'] ?? '').trim();
    if (rawVal.isEmpty || !RegExp(r'^\d+$').hasMatch(rawVal)) continue;
    final label = decodeHtmlEntitiesMinimal(
      o.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    if (label.isEmpty) continue;
    out.add(TrovaZonaOption(code: rawVal, label: label));
  }
  return out;
}

/// Estrae le tre liste «zona di partenza» dalla pagina HTML ufficiale.
Map<TrovaZonaBacino, List<TrovaZonaOption>> parseZonePartenzaFromPage(
  String html,
) {
  final doc = parse(html);
  final map = <TrovaZonaBacino, List<TrovaZonaOption>>{};
  for (final b in TrovaZonaBacino.values) {
    final sel = doc.querySelector('#${b.selectElementId}');
    if (sel == null) {
      map[b] = [];
      continue;
    }
    map[b] = _parseOptionElements(sel.querySelectorAll('option'));
  }
  return map;
}

List<TrovaZonaOption> parseArrivoOptionsFragment(String fragment) {
  final wrapped = '<select>$fragment</select>';
  final doc = parse(wrapped);
  final sel = doc.querySelector('select');
  if (sel == null) return [];
  return _parseOptionElements(sel.querySelectorAll('option'));
}

Uri? _trovaZonaInfoUrlDaAnchor(dom.Element? a) {
  if (a == null) return null;
  final href = a.attributes['href'];
  if (href == null || href.isEmpty) return null;
  if (href.startsWith('http')) return Uri.tryParse(href);
  if (href.startsWith('/')) {
    return Uri.tryParse('https://www.startromagna.it$href');
  }
  return null;
}

String _trovaZonaNormTestoCella(String s) => decodeHtmlEntitiesMinimal(
  s.replaceAll(RegExp(r'\s+'), ' ').trim(),
);

bool _trovaZonaSembraIntestazioneMacroBiglietti(String testoVisibile) {
  final l = testoVisibile.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (l.startsWith('biglietti di ')) return true;
  if (RegExp(
    r'^abbonamenti\s+mensili(\s+personali)?\b',
    caseSensitive: false,
  ).hasMatch(l)) {
    return true;
  }
  if (l == 'romagna smartpass' || l == 'romagna smart pass') return true;
  if (RegExp(r'^romagna\s+smart\s*pass$').hasMatch(l)) return true;
  // Stesso link: «Romagna SmartPass» + «SmartPass 3 giorni» (testo unico).
  if (RegExp(r'^romagna\s*smart\s*pass(\s+|$)', caseSensitive: false).hasMatch(l)) {
    return true;
  }
  return false;
}

/// Testo visibile dopo il primo `</a>` nella cella (macro spesso è l’unico link; il titolo sta dopo).
String? _testoDopoPrimaChiusuraAnchor(dom.Element td) {
  final raw = td.innerHtml;
  final i = raw.toLowerCase().indexOf('</a>');
  if (i < 0) return null;
  final tail = raw.substring(i + 4);
  final frag = parse('<div>$tail</div>').querySelector('div');
  if (frag == null) return null;
  final t = decodeHtmlEntitiesMinimal(
    frag.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
  return t.isEmpty ? null : t;
}

Uri? _trovaZonaInfoUrlPrimoAnchorNonMacro(dom.Element td) {
  for (final a in td.querySelectorAll('a')) {
    final t = _trovaZonaNormTestoCella(a.text);
    if (t.isEmpty || _trovaZonaSembraIntestazioneMacroBiglietti(t)) continue;
    return _trovaZonaInfoUrlDaAnchor(a);
  }
  return null;
}

/// Rimuove in testa le macro note ancora presenti nel testo unificato della cella.
String _stripMacroPrefissiCellaBiglietti(String s) {
  var t = s.trim();
  for (var n = 0; n < 6; n++) {
    final next = t
        .replaceFirst(
          RegExp(
            r'^abbonamenti\s+mensili(\s+personali)?\b[\s.:]*',
            caseSensitive: false,
          ),
          '',
        )
        .replaceFirst(
          RegExp(r'^biglietti di corsa semplice[\s.:]*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^romagna\s*smart\s*pass\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^biglietti di\s+', caseSensitive: false),
          '',
        )
        .trim();
    if (next == t) break;
    t = next;
  }
  return t.trim();
}

/// Prima colonna tabella sito: macro (spesso un solo [a]) + titolo vero (secondo [a] o testo dopo `</a>`).
({String descrizione, Uri? infoUrl}) _parseCellaBigliettoTrovaZona(dom.Element td) {
  final anchors = td.querySelectorAll('a');

  // Stesso <a> può contenere macro + titolo (es. <br> nel mezzo): il testo unito inizia ancora con «Biglietti di…».
  for (final a in anchors.reversed) {
    final full = _trovaZonaNormTestoCella(a.text);
    if (full.isEmpty) continue;
    if (_trovaZonaSembraIntestazioneMacroBiglietti(full)) {
      final stripped = _stripMacroPrefissiCellaBiglietti(full);
      if (stripped.isNotEmpty &&
          stripped != full &&
          !_trovaZonaSembraIntestazioneMacroBiglietti(stripped)) {
        return (descrizione: stripped, infoUrl: _trovaZonaInfoUrlDaAnchor(a));
      }
    }
  }

  final nonMacro = <dom.Element>[];
  for (final a in anchors) {
    final t = _trovaZonaNormTestoCella(a.text);
    if (t.isEmpty) continue;
    if (!_trovaZonaSembraIntestazioneMacroBiglietti(t)) {
      nonMacro.add(a);
    }
  }

  if (nonMacro.isNotEmpty) {
    final pick = nonMacro.last;
    final t = _trovaZonaNormTestoCella(pick.text);
    return (descrizione: t, infoUrl: _trovaZonaInfoUrlDaAnchor(pick));
  }

  final dopoAnchor = _testoDopoPrimaChiusuraAnchor(td);
  if (dopoAnchor != null &&
      !_trovaZonaSembraIntestazioneMacroBiglietti(dopoAnchor)) {
    return (
      descrizione: dopoAnchor,
      infoUrl:
          _trovaZonaInfoUrlPrimoAnchorNonMacro(td) ??
          (anchors.isNotEmpty ? _trovaZonaInfoUrlDaAnchor(anchors.first) : null),
    );
  }

  for (final strong in td.querySelectorAll('strong').reversed) {
    final t = decodeHtmlEntitiesMinimal(
      strong.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    if (t.isEmpty || _trovaZonaSembraIntestazioneMacroBiglietti(t)) {
      continue;
    }
    return (
      descrizione: t,
      infoUrl:
          _trovaZonaInfoUrlPrimoAnchorNonMacro(td) ??
          _trovaZonaInfoUrlDaAnchor(td.querySelector('a')),
    );
  }

  var plain = decodeHtmlEntitiesMinimal(
    td.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
  plain = _stripMacroPrefissiCellaBiglietti(plain);
  if (_trovaZonaSembraIntestazioneMacroBiglietti(plain)) {
    plain = '';
  }
  return (
    descrizione: plain,
    infoUrl:
        _trovaZonaInfoUrlPrimoAnchorNonMacro(td) ??
        _trovaZonaInfoUrlDaAnchor(td.querySelector('a')),
  );
}

TrovaZonaPrezziResult parseZonePrezziHtml(String body) {
  final doc = parse(body);
  for (final h in doc.querySelectorAll('h3')) {
    final t = decodeHtmlEntitiesMinimal(
      h.text.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
    if (t.toLowerCase().contains('nessun risultato')) {
      throw TrovaZonaNessunRisultato(t);
    }
    final m = RegExp(
      r'zone\s+attraversate\s*:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(t);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      final rows = <TrovaZonaPrezzoRow>[];
      final table = doc.querySelector('table.table_zone');
      if (table != null) {
        for (final tr in table.querySelectorAll('tr')) {
          if (tr.querySelector('th') != null) continue;
          final tds = tr.querySelectorAll('td');
          if (tds.length < 3) continue;
          final cella = _parseCellaBigliettoTrovaZona(tds[0]);
          final desc = cella.descrizione;
          final validita = decodeHtmlEntitiesMinimal(
            tds[1].text.replaceAll(RegExp(r'\s+'), ' ').trim(),
          );
          final prezzo = decodeHtmlEntitiesMinimal(
            tds[2].text.replaceAll(RegExp(r'\s+'), ' ').trim(),
          );
          if (desc.isNotEmpty) {
            rows.add(
              TrovaZonaPrezzoRow(
                descrizione: desc,
                validita: validita,
                prezzo: prezzo,
                infoUrl: cella.infoUrl,
              ),
            );
          }
        }
      }
      return TrovaZonaPrezziResult(zoneAttraversate: n, righe: rows);
    }
  }
  throw FormatException('Risposta Trova Zona non riconosciuta', body);
}

Future<Map<TrovaZonaBacino, List<TrovaZonaOption>>> fetchTrovaZonaPartenze({
  http.Client? client,
}) async {
  if (trovaZonaPreferOfflineCache) {
    final cache = await tryLoadTrovaZonaCache();
    if (cache != null) {
      return Map<TrovaZonaBacino, List<TrovaZonaOption>>.from(cache.partenze);
    }
  }

  final c = client ?? http.Client();
  final ownClient = client == null;
  try {
    final res = await c.get(
      Uri.parse(kStartTrovaZonaPageUrl),
      headers: kStartTrovaZonaHeaders,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TrovaZonaHttpException(
        'Pagina Trova Zona: HTTP ${res.statusCode}',
        res.statusCode,
      );
    }
    return parseZonePartenzaFromPage(res.body);
  } catch (e) {
    if (!trovaZonaPreferOfflineCache) rethrow;
    final cache = await tryLoadTrovaZonaCache();
    if (cache == null) rethrow;
    return Map<TrovaZonaBacino, List<TrovaZonaOption>>.from(cache.partenze);
  } finally {
    if (ownClient) c.close();
  }
}

Future<List<TrovaZonaOption>> fetchZoneArrivo({
  required String codicePartenza,
  required TrovaZonaBacino bacino,
  http.Client? client,
}) async {
  if (trovaZonaPreferOfflineCache) {
    final cache = await tryLoadTrovaZonaCache();
    final list = cache?.arrivi[bacino]?[codicePartenza];
    if (list != null && list.isNotEmpty) return list;
  }

  final c = client ?? http.Client();
  final ownClient = client == null;
  try {
    final uri = Uri.parse(kStartRomagnaAjaxUrl).replace(
      queryParameters: {
        'action': 'gat_zone_da_zona',
        'codice': codicePartenza,
        'bacino': '${bacino.ajaxId}',
      },
    );
    final res = await c.get(uri, headers: kStartTrovaZonaHeaders);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TrovaZonaHttpException(
        'Zone arrivo: HTTP ${res.statusCode}',
        res.statusCode,
      );
    }
    return parseArrivoOptionsFragment(res.body);
  } catch (e) {
    if (!trovaZonaPreferOfflineCache) rethrow;
    final cache = await tryLoadTrovaZonaCache();
    return cache?.arrivi[bacino]?[codicePartenza] ?? [];
  } finally {
    if (ownClient) c.close();
  }
}

Future<TrovaZonaPrezziResult> fetchZonePrezzi({
  required String partenza,
  required String arrivo,
  required TrovaZonaBacino bacino,
  http.Client? client,
}) async {
  if (trovaZonaPreferOfflineCache) {
    final cache = await tryLoadTrovaZonaCache();
    final z = cache?.zoneCount(bacino, partenza, arrivo);
    if (z != null) return buildTrovaZonaPrezziLocal(z);
  }

  final c = client ?? http.Client();
  final ownClient = client == null;
  try {
    final res = await c.post(
      Uri.parse(kStartRomagnaAjaxUrl),
      headers: {
        ...kStartTrovaZonaHeaders,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      },
      body:
          'action=get_zone_prezzi&partenza=${Uri.encodeQueryComponent(partenza)}'
          '&arrivo=${Uri.encodeQueryComponent(arrivo)}',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TrovaZonaHttpException(
        'Tariffa zone: HTTP ${res.statusCode}',
        res.statusCode,
      );
    }
    return parseZonePrezziHtml(res.body);
  } catch (e) {
    if (!trovaZonaPreferOfflineCache) rethrow;
    final cache = await tryLoadTrovaZonaCache();
    final z = cache?.zoneCount(bacino, partenza, arrivo);
    if (z == null) rethrow;
    return buildTrovaZonaPrezziLocal(z);
  } finally {
    if (ownClient) c.close();
  }
}

class TrovaZonaHttpException implements Exception {
  TrovaZonaHttpException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

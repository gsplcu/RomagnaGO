// Linee e percorsi: bacini da linee.json; tracciati da assets/shapes (GPX); orari da assets/data/orari.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'line_display.dart';
import 'romagna_brand.dart';
import 'avvisi_cache.dart';
import 'avvisi_page.dart';
import 'infobus_realtime.dart';

const String _kStartRomagnaAjaxUrl =
    'https://www.startromagna.it/wp-admin/admin-ajax.php';

/// Riga tappabile senza [ListTile] (evita assert ink su scaffold [ColoredBox]).
Widget _lineeInkRow({
  required VoidCallback? onTap,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
}) {
  return Material(
    color: Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class InfoBusPopupItem {
  const InfoBusPopupItem({
    required this.title,
    required this.url,
    required this.periodo,
    required this.anteprima,
  });

  final String title;
  final Uri url;
  final String periodo;
  final String anteprima;
}

/// Replica la logica di Start Romagna su "Trova linea e orari":
/// `action=get_route_id` restituisce un `post_id` Info Bus attivo per il route_id.
///
/// Può rispondere con JSON, un numero sul testo, o body vuoto. Ogni errore viene
/// isolato sul singolo tentativo così si provano tutti i candidati.
/// True se [s] è solo cifre: il backend `get_route_id` non distingue il bacino
/// su questi token (es. "1" → linea 1 di un bacino arbitrario).
bool _isBareNumericRouteToken(String s) {
  final t = s.trim();
  return t.isNotEmpty && RegExp(r'^\d+$').hasMatch(t);
}

Future<int?> fetchInfoBusPostIdForRouteId(
  String routeId, {
  String? lineLabel,
  String? basin,
  http.Client? client,
}) async {
  final key = routeId.trim();
  final c = client ?? http.Client();
  try {
    final candidates = <String>[];

    void addCandidate(String raw) {
      final v = raw.trim();
      if (v.isEmpty) return;
      if (!candidates.contains(v)) candidates.add(v);
    }

    final basinU = (basin ?? '').trim().toUpperCase();
    final label = (lineLabel ?? '').trim();
    final lineHasVariants = label.contains('/');

    // Come in UI sito tipo "94/94A FC" (label + bacino).
    if (label.isNotEmpty && basinU.isNotEmpty) {
      addCandidate('$label $basinU');
      addCandidate('$label $basin'); // casing originario
    }

    // route_id GTFS (es. 1CO, CE01, S094) prima del solo numero di linea:
    // altrimenti "1" può risolversi sulla linea 1 di un altro bacino (es. 1RA).
    addCandidate(key);

    if (label.isNotEmpty) {
      final skipBareNumericLabel =
          basinU.isNotEmpty && _isBareNumericRouteToken(label);
      if (!skipBareNumericLabel) {
        addCandidate(label);
      }
    }

    if (label.isNotEmpty) {
      final compact = label.replaceAll(RegExp(r'\s+'), '');
      final normalizedLabel = compact.replaceAll(RegExp(r'[^A-Za-z0-9/]'), '');
      final splitParts = normalizedLabel.split('/').map((e) => e.trim()).where(
            (e) => e.isNotEmpty,
          );
      for (final p in splitParts) {
        if (basinU.isNotEmpty) {
          addCandidate('$p $basinU');
          addCandidate('$p $basin');
        }
        final skipBarePart =
            basinU.isNotEmpty && _isBareNumericRouteToken(p);
        if (!skipBarePart) {
          addCandidate(p);
        }
      }
    }

    // Fallback da route_id suburbana tipo "S094" → numero senza rimuovere zeri prima.
    final routeDigits = key.replaceAll(RegExp(r'^[A-Za-z]+'), '').trim();

    /// Il solo numero (es. "94") sulla rete collide tra bacini (es. RN 94 ≠ FC).
    /// Si usa solo quando la label non raggruppa più varianti (no `/`).
    /// Con bacino noto si evita: si usano già "N FC" e il route_id completo.
    final mayUseBareRouteNumber = basinU.isEmpty &&
        routeDigits.isNotEmpty &&
        !lineHasVariants;
    if (mayUseBareRouteNumber) {
      addCandidate(routeDigits);
      final asInt = int.tryParse(routeDigits);
      if (asInt != null) addCandidate('$asInt');
    }

    for (final candidate in candidates) {
      try {
        final postId = await _fetchInfoBusPostIdRaw(candidate, c);
        if (postId != null && postId > 0) return postId;
      } catch (_) {
        continue;
      }
    }
    return null;
  } finally {
    if (client == null) c.close();
  }
}

Future<int?> _fetchInfoBusPostIdRaw(String routeKey, http.Client c) async {
  final res = await c.post(
    Uri.parse(_kStartRomagnaAjaxUrl),
    headers: const {
      'Accept': 'application/json, text/plain, */*',
      // Alcune risposte (es. ID numerico) risultano più coerenti con UA da browser.
      'User-Agent': 'Mozilla/5.0 (compatible; RomagnaGO/1.0; infobus route lookup)',
      'Referer': 'https://www.startromagna.it/',
    },
    body: {'action': 'get_route_id', 'route_id': routeKey},
  );
  if (res.statusCode < 200 || res.statusCode >= 300) return null;

  final text = res.body.trim();
  if (text.isEmpty || text.toLowerCase() == 'null' || text == '0') {
    return null;
  }

  final plain = int.tryParse(text);
  if (plain != null && plain > 0) return plain;

  try {
    final dynamic decoded = json.decode(text);

    dynamic rawId;
    if (decoded is Map<String, dynamic>) {
      if (decoded['success'] == true) {
        final d = decoded['data'];
        if (d is Map<String, dynamic>) {
          rawId = d['post_id'] ?? d['id'];
        } else {
          rawId = d;
        }
      } else {
        rawId = decoded['post_id'] ?? decoded['id'];
      }
    } else if (decoded is num) {
      rawId = decoded;
    } else if (decoded is String) {
      rawId = decoded;
    } else {
      rawId = null;
    }

    final asText = rawId?.toString().trim() ?? '';
    if (asText.isEmpty || asText == '0') return null;
    final id = int.tryParse(asText);
    if (id != null && id > 0) return id;
  } catch (_) {
    return null;
  }

  return null;
}

String _stripHtml(String s) {
  var out = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  out = out
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  out = out
      .replaceAll('&raquo;', '»')
      .replaceAll('&laquo;', '«')
      .replaceAll('&hellip;', '…')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&euro;', '€')
      .replaceAll('&apos;', "'");
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final v = int.tryParse(m.group(1)!);
    if (v == null) return m.group(0)!;
    return String.fromCharCode(v);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final v = int.tryParse(m.group(1)!, radix: 16);
    if (v == null) return m.group(0)!;
    return String.fromCharCode(v);
  });
  return out;
}

String _decodeHtmlEntities(String s) {
  var out = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&raquo;', '»')
      .replaceAll('&laquo;', '«')
      .replaceAll('&hellip;', '…')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&euro;', '€');
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final v = int.tryParse(m.group(1)!);
    if (v == null) return m.group(0)!;
    return String.fromCharCode(v);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final v = int.tryParse(m.group(1)!, radix: 16);
    if (v == null) return m.group(0)!;
    return String.fromCharCode(v);
  });
  return out;
}

String _extractArticleBodyHtml(String html) {
  final start = RegExp(
    r'<div class="mt-4 pt-2[^"]*">',
    caseSensitive: false,
  ).firstMatch(html);
  if (start == null) return html;
  var body = html.substring(start.end);
  final endMarkers = [
    RegExp(r'<h2[^>]*>\s*Documenti allegati\s*</h2>', caseSensitive: false),
    RegExp(r'<div class="border-top[^"]*">', caseSensitive: false),
    RegExp(r'Info Bus\s*→', caseSensitive: false),
  ];
  var end = body.length;
  for (final re in endMarkers) {
    final m = re.firstMatch(body);
    if (m != null && m.start < end) end = m.start;
  }
  return body.substring(0, end);
}

class _ArticleBlock {
  const _ArticleBlock.text(this.spans) : imageUrl = null;
  const _ArticleBlock.image(this.imageUrl) : spans = null;

  final List<InlineSpan>? spans;
  final Uri? imageUrl;
}

Uri? _resolveImageUrl(String rawSrc, Uri pageUrl) {
  final src = rawSrc.trim();
  if (src.isEmpty) return null;
  if (src.startsWith('data:')) return null;
  final normalized = src.startsWith('//') ? '${pageUrl.scheme}:$src' : src;
  return Uri.tryParse(pageUrl.resolve(normalized).toString());
}

List<_ArticleBlock> _articleBlocksFromHtml(String html, TextStyle base, Uri pageUrl) {
  final blocks = <_ArticleBlock>[];
  final spans = <InlineSpan>[];
  var hasVisibleText = false;
  var bold = 0;
  var italic = 0;
  var headingLevel = 0;
  var pendingNewlines = 0;
  final tokens = RegExp(
    r'<[^>]+>|[^<]+',
    caseSensitive: false,
  ).allMatches(html);

  void flushTextBlock() {
    if (!hasVisibleText) {
      spans.clear();
      pendingNewlines = 0;
      return;
    }
    blocks.add(_ArticleBlock.text(List<InlineSpan>.from(spans)));
    spans.clear();
    hasVisibleText = false;
    pendingNewlines = 0;
  }

  void pushText(String txt) {
    var t = _decodeHtmlEntities(txt).replaceAll(RegExp(r'[ \t]+'), ' ');
    if (t.trim().isEmpty) return;
    if (pendingNewlines > 0 && spans.isNotEmpty) {
      spans.add(TextSpan(text: '\n' * pendingNewlines, style: base));
      pendingNewlines = 0;
    }
    final headingSize = switch (headingLevel) {
      1 => (base.fontSize ?? 14) + 6,
      2 => (base.fontSize ?? 14) + 4,
      3 => (base.fontSize ?? 14) + 2,
      _ => null,
    };
    spans.add(
      TextSpan(
        text: t,
        style: base.copyWith(
          fontSize: headingSize,
          fontWeight:
              headingLevel > 0 || bold > 0 ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic > 0 ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
    hasVisibleText = true;
  }

  bool isOpenTag(String tok, List<String> names) => names.any(
    (n) => RegExp('^<\\s*$n(\\s|>)', caseSensitive: false).hasMatch(tok),
  );
  bool isCloseTag(String tok, List<String> names) => names.any(
    (n) => RegExp('^<\\s*/\\s*$n\\s*>', caseSensitive: false).hasMatch(tok),
  );

  for (final m in tokens) {
    final tok = m.group(0)!;
    if (!tok.startsWith('<')) {
      pushText(tok);
      continue;
    }
    final low = tok.toLowerCase();
    if (isOpenTag(low, const ['strong', 'b'])) {
      bold++;
    } else if (isCloseTag(low, const ['strong', 'b'])) {
      if (bold > 0) bold--;
    } else if (isOpenTag(low, const ['em', 'i'])) {
      italic++;
    } else if (isCloseTag(low, const ['em', 'i'])) {
      if (italic > 0) italic--;
    } else if (isOpenTag(low, const ['h1'])) {
      headingLevel = 1;
      pendingNewlines = pendingNewlines < 2 ? 2 : pendingNewlines;
    } else if (isOpenTag(low, const ['h2'])) {
      headingLevel = 2;
      pendingNewlines = pendingNewlines < 2 ? 2 : pendingNewlines;
    } else if (isOpenTag(low, const ['h3'])) {
      headingLevel = 3;
      pendingNewlines = pendingNewlines < 2 ? 2 : pendingNewlines;
    } else if (isCloseTag(low, const ['h1', 'h2', 'h3'])) {
      headingLevel = 0;
      pendingNewlines = pendingNewlines < 2 ? 2 : pendingNewlines;
    } else if (low.startsWith('<br')) {
      pendingNewlines = pendingNewlines < 1 ? 1 : pendingNewlines;
    } else if (low.startsWith('</p') ||
        low.startsWith('</div') ||
        low.startsWith('</section')) {
      pendingNewlines = pendingNewlines < 2 ? 2 : pendingNewlines;
    } else if (low.startsWith('<li')) {
      pendingNewlines = pendingNewlines < 1 ? 1 : pendingNewlines;
      pushText('• ');
    } else if (low.startsWith('</li')) {
      pendingNewlines = pendingNewlines < 1 ? 1 : pendingNewlines;
    } else if (low.startsWith('<img')) {
      final src =
          RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false)
              .firstMatch(tok)
              ?.group(1);
      final imageUrl = src == null ? null : _resolveImageUrl(src, pageUrl);
      if (imageUrl != null) {
        flushTextBlock();
        blocks.add(_ArticleBlock.image(imageUrl));
      }
    }
  }
  flushTextBlock();
  return blocks;
}

Future<List<_ArticleBlock>> fetchInfoBusDescrizione(Uri url, TextStyle base) async {
  final res = await http.get(
    url,
    headers: const {
      'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'User-Agent': 'RomagnaGO/1.0 (infobus detail linee)',
    },
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('HTTP ${res.statusCode}');
  }
  final articleHtml = _extractArticleBodyHtml(res.body);
  return _articleBlocksFromHtml(articleHtml, base, url);
}

List<InfoBusPopupItem> parseInfoBusLineaPopupHtml(String html) {
  final out = <InfoBusPopupItem>[];
  final blocks = RegExp(
    r'<div\s+class="news_list[^"]*"[\s\S]*?<a\s+href="(https://www\.startromagna\.it/infobus/[^"]+)"[\s\S]*?<strong>([\s\S]*?)</strong>[\s\S]*?<small>([\s\S]*?)</small>[\s\S]*?<div\s+class="black[^"]*"[^>]*>([\s\S]*?)</div>',
    caseSensitive: false,
  ).allMatches(html);
  for (final m in blocks) {
    final href = (m.group(1) ?? '').trim();
    if (href.isEmpty) continue;
    final url = Uri.tryParse(href);
    if (url == null || !url.hasScheme) continue;
    final title = _stripHtml(m.group(2) ?? '');
    if (title.isEmpty) continue;
    final periodo = _stripHtml(m.group(3) ?? '');
    final body = _stripHtml(m.group(4) ?? '');
    final anteprima =
        body.replaceAll(RegExp(r'\s*Leggi\s*$', caseSensitive: false), '').trim();
    out.add(
      InfoBusPopupItem(
        title: title,
        url: url,
        periodo: periodo,
        anteprima: anteprima,
      ),
    );
  }
  return out;
}

Future<List<InfoBusPopupItem>> fetchInfoBusPopupItemsForPostId(
  int postId, {
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final res = await c.post(
      Uri.parse(_kStartRomagnaAjaxUrl),
      headers: const {
        'Accept': 'text/html, */*',
        'User-Agent': 'RomagnaGO/1.0 (trova-linea infobus popup)',
      },
      body: {'action': 'get_infobus_linea', 'idPost': '$postId'},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return parseInfoBusLineaPopupHtml(res.body);
  } finally {
    if (client == null) c.close();
  }
}

InfoBusPopupItem infobusAvvisoToPopupItem(InfobusAvviso avviso) {
  return InfoBusPopupItem(
    title: avviso.titolo,
    url: avviso.url,
    periodo: avviso.periodo,
    anteprima: avviso.anteprima,
  );
}

Future<List<InfoBusPopupItem>> _infoBusPopupItemsFromListingFallback({
  required String lineLabel,
  required String routeId,
  required String basin,
  Duration avvisiMaxAge = const Duration(hours: 1),
}) async {
  final all = await fetchInfobusAvvisiCached(maxAge: avvisiMaxAge);
  final catalogBundle = await loadAvvisiLineCatalogBundle();
  final basinU = basin.trim().toUpperCase();
  return all
      .where(
        (a) => infobusAvvisoMatchesLineLabel(
          a.lineeInteressate,
          lineLabel,
          avvisoBasins: a.bacini,
          requiredBasin: basinU,
          catalog: catalogBundle.catalog,
          avvisoLocalityHint: a.localityHint,
          filterRouteId: routeId,
        ),
      )
      .map(infobusAvvisoToPopupItem)
      .toList();
}

/// Avvisi attivi per linea: API Info Bus del sito, con fallback su elenco InfoBus filtrato.
Future<List<InfoBusPopupItem>> fetchInfoBusItemsForLine({
  required String routeId,
  required String lineLabel,
  required String basin,
  Duration avvisiMaxAge = const Duration(hours: 1),
}) async {
  final postId = await fetchInfoBusPostIdForRouteId(
    routeId,
    lineLabel: lineLabel,
    basin: basin,
  );
  if (postId != null) {
    try {
      final popup = await fetchInfoBusPopupItemsForPostId(postId);
      if (popup.isNotEmpty) return popup;
    } catch (_) {
      // Fallback sotto (route suburbane non mappate dall’API).
    }
  }
  return _infoBusPopupItemsFromListingFallback(
    lineLabel: lineLabel,
    routeId: routeId,
    basin: basin,
    avvisiMaxAge: avvisiMaxAge,
  );
}

Future<bool> infoBusHasAvvisiForLine({
  required String routeId,
  required String lineLabel,
  required String basin,
  Duration avvisiMaxAge = const Duration(hours: 1),
}) async {
  final items = await fetchInfoBusItemsForLine(
    routeId: routeId,
    lineLabel: lineLabel,
    basin: basin,
    avvisiMaxAge: avvisiMaxAge,
  );
  return items.isNotEmpty;
}

/// Riga da [assets/data/linee.json].
class RomagnaLineaRow {
  const RomagnaLineaRow({
    required this.linea,
    required this.bacino,
    required this.area,
    required this.routeId,
  });

  final String linea;
  final String bacino;
  final String area;
  final String routeId;

  static RomagnaLineaRow? fromJsonMap(Map<String, dynamic> m) {
    final linea = m['linea']?.toString();
    final bacino = m['bacino']?.toString();
    final area = m['area']?.toString();
    final routeId = m['route_id']?.toString();
    if (linea == null ||
        bacino == null ||
        area == null ||
        routeId == null ||
        linea.isEmpty ||
        bacino.isEmpty ||
        routeId.isEmpty) {
      return null;
    }
    return RomagnaLineaRow(
      linea: linea,
      bacino: bacino.toUpperCase(),
      area: area,
      routeId: routeId,
    );
  }
}

Future<List<RomagnaLineaRow>> loadLineeCatalog() async {
  final cached = _cachedLineeCatalog;
  if (cached != null) return cached;
  return _loadingLineeCatalog ??= _loadLineeCatalogInternal().then((rows) {
    _cachedLineeCatalog = rows;
    return rows;
  });
}

List<RomagnaLineaRow>? _cachedLineeCatalog;
Future<List<RomagnaLineaRow>>? _loadingLineeCatalog;

Future<List<RomagnaLineaRow>> _loadLineeCatalogInternal() async {
  final raw = await rootBundle.loadString('assets/data/linee.json');
  final decoded = json.decode(raw) as Map<String, dynamic>;
  final list = decoded['linee'] as List<dynamic>? ?? const [];
  final out = <RomagnaLineaRow>[];
  for (final e in list) {
    if (e is Map<String, dynamic>) {
      final row = RomagnaLineaRow.fromJsonMap(e);
      if (row != null) out.add(row);
    }
  }
  return out;
}

int _compareLineaLabel(String a, String b) => compareRomagnaLineLabels(a, b);

/// Bacini in ordine di visualizzazione in «Linee e percorsi».
const List<String> kBaciniOrdine = ['CE', 'CO', 'FC', 'FO', 'RA', 'RN'];

String bacinoTitolo(String codice) {
  switch (codice) {
    case 'CE':
      return 'Cesena (CE)';
    case 'CO':
      return 'Cesenatico (CO)';
    case 'FC':
      return 'Forlì-Cesena (FC)';
    case 'FO':
      return 'Forlì (FO)';
    case 'RA':
      return 'Ravenna (RA)';
    case 'RN':
      return 'Rimini (RN)';
    default:
      return codice;
  }
}

Map<String, List<RomagnaLineaRow>> groupLineeByBacino(List<RomagnaLineaRow> all) {
  final map = <String, List<RomagnaLineaRow>>{};
  for (final r in all) {
    map.putIfAbsent(r.bacino, () => []).add(r);
  }
  for (final e in map.entries) {
    e.value.sort((a, b) => _compareLineaLabel(a.linea, b.linea));
  }
  return map;
}

String shapesFolderPrefix(String bacino, String routeId) {
  return 'assets/shapes/${bacino.toLowerCase()}/route_$routeId/';
}

Future<List<String>> listGpxAssetsForRoute(String bacino, String routeId) async {
  final prefix = shapesFolderPrefix(bacino, routeId);
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final keys = manifest.listAssets();
  final gpx =
      keys
          .where((k) => k.startsWith(prefix) && k.toLowerCase().endsWith('.gpx'))
          .toList()
        ..sort();
  return gpx;
}

String _decodeXmlText(String s) {
  return s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
}

/// Direzione da un file GPX (titolo dal tag `<name>… [id]</name>`; orari da JSON orari_*).
class LineaShapeDirection {
  const LineaShapeDirection({
    required this.label,
    required this.gpxAsset,
    this.orariPartenze,
  });

  final String label;
  final String gpxAsset;

  /// Es. «Partenze: 06:20, 07:00, …» da [assets/data/orari], null se assente o non associabile.
  final String? orariPartenze;
}

/// Legge `shape_id` e etichetta dal tag `<name>… [id]</name>` in testa al GPX.
({String? shapeId, String? label}) parseGpxTrackNameMeta(String gpxHead) {
  final m = RegExp(
    r'<name>([^<]+)\s*\[(\d+)\]\s*</name>',
    caseSensitive: false,
  ).firstMatch(gpxHead);
  if (m == null) return (shapeId: null, label: null);
  final lab = _decodeXmlText(m.group(1)!.trim());
  final sid = m.group(2);
  return (shapeId: sid, label: lab.isEmpty ? null : lab);
}

Future<String> _loadAssetHeadUtf8(String assetPath, int maxBytes) async {
  final bd = await rootBundle.load(assetPath);
  final bytes = bd.buffer.asUint8List();
  final n = bytes.length < maxBytes ? bytes.length : maxBytes;
  return utf8.decode(bytes.sublist(0, n), allowMalformed: true);
}

String _labelFromGpxFileName(String assetPath) {
  final base = assetPath.split('/').last;
  if (base.toLowerCase().endsWith('.gpx')) {
    return base.substring(0, base.length - 4).replaceAll('_', ' ');
  }
  return base;
}

String _normalizeDirezioneLabel(String s) {
  var t = _decodeXmlText(s.trim());
  t = t.replaceAll(RegExp(r'\s*\[\d+\]\s*$'), '');
  t = t.replaceAll('->', '>').replaceAll('→', '>').replaceAll('—', '-');
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.toLowerCase().trim();
}

/// Orari da `assets/data/orari/{fc|ra|rn}/orari_{routeId}.json`.
Future<List<Map<String, dynamic>>> loadOrariDirezioni(RomagnaLineaRow r) async {
  final path =
      'assets/data/orari/${openDataAssetBacino(r).toLowerCase()}/orari_${r.routeId}.json';
  try {
    final raw = await rootBundle.loadString(path);
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['direzioni_orari'];
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  } catch (_) {
    return const [];
  }
}

/// Estrae blocchi `1318-1410` o `0735` dal nome file `..._1318-1410__726651438.gpx`.
List<String> _timesFromGpxBasename(String assetPath) {
  final base = assetPath.split('/').last;
  final m = RegExp(r'_(\d{4}(?:-\d{4})*)__(?:\d+)\.gpx$', caseSensitive: false).firstMatch(base);
  if (m == null) return const [];
  final chunk = m.group(1)!;
  final out = <String>[];
  for (final four in chunk.split('-')) {
    if (four.length != 4 || !RegExp(r'^\d{4}$').hasMatch(four)) continue;
    final h = int.tryParse(four.substring(0, 2));
    final mi = int.tryParse(four.substring(2, 4));
    if (h == null || mi == null || h > 23 || mi > 59) continue;
    out.add('${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}:00');
  }
  return out;
}

String _normTimeKey(String raw) {
  final p = raw.trim();
  final seg = p.split(':');
  if (seg.length >= 2) {
    final h = int.tryParse(seg[0]) ?? 0;
    final m = int.tryParse(seg[1]) ?? 0;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  return p;
}

Set<String> _timeKeysFromOrariList(List<dynamic> raw) {
  return raw.map((e) => _normTimeKey(e.toString())).toSet();
}

String _formatOrariPartenze(List<dynamic> orari) {
  if (orari.isEmpty) return '';
  final parts = <String>[];
  for (final e in orari) {
    final s = e.toString();
    if (s.length >= 5 && s.contains(':')) {
      parts.add(s.length >= 8 ? s.substring(0, 5) : s);
    }
  }
  return 'Partenze: ${parts.join(', ')}';
}

int _tripCount(Map<String, dynamic> b) {
  final v = b['trip_count'];
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

/// Abbina una variante GPX a una voce in `direzioni_orari` (stessi capolinea / stessa etichetta percorso).
String? _pickOrariSubtitle({
  required List<Map<String, dynamic>> blocks,
  required String gpxLabel,
  required String gpxPath,
}) {
  if (blocks.isEmpty) return null;
  final norm = _normalizeDirezioneLabel(gpxLabel);
  final candidates =
      blocks.where((b) {
        final dp = b['direzione_percorso']?.toString() ?? '';
        return _normalizeDirezioneLabel(dp) == norm;
      }).toList();
  if (candidates.isEmpty) return null;

  final sig = _timesFromGpxBasename(gpxPath);
  if (sig.isNotEmpty) {
    final sigSet = sig.map(_normTimeKey).toSet();
    for (final c in candidates) {
      final op = c['orari_partenza'] as List? ?? const [];
      final keys = _timeKeysFromOrariList(op);
      if (keys.length == sigSet.length && sigSet.every(keys.contains)) {
        return _formatOrariPartenze(op);
      }
    }
    final filtered =
        candidates.where((c) {
          final keys = _timeKeysFromOrariList(c['orari_partenza'] as List? ?? const []);
          return sigSet.every(keys.contains);
        }).toList();
    if (filtered.length == 1) {
      return _formatOrariPartenze(filtered.first['orari_partenza'] as List? ?? const []);
    }
    if (filtered.isNotEmpty) {
      filtered.sort((a, b) {
        final la = (a['orari_partenza'] as List?)?.length ?? 0;
        final lb = (b['orari_partenza'] as List?)?.length ?? 0;
        return la.compareTo(lb);
      });
      return _formatOrariPartenze(filtered.first['orari_partenza'] as List? ?? const []);
    }
  }

  if (candidates.length == 1) {
    return _formatOrariPartenze(candidates.first['orari_partenza'] as List? ?? const []);
  }

  candidates.sort((a, b) => _tripCount(b).compareTo(_tripCount(a)));
  return _formatOrariPartenze(candidates.first['orari_partenza'] as List? ?? const []);
}

/// Elenco direzioni da tutti i `.gpx` della cartella della linea + orari da JSON in `assets/data/orari`.
Future<List<LineaShapeDirection>> loadShapeDirectionsForLine(RomagnaLineaRow r) async {
  final paths = await listGpxAssetsForRoute(openDataAssetBacino(r), r.routeId);
  final blocks = await loadOrariDirezioni(r);
  final out = <LineaShapeDirection>[];
  final seenShapeIds = <String>{};
  for (final p in paths) {
    try {
      final head = await _loadAssetHeadUtf8(p, 16384);
      final meta = parseGpxTrackNameMeta(head);
      final sid = meta.shapeId ?? '';
      if (sid.isNotEmpty) {
        if (seenShapeIds.contains(sid)) continue;
        seenShapeIds.add(sid);
      }
      final label = (meta.label != null && meta.label!.isNotEmpty) ? meta.label! : _labelFromGpxFileName(p);
      final orari =
          blocks.isEmpty ? null : _pickOrariSubtitle(blocks: blocks, gpxLabel: label, gpxPath: p);
      out.add(LineaShapeDirection(label: label, gpxAsset: p, orariPartenze: orari));
    } catch (_) {
      continue;
    }
  }
  out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return out;
}

List<LatLng> latLngsFromGpxString(String gpx) {
  final pts = <LatLng>[];
  final patterns = [
    RegExp(r'<trkpt\s+lat="([-0-9.eE+]+)"\s+lon="([-0-9.eE+]+)"', caseSensitive: false),
    RegExp(r'<rtept\s+lat="([-0-9.eE+]+)"\s+lon="([-0-9.eE+]+)"', caseSensitive: false),
    RegExp(r'<wpt\s+lat="([-0-9.eE+]+)"\s+lon="([-0-9.eE+]+)"', caseSensitive: false),
  ];
  for (final re in patterns) {
    for (final m in re.allMatches(gpx)) {
      final la = double.tryParse(m.group(1)!);
      final lo = double.tryParse(m.group(2)!);
      if (la == null || lo == null) continue;
      if (!la.isFinite || !lo.isFinite) continue;
      if (la.abs() > 90 || lo.abs() > 180) continue;
      pts.add(LatLng(la, lo));
    }
    if (pts.isNotEmpty) break;
  }
  return pts;
}

Future<void> shareGpxContent(String gpx, String filename) async {
  final safeName = filename.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final name = safeName.endsWith('.gpx') ? safeName : '$safeName.gpx';
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(gpx),
          name: name,
          mimeType: 'application/gpx+xml',
        ),
      ],
      subject: 'Percorso GPX',
    ),
  );
}

// -----------------------------------------------------------------------------
// Lista bacini
// -----------------------------------------------------------------------------

class LineeBaciniPage extends StatefulWidget {
  const LineeBaciniPage({super.key});

  @override
  State<LineeBaciniPage> createState() => _LineeBaciniPageState();
}

class _LineeBaciniPageState extends State<LineeBaciniPage> {
  late Future<Map<String, List<RomagnaLineaRow>>> _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      final all = await loadLineeCatalog();
      return groupLineeByBacino(all);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Linee e percorsi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: FutureBuilder<Map<String, List<RomagnaLineaRow>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
          }
          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare l\'elenco linee.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: kRomagnaDarkGray),
                ),
              ),
            );
          }
          final byBacino = snap.data!;
          return ListView(
            children: [
              for (final codice in kBaciniOrdine)
                if ((byBacino[codice] ?? const []).isNotEmpty)
                  _lineeInkRow(
                    onTap:
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder:
                                (_) => LineeElencoPage(
                                  titolo: bacinoTitolo(codice),
                                  righe: byBacino[codice]!,
                                ),
                          ),
                        ),
                    child: Row(
                      children: [
                        Icon(Icons.map_outlined, color: kRomagnaPrimary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bacinoTitolo(codice),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: kRomagnaDarkGray,
                                ),
                              ),
                              Text(
                                '${byBacino[codice]!.length} linee',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: kRomagnaDarkGray.withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: kRomagnaDarkGray.withValues(alpha: 0.45),
                        ),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Linee di un bacino
// -----------------------------------------------------------------------------

class LineeElencoPage extends StatelessWidget {
  const LineeElencoPage({super.key, required this.titolo, required this.righe});

  final String titolo;
  final List<RomagnaLineaRow> righe;

  @override
  Widget build(BuildContext context) {
    const areaGray = Color(0xFFB0B0B0);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(titolo, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView.builder(
        itemCount: righe.length,
        itemBuilder: (context, i) {
          final r = righe[i];
          return _lineeInkRow(
            onTap:
                () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => DirezioniLineaPage(riga: r),
                  ),
                ),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: r.linea,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: kRomagnaDarkGray,
                            fontSize: 16,
                          ),
                        ),
                        TextSpan(
                          text: '  ${r.area}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: areaGray,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: kRomagnaDarkGray.withValues(alpha: 0.45),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Direzioni / shape per linea (solo assets/shapes)
// -----------------------------------------------------------------------------

class DirezioniLineaPage extends StatefulWidget {
  const DirezioniLineaPage({super.key, required this.riga});

  final RomagnaLineaRow riga;

  @override
  State<DirezioniLineaPage> createState() => _DirezioniLineaPageState();
}

class _DirezioniLineaPageState extends State<DirezioniLineaPage> {
  late Future<List<LineaShapeDirection>> _future;
  bool _infoBusHasAvvisi = false;
  bool _infoBusChecked = false;

  @override
  void initState() {
    super.initState();
    _future = () async {
      try {
        return await loadShapeDirectionsForLine(widget.riga);
      } catch (e, st) {
        debugPrint('DirezioniLinea load: $e\n$st');
        rethrow;
      }
    }();
    _loadInfoBusAvailability();
  }

  Future<void> _loadInfoBusAvailability() async {
    final displayBasin = displayBasinUpper(widget.riga);
    final has = await infoBusHasAvvisiForLine(
      routeId: widget.riga.routeId,
      lineLabel: widget.riga.linea,
      basin: displayBasin,
    );
    if (!mounted) return;
    setState(() {
      _infoBusHasAvvisi = has;
      _infoBusChecked = true;
    });
  }

  Future<void> _openInfoBusPost() async {
    if (!_infoBusHasAvvisi) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => InfoBusLineaPage(
              lineLabel: widget.riga.linea,
              areaLabel: widget.riga.area,
              basin: displayBasinUpper(widget.riga),
              routeId: widget.riga.routeId,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const shapeGray = Color(0xFF9E9E9E);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Linea ${widget.riga.linea}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        actions: [
          if (_infoBusChecked)
            TextButton.icon(
              onPressed: _infoBusHasAvvisi ? _openInfoBusPost : null,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: Text(
                _infoBusHasAvvisi
                    ? 'Info Bus'
                    : 'Nessun avviso per questa linea',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: FutureBuilder<List<LineaShapeDirection>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare le direzioni.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: kRomagnaDarkGray, height: 1.35),
                ),
              ),
            );
          }
          final dirs = snap.data ?? const <LineaShapeDirection>[];
          if (dirs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nessun tracciato in assets per questa linea (cartella route_${widget.riga.routeId}).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: kRomagnaDarkGray, height: 1.35),
                ),
              ),
            );
          }
          final sortedDirs = [...dirs]
            ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  widget.riga.area,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kRomagnaDarkGray.withValues(alpha: 0.62),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Direzioni disponibili (A-Z)',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ),
              for (final d in sortedDirs)
                _lineeInkRow(
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder:
                            (_) => GpxViewerPage(
                              title: 'Linea ${widget.riga.linea}',
                              assetPath: d.gpxAsset,
                            ),
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.alt_route_rounded, color: kRomagnaPrimary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              d.label,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: kRomagnaDarkGray,
                              ),
                            ),
                            if (d.orariPartenze != null &&
                                d.orariPartenze!.trim().isNotEmpty)
                              Builder(
                                builder: (_) {
                                  final raw = d.orariPartenze!.trim();
                                  final timesPart =
                                      raw.startsWith('Partenze:')
                                          ? raw
                                              .substring('Partenze:'.length)
                                              .trim()
                                          : raw;
                                  final times =
                                      timesPart
                                          .split(',')
                                          .map((e) => e.trim())
                                          .where((e) => e.isNotEmpty)
                                          .toList();
                                  if (times.isEmpty) {
                                    return Text(
                                      raw,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: shapeGray,
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Partenze: ${times.join(' • ')}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: shapeGray,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class InfoBusLineaPage extends StatefulWidget {
  const InfoBusLineaPage({
    super.key,
    required this.lineLabel,
    required this.areaLabel,
    required this.basin,
    required this.routeId,
  });

  final String lineLabel;
  final String areaLabel;
  final String basin;
  final String routeId;

  @override
  State<InfoBusLineaPage> createState() => _InfoBusLineaPageState();
}

class _InfoBusLineaPageState extends State<InfoBusLineaPage> {
  late Future<List<InfoBusPopupItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchInfoBusItemsForLine(
      routeId: widget.routeId,
      lineLabel: widget.lineLabel,
      basin: widget.basin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Info Bus',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<InfoBusPopupItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.2));
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossibile caricare gli avvisi della linea.\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: kRomagnaDarkGray, height: 1.35),
                ),
              ),
            );
          }
          final items = snap.data ?? const <InfoBusPopupItem>[];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Nessun avviso attivo per questa linea.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: kRomagnaDarkGray, height: 1.35),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Linea ${widget.lineLabel} · ${widget.areaLabel}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaDarkGray.withValues(alpha: 0.7),
                  ),
                ),
              ),
              for (final it in items)
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap:
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => InfoBusDettaglioPage(item: it),
                          ),
                        ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                              color: kRomagnaDarkGray,
                            ),
                          ),
                          if (it.periodo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              it.periodo,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kRomagnaPrimary,
                              ),
                            ),
                          ],
                          if (it.anteprima.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              it.anteprima,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.35,
                                color: kRomagnaDarkGray.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class InfoBusDettaglioPage extends StatefulWidget {
  const InfoBusDettaglioPage({super.key, required this.item});

  final InfoBusPopupItem item;

  @override
  State<InfoBusDettaglioPage> createState() => _InfoBusDettaglioPageState();
}

class _InfoBusDettaglioPageState extends State<InfoBusDettaglioPage> {
  late Future<List<_ArticleBlock>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchInfoBusDescrizione(
      widget.item.url,
      GoogleFonts.inter(fontSize: 14, height: 1.45, color: kRomagnaDarkGray),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio avviso'),
        actions: [
          IconButton(
            onPressed:
                () => launchUrl(
                  widget.item.url,
                  mode: LaunchMode.externalApplication,
                ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<_ArticleBlock>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                widget.item.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaPrimary,
                ),
              ),
              if (widget.item.periodo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.item.periodo,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaDarkGray.withValues(alpha: 0.9),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ..._buildArticleBlocks(context, snap.data ?? const <_ArticleBlock>[]),
            ],
          );
        },
      ),
    );
  }
}

List<Widget> _buildArticleBlocks(BuildContext context, List<_ArticleBlock> blocks) {
  final out = <Widget>[];
  for (final b in blocks) {
    if (b.imageUrl != null) {
      out.add(const SizedBox(height: 10));
      out.add(_ZoomableArticleImage(url: b.imageUrl!));
      out.add(const SizedBox(height: 10));
      continue;
    }
    final spans = b.spans;
    if (spans == null || spans.isEmpty) continue;
    out.add(SelectableText.rich(TextSpan(children: spans)));
  }
  return out;
}

class _ZoomableArticleImage extends StatelessWidget {
  const _ZoomableArticleImage({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url.toString(),
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, _, __) => Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Immagine non disponibile',
            style: GoogleFonts.inter(color: kRomagnaDarkGray.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: () {
        showDialog<void>(
          context: context,
          builder:
              (_) => Dialog(
                insetPadding: const EdgeInsets.all(8),
                backgroundColor: Colors.black,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: Center(
                        child: Image.network(url.toString(), fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
      child: image,
    );
  }
}

// -----------------------------------------------------------------------------
// Visualizzatore GPX
// -----------------------------------------------------------------------------

class GpxViewerPage extends StatefulWidget {
  const GpxViewerPage({super.key, required this.title, required this.assetPath});

  final String title;
  final String assetPath;

  @override
  State<GpxViewerPage> createState() => _GpxViewerPageState();
}

class _GpxViewerPageState extends State<GpxViewerPage> {
  final MapController _mapController = MapController();
  String? _raw;
  List<LatLng> _pts = const [];
  LatLng? _userPos;
  String? _err;
  bool _loading = true;
  bool _locatingUser = false;
  double _currentZoom = 13;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(widget.assetPath);
      final pts = latLngsFromGpxString(raw);
      if (!mounted) return;
      setState(() {
        _raw = raw;
        _pts = pts;
        _err = null;
        _loading = false;
        _currentZoom = _pts.isEmpty ? 11 : 13;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pts.length < 2) return;
        try {
          final bounds = LatLngBounds.fromPoints(_pts);
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
            ),
          );
        } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _saveGpx() async {
    final raw = _raw;
    if (raw == null || raw.isEmpty) return;
    try {
      final name = widget.assetPath.split('/').last;
      await shareGpxContent(raw, name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvataggio non riuscito: $e')),
      );
    }
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom + delta).clamp(8.0, 18.0);
      _mapController.move(cam.center, nextZoom);
      setState(() => _currentZoom = nextZoom);
    } catch (_) {}
  }

  Future<void> _showMyPosition() async {
    if (_locatingUser) return;
    setState(() => _locatingUser = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('Servizi di localizzazione disattivati');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permesso posizione non concesso');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      setState(() => _userPos = point);
      final cam = _mapController.camera;
      final targetZoom = cam.zoom < 15 ? 15.0 : cam.zoom;
      _mapController.move(point, targetZoom);
      setState(() => _currentZoom = targetZoom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Posizione non disponibile: $e')));
    } finally {
      if (mounted) setState(() => _locatingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userMarkerSize = (_currentZoom * 1.1).clamp(10.0, 24.0);
    final userMarkerBorder = (userMarkerSize * 0.1).clamp(1.4, 2.6);
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        actions: [
          if (!_loading && _err == null && (_raw?.isNotEmpty ?? false))
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'save') _saveGpx();
              },
              itemBuilder:
                  (ctx) => [
                    PopupMenuItem<String>(
                      value: 'save',
                      child: Text('Salva file GPX', style: GoogleFonts.inter()),
                    ),
                  ],
            ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2))
              : _err != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _err!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: kRomagnaDarkGray, height: 1.35),
                  ),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _pts.isNotEmpty ? _pts.first : const LatLng(44.2, 12.2),
                            initialZoom: _pts.isEmpty ? 11 : 13,
                            minZoom: 8,
                            maxZoom: 18,
                            onPositionChanged: (position, _) {
                              final z = position.zoom;
                              if ((_currentZoom - z).abs() < 0.01) return;
                              setState(() => _currentZoom = z);
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'RomagnaGO',
                              maxNativeZoom: 19,
                            ),
                            if (_pts.length >= 2)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _pts,
                                    strokeWidth: 4,
                                    color: kRomagnaPrimary,
                                  ),
                                ],
                              ),
                            if (_pts.isNotEmpty || _userPos != null)
                              MarkerLayer(
                                markers: [
                                  if (_pts.isNotEmpty)
                                    Marker(
                                      point: _pts.first,
                                      width: 18,
                                      height: 18,
                                      child: const Icon(Icons.flag, color: Color(0xFF2E7D32), size: 22),
                                    ),
                                  if (_pts.length > 1)
                                    Marker(
                                      point: _pts.last,
                                      width: 18,
                                      height: 18,
                                      child: Icon(Icons.flag, color: Colors.red.shade700, size: 22),
                                    ),
                                  if (_userPos != null)
                                    Marker(
                                      point: _userPos!,
                                      width: userMarkerSize,
                                      height: userMarkerSize,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Color(0xFFFF9800),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: userMarkerBorder,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      romagnaMapAttributionChip(
                        backgroundColor: Colors.white.withValues(alpha: 0.82),
                        text: '© OpenStreetMap',
                        textStyle: GoogleFonts.inter(
                          fontSize: 9,
                          color: kRomagnaDarkGray.withValues(alpha: 0.65),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Material(
                              color: Colors.white,
                              elevation: 2,
                              borderRadius: BorderRadius.circular(10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Zoom in',
                                    onPressed: () => _zoomBy(1),
                                    icon: const Icon(Icons.add),
                                  ),
                                  const Divider(height: 1),
                                  IconButton(
                                    tooltip: 'Zoom out',
                                    onPressed: () => _zoomBy(-1),
                                    icon: const Icon(Icons.remove),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _locatingUser ? null : _showMyPosition,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(46, 46),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child:
                                  _locatingUser
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                      : const Icon(Icons.my_location_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

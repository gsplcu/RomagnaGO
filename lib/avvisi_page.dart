import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'avvisi_cache.dart';
import 'infobus_realtime.dart';
import 'romagna_brand.dart';

const String _kInfobusUrl = 'https://www.startromagna.it/infobus/';

const double _kAvvisiFilterFieldFontSize = 16;
const double _kAvvisiFilterFieldRadius = 12;
const EdgeInsets _kAvvisiFilterFieldPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 14,
);

Widget _avvisiFilterFieldShell({required Widget child}) {
  return Material(
    color: const Color(0xFFF3F3F3),
    borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

OutlineInputBorder _avvisiFilterOutlineBorder({Color? borderColor, double width = 0}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
    borderSide:
        borderColor == null || width <= 0
            ? BorderSide.none
            : BorderSide(color: borderColor, width: width),
  );
}

InputDecoration _avvisiFilterInputDecoration(
  String hintText, {
  Widget? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: false,
    isDense: true,
    contentPadding:
        prefixIcon == null
            ? _kAvvisiFilterFieldPadding
            : const EdgeInsets.symmetric(vertical: 14),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: _avvisiFilterOutlineBorder(
      borderColor: kRomagnaPrimary,
      width: 1.2,
    ),
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: _avvisiFilterOutlineBorder(
      borderColor: kRomagnaPrimary,
      width: 1.2,
    ),
    hintStyle: GoogleFonts.inter(
      fontSize: _kAvvisiFilterFieldFontSize,
      color: kRomagnaDarkGray.withValues(alpha: 0.55),
    ),
  );
}

TextStyle _avvisiFilterFieldTextStyle({Color? color}) {
  return GoogleFonts.inter(
    fontSize: _kAvvisiFilterFieldFontSize,
    color: color ?? kRomagnaDarkGray,
  );
}

const double _kAvvisiLineFilterResetSize = 48;

Widget _avvisiLineFilterResetButton({
  required bool enabled,
  required VoidCallback onPressed,
}) {
  return Material(
    color: const Color(0xFFF3F3F3),
    borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
    child: InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
      child: SizedBox(
        width: _kAvvisiLineFilterResetSize,
        height: _kAvvisiLineFilterResetSize,
        child: Icon(
          Icons.close_rounded,
          size: 22,
          color:
              enabled
                  ? kRomagnaDarkGray.withValues(alpha: 0.72)
                  : kRomagnaDarkGray.withValues(alpha: 0.28),
        ),
      ),
    ),
  );
}

Widget _avvisiLineFilterRow({
  required Widget dropdown,
  required bool resetEnabled,
  required VoidCallback onReset,
}) {
  return Row(
    children: [
      Expanded(child: dropdown),
      const SizedBox(width: 8),
      _avvisiLineFilterResetButton(enabled: resetEnabled, onPressed: onReset),
    ],
  );
}

Widget _avvisiLineFilterDropdown({
  required BuildContext context,
  required double width,
  required String hintText,
  required String selectedRouteId,
  required List<AvvisiLineFilterOption> options,
  required bool enabled,
  required ValueChanged<String> onSelectedRouteId,
}) {
  final lineItemStyle = _avvisiFilterFieldTextStyle();
  final isPlaceholder = selectedRouteId.isEmpty;
  AvvisiLineFilterOption? selectedOption;
  for (final opt in options) {
    if (opt.routeId == selectedRouteId) {
      selectedOption = opt;
      break;
    }
  }
  final displayText =
      isPlaceholder ? hintText : (selectedOption?.displayLabel ?? hintText);

  Future<void> openPicker() async {
    if (!enabled || options.isEmpty) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
            itemCount: options.length,
            itemBuilder: (sheetContext, index) {
              final opt = options[index];
              final selected = opt.routeId == selectedRouteId;
              return Material(
                color:
                    selected
                        ? kRomagnaPrimary.withValues(alpha: 0.08)
                        : Colors.white,
                child: InkWell(
                  onTap: () => Navigator.pop(sheetContext, opt.routeId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      opt.displayLabel,
                      style: lineItemStyle.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? kRomagnaPrimary : kRomagnaDarkGray,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    if (picked != null) onSelectedRouteId(picked);
  }

  return SizedBox(
    width: width,
    height: _kAvvisiLineFilterResetSize,
    child: _avvisiFilterFieldShell(
      child: InkWell(
        onTap: enabled ? openPicker : null,
        borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    style: lineItemStyle.copyWith(
                      color:
                          isPlaceholder
                              ? kRomagnaDarkGray.withValues(alpha: 0.55)
                              : kRomagnaDarkGray,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: kRomagnaDarkGray.withValues(alpha: enabled ? 0.55 : 0.28),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

enum InfobusBacinoFiltro { tutti, forliCesena, ravenna, rimini }

extension InfobusBacinoFiltroX on InfobusBacinoFiltro {
  String get label => switch (this) {
    InfobusBacinoFiltro.tutti => 'Tutti',
    InfobusBacinoFiltro.forliCesena => 'Forlì-Cesena',
    InfobusBacinoFiltro.ravenna => 'Ravenna',
    InfobusBacinoFiltro.rimini => 'Rimini',
  };

  String? get codice => switch (this) {
    InfobusBacinoFiltro.tutti => null,
    InfobusBacinoFiltro.forliCesena => 'FC',
    InfobusBacinoFiltro.ravenna => 'RA',
    InfobusBacinoFiltro.rimini => 'RN',
  };
}

class AvvisiLineFilterOption {
  const AvvisiLineFilterOption({
    required this.routeId,
    required this.displayLabel,
    required this.linea,
  });

  final String routeId;
  final String displayLabel;
  final String linea;
}

class AvvisiLineCatalogBundle {
  const AvvisiLineCatalogBundle({
    required this.catalog,
    required this.filtersByBasin,
  });

  final InfobusLineCatalog catalog;
  final Map<String, List<AvvisiLineFilterOption>> filtersByBasin;
}

class InfobusAvviso {
  const InfobusAvviso({
    required this.titolo,
    required this.url,
    required this.anteprima,
    required this.periodo,
    required this.lineeInteressate,
    required this.lineTokens,
    required this.localityHint,
    required this.bacini,
  });

  final String titolo;
  final Uri url;
  final String anteprima;
  final String periodo;
  final String lineeInteressate;
  final List<InfobusSiteLineToken> lineTokens;
  final String? localityHint;
  final Set<String> bacini;
}

String _stripHtml(String s) {
  var out =
      s
          .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
            ' ',
          )
          .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
            ' ',
          )
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n\s+'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
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

Set<String> _baciniFromClass(String classAttr) {
  final t = classAttr.toLowerCase();
  final out = <String>{};
  if (t.contains('forli-cesena')) out.add('FC');
  if (t.contains('ravenna')) out.add('RA');
  if (t.contains('rimini')) out.add('RN');
  return out;
}

List<InfobusAvviso> parseInfobusListing(String html) {
  final out = <InfobusAvviso>[];
  final chunks = html.split('<div class="col-12 mb-3 lista_info_news');
  for (var i = 1; i < chunks.length; i++) {
    final raw = '<div class="col-12 mb-3 lista_info_news${chunks[i]}';
    final classAttr =
        RegExp(
          r'^<div class="([^"]+)"',
          caseSensitive: false,
        ).firstMatch(raw)?.group(1) ??
        '';
    final href =
        (RegExp(
                  r'<a\s+href="(https://www\.startromagna\.it/infobus/[^"#\s]+)"[^>]*>\s*(?:&raquo;|»)?\s*Leggi\s*</a>',
                  caseSensitive: false,
                ).firstMatch(raw)?.group(1) ??
                RegExp(
                  r'<a\s+href="(https://www\.startromagna\.it/infobus/[^"#\s]+)"',
                  caseSensitive: false,
                ).firstMatch(raw)?.group(1) ??
                '')
            .trim();
    if (href.isEmpty) continue;
    final url = Uri.tryParse(href);
    if (url == null) continue;
    final titolo = _stripHtml(
      RegExp(
            r'<a\s+href="https://www\.startromagna\.it/infobus/[^"#\s]+"[^>]*>\s*([^<]+?)\s*</a>',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          '',
    );
    if (titolo.isEmpty) continue;
    final periodo = _stripHtml(
      RegExp(
            r'<strong>([\s\S]*?)</strong>',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          '',
    );
    final anteprima = _stripHtml(
      RegExp(
            r'<div class="mb-3"[^>]*>([\s\S]*?)</div>',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          '',
    ).replaceAll(RegExp(r'\s*»\s*Leggi\s*$', caseSensitive: false), '');
    final subtitle = _stripHtml(
      RegExp(
            r'<h2[^>]*>[\s\S]*?<small>\s*([^<]+?)\s*</small>',
            caseSensitive: false,
          ).firstMatch(raw)?.group(1) ??
          '',
    );
    final localityHint = inferInfobusAvvisoLocalityHint(titolo, subtitle);
    final lineTokens = <InfobusSiteLineToken>[];
    final spanRe = RegExp(
      r'<span class="span_linee">\s*([^<]+?)(?:\s*<small>\s*([^<]*?)\s*</small>)?\s*</span>',
      caseSensitive: false,
    );
    for (final m in spanRe.allMatches(raw)) {
      final line = _stripHtml(m.group(1) ?? '').trim();
      if (line.isEmpty) continue;
      final locRaw = _stripHtml(m.group(2) ?? '').trim().toUpperCase();
      final loc = locRaw.isEmpty ? null : locRaw;
      lineTokens.add(
        InfobusSiteLineToken(lineLabel: line, siteLocality: loc),
      );
    }
    final linee = lineTokens.map((t) => t.displayLabel).join(' · ');
    out.add(
      InfobusAvviso(
        titolo: titolo,
        url: url,
        anteprima: anteprima,
        periodo: periodo,
        lineeInteressate: linee,
        lineTokens: lineTokens,
        localityHint: localityHint,
        bacini: _baciniFromClass(classAttr),
      ),
    );
  }
  return out;
}

Future<List<InfobusAvviso>> fetchInfobusAvvisi() async {
  final res = await http.get(
    Uri.parse(_kInfobusUrl),
    headers: const {
      'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'User-Agent': 'RomagnaGO/1.0 (infobus listing)',
    },
  );
  if (res.statusCode < 200 || res.statusCode >= 300)
    throw Exception('HTTP ${res.statusCode}');
  return parseInfobusListing(res.body);
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

List<_ArticleBlock> _articleBlocksFromHtml(
  String html,
  TextStyle base,
  Uri pageUrl,
) {
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
      final src = RegExp(
        r'''src\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(tok)?.group(1);
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

Future<List<_ArticleBlock>> fetchInfobusDescrizione(
  Uri url,
  TextStyle base,
) async {
  final res = await http.get(
    url,
    headers: const {
      'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      'User-Agent': 'RomagnaGO/1.0 (infobus detail)',
    },
  );
  if (res.statusCode < 200 || res.statusCode >= 300)
    throw Exception('HTTP ${res.statusCode}');
  final articleHtml = _extractArticleBodyHtml(res.body);
  return _articleBlocksFromHtml(articleHtml, base, url);
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

bool _matchLinea(
  InfobusAvviso a,
  String lineFilterRouteId,
  String? requiredBasin,
  InfobusLineCatalog catalog,
) {
  final routeId = lineFilterRouteId.trim();
  if (routeId.isEmpty) return true;
  if (requiredBasin == null || requiredBasin.trim().isEmpty) return false;
  final tokens =
      a.lineTokens.isNotEmpty
          ? a.lineTokens
          : infobusLineeInteressateParsed(a.lineeInteressate);
  return infobusAvvisoMatchesRouteId(
    lineTokens: tokens,
    avvisoLocalityHint: a.localityHint,
    avvisoBasins: a.bacini,
    requiredBasin: requiredBasin,
    filterRouteId: routeId,
    catalog: catalog,
  );
}

Future<AvvisiLineCatalogBundle> loadAvvisiLineCatalogBundle() async {
  final raw = await rootBundle.loadString('assets/data/linee.json');
  final decoded = json.decode(raw) as Map<String, dynamic>;
  final list = decoded['linee'] as List<dynamic>? ?? const [];
  final catalogRows = <InfobusCatalogLine>[];
  for (final e in list) {
    if (e is! Map<String, dynamic>) continue;
    final linea = e['linea']?.toString().trim() ?? '';
    final bacino = e['bacino']?.toString().trim().toUpperCase() ?? '';
    final area = e['area']?.toString().trim() ?? '';
    final routeId = e['route_id']?.toString().trim() ?? '';
    if (linea.isEmpty || bacino.isEmpty || routeId.isEmpty) continue;
    catalogRows.add(
      InfobusCatalogLine(
        linea: linea,
        bacino: bacino,
        area: area,
        routeId: routeId,
      ),
    );
  }
  final catalog = InfobusLineCatalog(catalogRows);
  final filtersByBasin = <String, List<AvvisiLineFilterOption>>{
    'FC': [],
    'RA': [],
    'RN': [],
  };
  for (final basin in filtersByBasin.keys) {
    final rows = catalog.rowsInBasin(basin).toList();
    final lineaCounts = <String, int>{};
    for (final r in rows) {
      lineaCounts[r.linea] = (lineaCounts[r.linea] ?? 0) + 1;
    }
    final options =
        rows
            .map(
              (r) => AvvisiLineFilterOption(
                routeId: r.routeId,
                linea: r.linea,
                displayLabel: infobusAvvisiFilterDisplayLabel(
                  r,
                  ambiguousInBasin: (lineaCounts[r.linea] ?? 0) > 1,
                ),
              ),
            )
            .toList()
          ..sort((a, b) {
            final byLine = compareRomagnaLineLabels(a.linea, b.linea);
            if (byLine != 0) return byLine;
            return a.displayLabel.compareTo(b.displayLabel);
          });
    filtersByBasin[basin] = options;
  }
  return AvvisiLineCatalogBundle(
    catalog: catalog,
    filtersByBasin: filtersByBasin,
  );
}

class AvvisiPage extends StatefulWidget {
  const AvvisiPage({super.key});
  @override
  State<AvvisiPage> createState() => _AvvisiPageState();
}

class _AvvisiPageState extends State<AvvisiPage> {
  InfobusBacinoFiltro _filtro = InfobusBacinoFiltro.tutti;
  String _lineaFiltroRouteId = '';
  final _searchCtrl = TextEditingController();
  final _localitaCtrl = TextEditingController();
  late Future<List<InfobusAvviso>> _future;
  late Future<AvvisiLineCatalogBundle> _lineCatalogFuture;
  Timer? _refreshTimer;

  Duration _avvisiMaxAge(BuildContext context) =>
      AppSettingsScope.of(context).value.avvisiRefreshInterval.duration;

  void _reloadAvvisi({bool forceRefresh = false}) {
    final maxAge = _avvisiMaxAge(context);
    setState(() {
      _future = fetchInfobusAvvisiCached(
        maxAge: maxAge,
        forceRefresh: forceRefresh,
      );
    });
  }

  void _schedulePeriodicRefresh() {
    _refreshTimer?.cancel();
    final interval = _avvisiMaxAge(context);
    _refreshTimer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      _reloadAvvisi(forceRefresh: true);
    });
  }

  @override
  void initState() {
    super.initState();
    _lineCatalogFuture = loadAvvisiLineCatalogBundle();
    _searchCtrl.addListener(() => setState(() {}));
    _localitaCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadAvvisi();
      _schedulePeriodicRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    _localitaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Avvisi',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: dismissKeyboard,
        child: FutureBuilder<AvvisiLineCatalogBundle>(
          future: _lineCatalogFuture,
          builder: (context, lineeSnap) {
            if (lineeSnap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(strokeWidth: 2.2),
              );
            }
            if (lineeSnap.hasError || lineeSnap.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossibile caricare linee per filtri.\n${lineeSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final lineCatalog = lineeSnap.data!;
            final lineeByBacino = lineCatalog.filtersByBasin;
            return FutureBuilder<List<InfobusAvviso>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done)
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  );
                if (snap.hasError)
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossibile caricare gli avvisi.\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                final all = snap.data ?? const <InfobusAvviso>[];
                final byBacino =
                    _filtro == InfobusBacinoFiltro.tutti
                        ? all
                        : all
                            .where((a) => a.bacini.contains(_filtro.codice))
                            .toList();
                final filtered =
                    byBacino.where((a) {
                      final q = _norm(_searchCtrl.text);
                      if (q.isNotEmpty &&
                          !_norm('${a.titolo} ${a.anteprima}').contains(q))
                        return false;
                      if (!_matchLinea(
                        a,
                        _lineaFiltroRouteId,
                        _filtro.codice,
                        lineCatalog.catalog,
                      )) {
                        return false;
                      }
                      final lq = _norm(_localitaCtrl.text);
                      if (lq.isNotEmpty && !_norm(a.titolo).contains(lq))
                        return false;
                      return true;
                    }).toList();
                final prioritizeSciopero =
                    AppSettingsScope.of(context).value.prioritizeScioperoAvvisi;
                final visibili = sortAvvisiForDisplay(
                  filtered,
                  prioritizeSciopero: prioritizeSciopero,
                );
                final bac = _filtro.codice;
                final lineeOrd =
                    bac == null
                        ? const <AvvisiLineFilterOption>[]
                        : (lineeByBacino[bac] ?? const <AvvisiLineFilterOption>[]);
                return Column(
                  children: [
                    Material(
                      color: Colors.white,
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final f
                                      in InfobusBacinoFiltro.values) ...[
                                    ChoiceChip(
                                      label: Text(f.label),
                                      selected: _filtro == f,
                                      onSelected:
                                          (_) => setState(() {
                                            _filtro = f;
                                            _lineaFiltroRouteId = '';
                                          }),
                                    ),
                                    if (f != InfobusBacinoFiltro.values.last)
                                      const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: _kAvvisiLineFilterResetSize,
                              child: _avvisiFilterFieldShell(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onTapOutside: (_) => dismissKeyboard(),
                                  style: _avvisiFilterFieldTextStyle(),
                                  decoration: _avvisiFilterInputDecoration(
                                    'Cerca avviso...',
                                    prefixIcon: const Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 420;
                                final lineFilterHint =
                                    _filtro == InfobusBacinoFiltro.tutti
                                        ? 'Scegli prima un bacino in alto'
                                        : 'Filtra linea';
                                final lineFilterEnabled =
                                    _filtro != InfobusBacinoFiltro.tutti;
                                final lineFilterResetEnabled =
                                    lineFilterEnabled &&
                                    _lineaFiltroRouteId.isNotEmpty;
                                void resetLineFilter() {
                                  if (!lineFilterResetEnabled) return;
                                  setState(() => _lineaFiltroRouteId = '');
                                }

                                Widget buildLineFilterRow() {
                                  return _avvisiLineFilterRow(
                                    dropdown: LayoutBuilder(
                                      builder: (context, box) {
                                        return _avvisiLineFilterDropdown(
                                          context: context,
                                          width: box.maxWidth,
                                          hintText: lineFilterHint,
                                          selectedRouteId: _lineaFiltroRouteId,
                                          options: lineeOrd,
                                          enabled: lineFilterEnabled,
                                          onSelectedRouteId:
                                              (v) => setState(
                                                () => _lineaFiltroRouteId = v,
                                              ),
                                        );
                                      },
                                    ),
                                    resetEnabled: lineFilterResetEnabled,
                                    onReset: resetLineFilter,
                                  );
                                }

                                final localita = SizedBox(
                                  height: _kAvvisiLineFilterResetSize,
                                  child: _avvisiFilterFieldShell(
                                    child: TextField(
                                      controller: _localitaCtrl,
                                      onTapOutside: (_) => dismissKeyboard(),
                                      style: _avvisiFilterFieldTextStyle(),
                                      decoration: _avvisiFilterInputDecoration(
                                        'Filtra località (cerca dal titolo)',
                                      ),
                                    ),
                                  ),
                                );
                                if (compact) {
                                  return Column(
                                    children: [
                                      buildLineFilterRow(),
                                      const SizedBox(height: 8),
                                      localita,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: buildLineFilterRow()),
                                    const SizedBox(width: 8),
                                    Expanded(child: localita),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                        itemCount: visibili.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final a = visibili[i];
                          return Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
                            ),
                            child: InkWell(
                              onTap:
                                  () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder:
                                          (_) => AvvisoDettaglioPage(avviso: a),
                                    ),
                                  ),
                              borderRadius: BorderRadius.circular(_kAvvisiFilterFieldRadius),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a.titolo,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (a.anteprima.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        a.anteprima,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (a.periodo.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        a.periodo,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: kRomagnaPrimary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AvvisoDettaglioPage extends StatefulWidget {
  const AvvisoDettaglioPage({super.key, required this.avviso});
  final InfobusAvviso avviso;
  @override
  State<AvvisoDettaglioPage> createState() => _AvvisoDettaglioPageState();
}

class _AvvisoDettaglioPageState extends State<AvvisoDettaglioPage> {
  late Future<List<_ArticleBlock>> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchInfobusDescrizione(
      widget.avviso.url,
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
                  widget.avviso.url,
                  mode: LaunchMode.externalApplication,
                ),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<_ArticleBlock>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                widget.avviso.titolo,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kRomagnaPrimary,
                ),
              ),
              if (widget.avviso.periodo.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.avviso.periodo,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kRomagnaDarkGray.withValues(alpha: 0.9),
                  ),
                ),
              ],
              if (widget.avviso.lineeInteressate.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Linee: ${widget.avviso.lineeInteressate}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: kRomagnaDarkGray.withValues(alpha: 0.82),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ..._buildArticleBlocks(
                context,
                snap.data ?? const <_ArticleBlock>[],
              ),
            ],
          );
        },
      ),
    );
  }
}

List<Widget> _buildArticleBlocks(
  BuildContext context,
  List<_ArticleBlock> blocks,
) {
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
        errorBuilder:
            (context, _, __) => Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Immagine non disponibile',
                style: GoogleFonts.inter(
                  color: kRomagnaDarkGray.withValues(alpha: 0.7),
                ),
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
                        child: Image.network(
                          url.toString(),
                          fit: BoxFit.contain,
                        ),
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

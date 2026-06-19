import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;

import '../start_content_html_utils.dart';

/// Prima occorrenza di ogni chiave i18n (blocco italiano prima del duplicato inglese).
Map<String, String> startContentItalianI18nMap(String html) {
  final map = <String, String>{};
  final re = RegExp(r"(\w+):\s*'((?:\\'|[^'])*)'");
  for (final m in re.allMatches(html)) {
    final key = m.group(1)!;
    map.putIfAbsent(key, () => m.group(2)!.replaceAll(r"\'", "'"));
  }
  return map;
}

String? startContentI18nKey(String html, String key) =>
    startContentItalianI18nMap(html)[key];

String startContentI18nPlain(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  return startContentStripInlineHtml(raw);
}

String startContentStripInlineHtml(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
  s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
  return startContentNormalizeText(startContentDecodeHtmlEntities(s));
}

String? startContentHrefInHtml(String? html) {
  if (html == null) return null;
  final m = RegExp(r'href="([^"]+)"').firstMatch(html);
  return m?.group(1);
}

Element? startContentSrRoot(Document doc, String css) => doc.querySelector(css);

Element? startContentSectionById(Document doc, String sectionId) =>
    doc.getElementById(sectionId);

List<String> startContentItalianLangTexts(
  Element root, {
  String selector = '[data-lang="it"]',
}) {
  return [
    for (final el in root.querySelectorAll(selector))
      startContentNormalizeText(
        startContentDecodeHtmlEntities(el.text),
      ),
  ].where((s) => s.isNotEmpty).toList();
}

List<String> startContentItalianBlockTexts(Element section) {
  return [
    for (final el in section.querySelectorAll('[data-lang-block="it"]'))
      startContentNormalizeText(
        startContentDecodeHtmlEntities(el.text),
      ),
  ].where((s) => s.isNotEmpty).toList();
}

List<String> startContentSectionBullets(Document doc, String sectionId) {
  final sec = startContentSectionById(doc, sectionId);
  if (sec == null) return [];
  return [
    for (final li in sec.querySelectorAll('li[data-lang-block="it"]'))
      startContentNormalizeText(
        startContentDecodeHtmlEntities(li.text),
      ),
  ].where((s) => s.isNotEmpty).toList();
}

String? startContentSectionFirstParagraph(Document doc, String sectionId) {
  final sec = startContentSectionById(doc, sectionId);
  if (sec == null) return null;
  final p = sec.querySelector('p[data-lang-block="it"]');
  if (p == null) return null;
  final text = startContentNormalizeText(
    startContentDecodeHtmlEntities(p.text),
  );
  return text.length >= 15 ? text : null;
}

String? startContentSectionParagraphContaining(
  Document doc,
  String sectionId,
  String needle,
) {
  final sec = startContentSectionById(doc, sectionId);
  if (sec == null) return null;
  final lower = needle.toLowerCase();
  for (final p in sec.querySelectorAll('p[data-lang-block="it"]')) {
    final text = startContentNormalizeText(
      startContentDecodeHtmlEntities(p.text),
    );
    if (text.toLowerCase().contains(lower) && text.length >= 20) {
      return text;
    }
  }
  return null;
}

List<String> startContentParagraphsAfter(
  Document doc,
  String sectionId,
  String afterNeedle, {
  int max = 5,
}) {
  final sec = startContentSectionById(doc, sectionId);
  if (sec == null) return [];
  final paragraphs = sec.querySelectorAll('p[data-lang-block="it"]');
  var found = false;
  final out = <String>[];
  for (final p in paragraphs) {
    final text = startContentNormalizeText(
      startContentDecodeHtmlEntities(p.text),
    );
    if (text.isEmpty) continue;
    if (!found) {
      if (text.toLowerCase().contains(afterNeedle.toLowerCase())) {
        found = true;
      }
      continue;
    }
    out.add(text);
    if (out.length >= max) break;
  }
  return out;
}

String startContentNormalizePrezzo(String raw) {
  final s = startContentNormalizeText(raw);
  if (s == '—' || s == '-' || s.toLowerCase().startsWith('variabile')) {
    return s.contains('*') ? s : s;
  }
  final m = RegExp(r'([\d.,]+)\s*€').firstMatch(s);
  if (m != null) return '€ ${m.group(1)}';
  if (s.startsWith('€')) return s;
  return s;
}

List<Map<String, String?>> startContentParsePrezzoTable(Element table) {
  final rows = <Map<String, String?>>[];
  for (final tr in table.querySelectorAll('tr')) {
    final cells = tr.querySelectorAll('th,td');
    if (cells.length < 2) continue;
    final titolo = startContentNormalizeText(cells[0].text);
    final prezzoRaw = startContentNormalizeText(cells[1].text);
    if (titolo.isEmpty || prezzoRaw.isEmpty) continue;
    final lower = titolo.toLowerCase();
    if (lower == 'abbonamento' || lower == 'prezzo' || lower == 'ticket') {
      continue;
    }
    final prezzo = startContentNormalizePrezzo(prezzoRaw);
    String? nota;
    if (cells.length > 2) {
      final n = startContentNormalizeText(cells[2].text);
      if (n.isNotEmpty) nota = n;
    }
    rows.add({
      'titolo': titolo,
      'prezzo': prezzo,
      if (nota != null) 'nota': nota,
    });
  }
  return rows;
}

List<List<Map<String, String?>>> startContentParseSubscriptionTables(
  String html,
) {
  final doc = parse(html);
  return [
    for (final table in doc.querySelectorAll('table'))
      startContentParsePrezzoTable(table),
  ].where((rows) => rows.isNotEmpty).toList();
}

List<Map<String, String>> startContentParseFareTable(Element root) {
  final rows = <Map<String, String>>[];
  for (final table in root.querySelectorAll('table')) {
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('th,td');
      if (cells.length < 2) continue;
      final ticket = startContentNormalizeText(cells[0].text);
      final price = startContentNormalizePrezzo(
        startContentNormalizeText(cells[1].text),
      );
      if (ticket.isEmpty || !startContentIsValidPrice(price)) continue;
      final validity =
          cells.length > 2
              ? startContentNormalizeText(cells[2].text)
              : '';
      rows.add({
        'ticket': ticket,
        'price': price,
        if (validity.isNotEmpty) 'validity': validity,
      });
    }
  }
  return rows;
}

List<String> startContentListItemsUnderHeading(Element root, String heading) {
  for (final h in root.querySelectorAll('h2, h3, h4')) {
    if (!h.text.toLowerCase().contains(heading.toLowerCase())) continue;
    var el = h.nextElementSibling;
    while (el != null) {
      if (el.localName == 'ul') {
        return [
          for (final li in el.querySelectorAll('li'))
            startContentNormalizeText(
              startContentDecodeHtmlEntities(li.text),
            ),
        ].where((s) => s.isNotEmpty).toList();
      }
      if (el.localName == 'h2' || el.localName == 'h3') break;
      el = el.nextElementSibling;
    }
  }
  return [];
}

String? startContentParagraphUnderHeading(Element root, String heading) {
  for (final h in root.querySelectorAll('h2, h3, h4')) {
    if (!h.text.toLowerCase().contains(heading.toLowerCase())) continue;
    var el = h.nextElementSibling;
    while (el != null) {
      if (el.localName == 'p') {
        final text = startContentNormalizeText(
          startContentDecodeHtmlEntities(el.text),
        );
        if (text.length >= 20) return text;
      }
      if (el.localName == 'h2' || el.localName == 'h3') break;
      el = el.nextElementSibling;
    }
  }
  return null;
}

Map<String, String> startContentPdfUrlsByPatterns(
  Element root,
  Map<String, RegExp> patterns,
) {
  final out = <String, String>{};
  for (final a in root.querySelectorAll('a[href*=".pdf"]')) {
    final href = a.attributes['href'];
    if (href == null || href.isEmpty) continue;
    for (final e in patterns.entries) {
      if (out.containsKey(e.key)) continue;
      if (e.value.hasMatch(href)) out[e.key] = href;
    }
  }
  return out;
}

List<Map<String, dynamic>> startContentScioperoCards(Element root) {
  const titles = ['Forlì-Cesena', 'Ravenna', 'Rimini'];
  final sec = root.querySelector('#sciopero');
  if (sec == null) return [];
  final cards = sec.querySelectorAll('.sr-card');
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < cards.length && i < titles.length; i++) {
    final card = cards[i];
    final lines = <String>[];
    for (final el in card.querySelectorAll(
      'p[data-lang-block="it"], li[data-lang-block="it"]',
    )) {
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(el.text),
      );
      if (text.length < 8) continue;
      lines.add(text);
    }
    if (lines.isEmpty) continue;
    out.add({'title': titles[i], 'lines': lines});
  }
  return out;
}

List<String> startContentShuttlemareBookingSteps(Element root) {
  final steps = <String>[];
  for (final line in root.querySelectorAll('.sr-how-line')) {
    final en = line.querySelector('[data-lang="en"]');
    if (en != null) continue;
    final text = startContentNormalizeText(
      startContentDecodeHtmlEntities(line.text),
    );
    final cleaned = text.replaceFirst(RegExp(r'^\d+'), '').trim();
    if (cleaned.isNotEmpty) steps.add(cleaned);
    if (steps.length >= 5) break;
  }
  return steps;
}

List<Map<String, dynamic>> startContentShuttlemareParkingLots(Element root) {
  final lots = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final item in root.querySelectorAll('.sr-parking-item')) {
    if (item.querySelector('[data-lang="en"]') != null) continue;
    var text = startContentNormalizeText(
      startContentDecodeHtmlEntities(item.text),
    );
    text = text.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    final unavailable = text.toLowerCase().contains('non disponibile');
    text = text
        .replaceAll(
          RegExp(r'\s*Temporaneamente non disponibile', caseSensitive: false),
          '',
        )
        .trim();
    final name = text.split(RegExp(r'\s{2,}')).first.trim();
    if (name.isEmpty || seen.contains(name)) continue;
    seen.add(name);
    lots.add({
      'name': name,
      if (unavailable) 'unavailable': true,
    });
  }
  return lots;
}

bool startContentIsEnglishLangElement(Element el) {
  var node = el;
  while (true) {
    final lang = node.attributes['data-lang'];
    if (lang == 'en') return true;
    if (lang == 'it') return false;
    final parent = node.parent;
    if (parent is! Element) return false;
    node = parent;
  }
}

List<Map<String, dynamic>> startContentShuttlemareRuleGroups(Element root) {
  final groups = <Map<String, dynamic>>[];
  for (final h in root.querySelectorAll('h3[data-lang="it"], h3')) {
    if (startContentIsEnglishLangElement(h)) continue;
    final title = startContentNormalizeText(h.text);
    if (title.isEmpty ||
        title.toLowerCase().contains('when') ||
        title.toLowerCase().contains('how')) {
      continue;
    }
    final bullets = <String>[];
    var el = h.nextElementSibling;
    while (el != null) {
      if (el.localName == 'ul') {
        bullets.addAll([
          for (final li in el.querySelectorAll('li[data-lang="it"], li'))
            if (!startContentIsEnglishLangElement(li))
              startContentNormalizeText(
                startContentDecodeHtmlEntities(li.text),
              ),
        ]);
        break;
      }
      if (el.localName == 'h2' || el.localName == 'h3') break;
      el = el.nextElementSibling;
    }
    if (bullets.isNotEmpty) {
      groups.add({'title': title, 'bullets': bullets});
    }
    if (groups.length >= 2) break;
  }
  return groups;
}

Map<String, String>? startContentNavettaMiMaSchedule(
  Element root,
  String monthName,
) {
  for (final month in root.querySelectorAll('.sr-navetta-month')) {
    final h = month.querySelector('h3')?.text.trim();
    if (h == null || h != monthName) continue;
    final svc = month.querySelector('.sr-navetta-service');
    if (svc == null) return null;
    final text = startContentNormalizeText(
      startContentDecodeHtmlEntities(svc.text),
    );
    final hours = RegExp(
      r'Orario servizio:\s*([0-9:.–\s]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final freq = RegExp(
      r'^(Navetta ogni[^O]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (hours == null) return null;
    return {
      'serviceHoursLabel': startContentNormalizeText(hours.group(1)!),
      'frequencyLabel': startContentNormalizeText(
        freq?.group(1)?.replaceAll(RegExp(r'\s+'), ' ') ??
            'Navetta ogni 15 minuti · ogni 20 minuti dalle 21:30',
      ),
    };
  }
  return null;
}

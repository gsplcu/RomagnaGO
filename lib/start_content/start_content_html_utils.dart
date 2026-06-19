import 'package:html/parser.dart' show parse;

String? startContentFetchHtml(String url) => null;

Future<String?> startContentHttpGet(String url) async {
  // Implemented in parsers via http package.
  return null;
}

String startContentNormalizeText(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), ' ').trim();

String startContentDecodeHtmlEntities(String s) {
  var out = s;
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final v = int.tryParse(m.group(1)!);
    return v == null ? m.group(0)! : String.fromCharCode(v);
  });
  out = out.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final v = int.tryParse(m.group(1)!, radix: 16);
    return v == null ? m.group(0)! : String.fromCharCode(v);
  });
  out = out.replaceAll('&nbsp;', ' ');
  out = out.replaceAll('&amp;', '&');
  out = out.replaceAll('&quot;', '"');
  out = out.replaceAll('&#8217;', "'");
  out = out.replaceAll('&#8211;', '–');
  return out;
}

String startContentElementText(String html) {
  final doc = parse(html);
  return startContentNormalizeText(
    startContentDecodeHtmlEntities(doc.body?.text ?? ''),
  );
}

List<Map<String, String>> startContentParseFareTableRows(String html) {
  final doc = parse(html);
  final rows = <Map<String, String>>[];
  for (final table in doc.querySelectorAll('table')) {
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr.querySelectorAll('th,td');
      if (cells.length < 2) continue;
      final ticket = startContentNormalizeText(cells[0].text);
      final price = startContentNormalizeText(cells[1].text);
      if (ticket.isEmpty || price.isEmpty) continue;
      if (!price.contains('€')) continue;
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

bool startContentIsValidPrice(String price) =>
    RegExp(r'€\s*\d').hasMatch(price);

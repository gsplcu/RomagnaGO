import 'package:html/parser.dart' show parse;

import '../start_content_html_utils.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

class NavettaNavettomareParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.navettaNavettomare;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final root = startContentSrRoot(parse(html), '.sr-navettomare');
    if (root == null) return null;

    final patch = <String, dynamic>{'heroTitle': 'Navetto Mare'};

    for (final el in root.querySelectorAll('[data-lang="it"]')) {
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(el.text),
      );
      if (text.contains('Parcheggi') && text.contains('litorale')) {
        patch['heroSubtitle'] = text;
        break;
      }
    }

    for (final p in root.querySelectorAll('p[data-lang="it"], p')) {
      if (startContentIsEnglishLangElement(p)) continue;
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(p.text),
      );
      if (text.contains('calendario') &&
          text.contains('2026') &&
          text.length > 40) {
        patch['heroServiceNote'] = text;
        break;
      }
    }

    final chips = <String>[];
    for (final stat in root.querySelectorAll('.sr-stat[data-lang="it"], .sr-stat')) {
      if (stat.querySelector('[data-lang="en"]') != null) continue;
      final strong = stat.querySelector('strong');
      if (strong == null) continue;
      final chip = startContentNormalizeText(strong.text);
      if (chip.isNotEmpty) chips.add(chip);
    }
    if (chips.isNotEmpty) patch['heroChips'] = chips;

    if (patch.length <= 1) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if ((json['heroSubtitle'] as String?)?.isNotEmpty != true) {
      return 'heroSubtitle';
    }
    return null;
  }
}

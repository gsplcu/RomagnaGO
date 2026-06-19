import '../start_content_html_utils.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';

class NavettaCesenaticoParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.navettaCesenatico;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final features = <Map<String, String>>[];
    final re = RegExp(
      r'<h[3-4][^>]*>([^<]+)</h[3-4]>\s*<p[^>]*>([\s\S]*?)</p>',
      caseSensitive: false,
    );
    for (final m in re.allMatches(html)) {
      final title = startContentNormalizeText(m.group(1)!);
      final body = startContentElementText(m.group(2)!);
      if (title.length < 3 || body.length < 10) continue;
      if (title.toLowerCase().contains('cookie')) continue;
      features.add({'title': title, 'body': body});
      if (features.length >= 3) break;
    }
    if (features.isEmpty) return null;
    return {'features': features};
  }

  @override
  String? validate(Map<String, dynamic> json) {
    final f = json['features'];
    if (f is! List || f.isEmpty) return 'features';
    return null;
  }
}

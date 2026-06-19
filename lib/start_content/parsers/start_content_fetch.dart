import 'package:http/http.dart' as http;

import '../start_content_config.dart';
import '../start_content_html_utils.dart';

Future<String?> startContentDownloadPage(String url) async {
  try {
    final res = await http
        .get(Uri.parse(url), headers: kStartContentHttpHeaders)
        .timeout(kStartContentHttpTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    return res.body;
  } catch (_) {
    return null;
  }
}

List<Map<String, String>>? startContentExtractFareSection(
  String html,
  String sectionTitle,
) {
  final lower = html.toLowerCase();
  final idx = lower.indexOf(sectionTitle.toLowerCase());
  if (idx < 0) return null;
  final end = (idx + 12000).clamp(0, html.length);
  final slice = html.substring(idx, end);
  final rows = startContentParseFareTableRows(slice);
  return rows.isEmpty ? null : rows;
}

String? startContentExtractParagraphAfter(
  String html,
  String heading,
) {
  final pattern = RegExp(
    '<h[1-6][^>]*>\\s*${RegExp.escape(heading)}\\s*</h[1-6]>([\\s\\S]{0,2500}?)(?=<h[1-6]|</div\\s+class="entry)',
    caseSensitive: false,
  );
  final m = pattern.firstMatch(html);
  if (m == null) return null;
  final text = startContentElementText(m.group(1)!);
  return text.length < 20 ? null : text;
}

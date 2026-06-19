import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';

class NavettaBussiParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.navettaBussi;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final patch = <String, dynamic>{};

    final summer = RegExp(
      r'(\d{1,2}\s+\w+\s+al\s+\d{1,2}\s+\w+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (summer != null) {
      patch['summerPeriodLabel'] = 'Servizio BusSì dal ${summer.group(1)}';
    }

    final email = RegExp(
      r'bussi@startromagna\.it',
      caseSensitive: false,
    ).firstMatch(html);
    if (email != null) {
      patch['assistenzaEmail'] = 'bussi@startromagna.it';
    }

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if (json['assistenzaEmail'] == null && json['summerPeriodLabel'] == null) {
      return 'empty';
    }
    return null;
  }
}

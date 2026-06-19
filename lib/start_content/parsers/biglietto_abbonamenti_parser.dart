import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'abbonamenti_web_extract.dart';
import 'start_content_fetch.dart';

class BigliettoAbbonamentiParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.bigliettoAbbonamenti;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;
    return parseBigliettoAbbonamentiPatch(html);
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if ((json['overviewIntro'] as String?)?.isNotEmpty != true) {
      return 'overviewIntro';
    }
    return null;
  }
}

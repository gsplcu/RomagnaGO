import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'abbonamenti_web_extract.dart';
import 'start_content_fetch.dart';

class AbbonamentiOrdinariParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.abbonamentiOrdinari;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;
    return parseAbbonamentiOrdinariPatch(html);
  }

  @override
  String? validate(Map<String, dynamic> json) {
    final mensili = json['mensili'];
    final annuali = json['annuali'];
    if (mensili is! Map || annuali is! Map) return 'sections';
    final mRows = (mensili as Map)['tariffarioGenerale'];
    final aRows = (annuali as Map)['tariffarioGenerale'];
    if (mRows is! List || mRows.isEmpty) return 'mensili.tariffarioGenerale';
    if (aRows is! List || aRows.isEmpty) return 'annuali.tariffarioGenerale';
    return null;
  }
}

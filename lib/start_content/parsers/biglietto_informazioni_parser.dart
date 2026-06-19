import '../baseline/biglietto_informazioni_baseline.dart';
import '../start_content_html_utils.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';

class BigliettoInformazioniParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.bigliettoInformazioni;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final patch = <String, dynamic>{};
    final corsa = startContentExtractFareSection(html, 'corsa semplice');
    if (corsa != null && _validFareRows(corsa)) {
      patch['corsaSemplice'] = corsa;
    }
    final multi = startContentExtractFareSection(html, 'multicorsa');
    if (multi != null && _validFareRows(multi)) {
      patch['multicorsa'] = multi;
    }
    final day = startContentExtractFareSection(html, 'day ticket');
    if (day != null && _validFareRows(day)) {
      patch['dayTicket'] = day;
    }
    final metro = startContentExtractFareSection(html, 'metromare');
    if (metro != null && _validFareRows(metro)) {
      patch['metromare'] = metro;
    }
    final board = startContentExtractFareSection(html, 'a bordo');
    if (board != null && _validFareRows(board)) {
      patch['aBordo'] = board;
    }

    if (patch.isEmpty) return null;
    return patch;
  }

  bool _validFareRows(List<Map<String, String>> rows) {
    if (rows.isEmpty) return false;
    return rows.every(
      (r) =>
          (r['ticket'] ?? '').isNotEmpty &&
          startContentIsValidPrice(r['price'] ?? ''),
    );
  }

  @override
  String? validate(Map<String, dynamic> json) {
    final baseline = baselineBigliettoInformazioni();
    for (final key in ['corsaSemplice', 'multicorsa', 'dayTicket']) {
      final rows = json[key];
      if (rows is! List || rows.isEmpty) {
        if (baseline[key] is List && (baseline[key] as List).isNotEmpty) {
          continue;
        }
        return 'missing $key';
      }
    }
    return null;
  }
}

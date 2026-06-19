import 'package:html/parser.dart' show parse;

import '../baseline/start_content_baselines.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

class ServizioClientiParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.servizioClienti;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final patch = <String, dynamic>{};

    final phone = RegExp(r'199[\s.]*11[\s.]*55[\s.]*77').firstMatch(html);
    if (phone != null) {
      patch['infoStartPhoneDisplay'] = '199.11.55.77';
      patch['infoStartPhoneTel'] = '199115577';
    }

    final email = RegExp(
      r'servizioclienti@startromagna\.it',
      caseSensitive: false,
    ).firstMatch(html);
    if (email != null) {
      patch['servizioClientiEmail'] = 'servizioclienti@startromagna.it';
    }

    final wa = RegExp(r'331[\s.]*65[\s.]*66[\s.]*555').firstMatch(html);
    if (wa != null) {
      patch['whatsAppDisplay'] = '331.65.66.555';
    }

    final root = startContentSrRoot(parse(html), '.sr-servizi-clienti');
    if (root != null) {
      final intro = startContentParagraphUnderHeading(
        root,
        'Come contattare',
      );
      if (intro != null) patch['intro'] = intro;
    }

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if ((json['infoStartPhoneDisplay'] as String?)?.isNotEmpty != true) {
      final b = baselineServizioClienti();
      if (b['infoStartPhoneDisplay'] == null) return 'phone';
    }
    return null;
  }
}

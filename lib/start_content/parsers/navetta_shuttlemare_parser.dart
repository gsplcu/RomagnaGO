import 'package:html/parser.dart' show parse;

import '../start_content_html_utils.dart';
import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

class NavettaShuttlemareParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.navettaShuttlemare;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final root = startContentSrRoot(parse(html), '.sr-shuttlemare');
    if (root == null) return null;

    final patch = <String, dynamic>{};

    for (final p in root.querySelectorAll('p[data-lang="it"], p')) {
      if (startContentIsEnglishLangElement(p)) continue;
      final text = startContentNormalizeText(
        startContentDecodeHtmlEntities(p.text),
      );
      if (text.contains('minibus') && text.contains('passeggeri')) {
        patch['onboardIntro'] = text;
        break;
      }
    }

    final groups = startContentShuttlemareRuleGroups(root);
    if (groups.isNotEmpty) patch['onboardRuleGroups'] = groups;

    final steps = startContentShuttlemareBookingSteps(root);
    if (steps.isNotEmpty) patch['bookingSteps'] = steps;

    final lots = startContentShuttlemareParkingLots(root);
    if (lots.isNotEmpty) patch['parkingLots'] = lots;

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    if ((json['onboardIntro'] as String?)?.isNotEmpty != true &&
        (json['bookingSteps'] as List?)?.isEmpty != false) {
      return 'empty';
    }
    return null;
  }
}

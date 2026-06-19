import 'package:html/parser.dart' show parse;

import '../start_content_id.dart';
import '../start_content_parser.dart';
import 'start_content_fetch.dart';
import 'start_content_page_extract.dart';

class NavettaMilanoMarittimaParser implements StartContentParser {
  @override
  StartContentId get id => StartContentId.navettaMilanoMarittima;

  @override
  Future<Map<String, dynamic>?> fetchFromWeb() async {
    final html = await startContentDownloadPage(id.sourceUrl);
    if (html == null) return null;

    final doc = parse(html);
    final root =
        startContentSrRoot(doc, '.sr-navetta') ?? doc.body;
    if (root == null) return null;

    final patch = <String, dynamic>{};
    final august = startContentNavettaMiMaSchedule(root, 'Agosto');
    final june = startContentNavettaMiMaSchedule(root, 'Giugno');
    if (august != null) patch['scheduleAugust'] = august;
    if (june != null) patch['scheduleDefault'] = june;

    if (patch.isEmpty) return null;
    return patch;
  }

  @override
  String? validate(Map<String, dynamic> json) {
    final aug = json['scheduleAugust'];
    final def = json['scheduleDefault'];
    if (aug is! Map && def is! Map) return 'schedules';
    return null;
  }
}

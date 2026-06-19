import 'start_content_id.dart';
import 'start_content_repository.dart';
import 'start_content_json.dart';
import 'baseline/start_content_baselines.dart';

/// Cache testuale navette sincronizzata da Start (fallback su baseline).
class NavettaContentSync {
  NavettaContentSync._();

  static final Map<StartContentId, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> load(StartContentId id) async {
    if (_cache.containsKey(id)) return _cache[id]!;
    try {
      final json = await StartContentRepository.instance.load(id);
      _cache[id] = json;
      return json;
    } catch (_) {
      final fb = baselineFor(id) ?? <String, dynamic>{};
      _cache[id] = fb;
      return fb;
    }
  }

  static Future<void> preloadNavette() async {
    await Future.wait([
      load(StartContentId.navettaCesenatico),
      load(StartContentId.navettaBussi),
      load(StartContentId.navettaShuttlemare),
      load(StartContentId.navettaNavettomare),
      load(StartContentId.navettaMilanoMarittima),
    ]);
  }

  static String text(StartContentId id, String key, {String fallback = ''}) =>
      scText(_cache[id], key, fallback: fallback);

  static List<String> strings(
    StartContentId id,
    String key, {
    List<String> fallback = const [],
  }) => scStringList(_cache[id], key, fallback: fallback);

  static List<Map<String, dynamic>> mapList(StartContentId id, String key) =>
      scMapList(_cache[id], key);

  static Map<String, dynamic>? scheduleBlock(
    StartContentId id,
    String key,
  ) =>
      scMap(_cache[id], key);
}

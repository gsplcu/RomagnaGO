// Cache elenco avvisi InfoBus + ordinamento opzionale sciopero.

import 'avvisi_page.dart';

List<InfobusAvviso>? _cachedAvvisi;
DateTime? _cachedAt;

List<InfobusAvviso> sortAvvisiForDisplay(
  List<InfobusAvviso> list, {
  required bool prioritizeSciopero,
}) {
  if (!prioritizeSciopero || list.length < 2) return list;
  final out = List<InfobusAvviso>.from(list);
  out.sort((a, b) {
    final sa = a.titolo.toLowerCase().contains('sciopero');
    final sb = b.titolo.toLowerCase().contains('sciopero');
    if (sa == sb) return 0;
    return sa ? -1 : 1;
  });
  return out;
}

/// Fetch con TTL; [forceRefresh] ignora la cache.
Future<List<InfobusAvviso>> fetchInfobusAvvisiCached({
  Duration? maxAge,
  bool forceRefresh = false,
}) async {
  final age = maxAge ?? const Duration(minutes: 30);
  final now = DateTime.now();
  if (!forceRefresh &&
      _cachedAvvisi != null &&
      _cachedAt != null &&
      now.difference(_cachedAt!) < age) {
    return _cachedAvvisi!;
  }
  final list = await fetchInfobusAvvisi();
  _cachedAvvisi = list;
  _cachedAt = now;
  return list;
}

void clearAvvisiCache() {
  _cachedAvvisi = null;
  _cachedAt = null;
}

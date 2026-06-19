import 'start_trova_zona_api.dart';
import 'start_trova_zona_cache.dart';

Future<TrovaZonaOfflineData?> tryLoadTrovaZonaCache() async {
  try {
    return await TrovaZonaCacheLoader.load();
  } catch (_) {
    return null;
  }
}

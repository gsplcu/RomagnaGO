import 'start_content_id.dart';

/// Parser opzionale: estrae dal sito solo i campi mostrati in app.
abstract class StartContentParser {
  StartContentId get id;

  /// `null` se fetch/parse non disponibile → il chiamante mantiene la cache.
  Future<Map<String, dynamic>?> fetchFromWeb();

  /// Valida il payload prima di salvarlo in cache. `null` se invalido.
  String? validate(Map<String, dynamic> json);
}

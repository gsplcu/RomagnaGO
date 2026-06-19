/// Manifest remoto opzionale (Firebase Storage / CDN).
///
/// Se vuoto o non raggiungibile, l'app usa solo cache locale + asset nel bundle
/// e tenta il refresh diretto dalle pagine sorgente tramite parser.
const String kStartContentRemoteManifestUrl =
    'https://firebasestorage.googleapis.com/v0/b/romagnago-app.firebasestorage.app/o/start_content%2Fmanifest.json?alt=media';

/// Base URL per JSON remoti (stesso bucket). `{id}` → fileKey.
const String kStartContentRemoteJsonUrlTemplate =
    'https://firebasestorage.googleapis.com/v0/b/romagnago-app.firebasestorage.app/o/start_content%2F{id}.json?alt=media';

/// Intervallo minimo tra due tentativi di refresh per lo stesso pacchetto.
const Duration kStartContentRefreshMinInterval = Duration(hours: 12);

const Duration kStartContentHttpTimeout = Duration(seconds: 25);

const Map<String, String> kStartContentHttpHeaders = {
  'User-Agent': 'RomagnaGO/1.0 (+https://startromagna.it)',
  'Accept': 'text/html,application/json',
};

String startContentRemoteJsonUrl(String fileKey) =>
    kStartContentRemoteJsonUrlTemplate.replaceAll('{id}', fileKey);

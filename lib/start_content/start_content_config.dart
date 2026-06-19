/// Manifest remoto su GitHub (branch main della repo RomagnaGO).
///
/// L'app scarica i JSON da raw.githubusercontent.com; in CI GitHub Actions
/// esegue [tool/sync_start_content.dart] e fa commit se Start Romagna cambia.
///
/// Se il remoto non è raggiungibile: cache disco → asset nel bundle.
const String kStartContentGitHubOwner = 'gsplcu';
const String kStartContentGitHubRepo = 'RomagnaGO';
const String kStartContentGitHubBranch = 'main';
const String kStartContentGitHubContentPath = 'assets/data/start_content';

String get _githubRawBase =>
    'https://raw.githubusercontent.com/$kStartContentGitHubOwner'
    '/$kStartContentGitHubRepo/$kStartContentGitHubBranch'
    '/$kStartContentGitHubContentPath';

/// Manifest con hash dei pacchetti (guida il download selettivo).
String get kStartContentRemoteManifestUrl => '$_githubRawBase/manifest.json';

/// JSON remoto per fileKey (es. `biglietto_informazioni`).
String startContentRemoteJsonUrl(String fileKey, {String? cacheBust}) {
  final base = '$_githubRawBase/$fileKey.json';
  if (cacheBust == null || cacheBust.isEmpty) return base;
  return '$base?v=$cacheBust';
}

/// Intervallo minimo tra due tentativi di refresh per lo stesso pacchetto.
const Duration kStartContentRefreshMinInterval = Duration(hours: 6);

const Duration kStartContentHttpTimeout = Duration(seconds: 25);

const Map<String, String> kStartContentHttpHeaders = {
  'User-Agent': 'RomagnaGO/1.0 (+https://startromagna.it)',
  'Accept': 'application/json',
};

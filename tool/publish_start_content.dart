// Genera, sincronizza (opzionale) e carica start_content su Firebase Storage.
//
// Prerequisiti locali (una volta):
//   1. Google Cloud SDK: https://cloud.google.com/sdk/docs/install
//   2. gcloud auth application-default login
//      oppure export GOOGLE_APPLICATION_CREDENTIALS=/path/service-account.json
//   3. Service account con ruolo "Storage Object Admin" sul bucket.
//
// Uso:
//   dart run tool/publish_start_content.dart
//   dart run tool/publish_start_content.dart --no-sync    # solo upload
//   dart run tool/publish_start_content.dart --dry-run    # prova senza caricare
//
// In CI: vedi .github/workflows/publish-start-content.yml

import 'dart:io';

import 'start_content_storage.dart';

Future<void> main(List<String> args) async {
  final skipGen = args.contains('--no-gen');
  final skipSync = args.contains('--no-sync');
  final dryRun = args.contains('--dry-run');

  if (!skipGen) {
    stdout.writeln('→ gen baseline JSON');
    final code = await _runDart(['run', 'tool/gen_start_content_baseline.dart']);
    if (code != 0) exit(code);
  }

  if (!skipSync) {
    stdout.writeln('→ sync da web (parser disponibili)');
    final code = await _runDart(['run', 'tool/sync_start_content.dart']);
    if (code != 0) exit(code);
  }

  final local = Directory(kStartContentLocalDir);
  if (!await local.exists()) {
    stderr.writeln('Manca $kStartContentLocalDir — esegui gen_start_content_baseline.');
    exit(1);
  }
  if (!await File('$kStartContentLocalDir/manifest.json').exists()) {
    stderr.writeln('Manca manifest.json in $kStartContentLocalDir');
    exit(1);
  }

  stdout.writeln('→ upload verso $kStartContentGcsUri');
  final uploaded = await _uploadWithGcloud(dryRun: dryRun);
  if (!uploaded) {
    stderr.writeln('');
    stderr.writeln('Upload non eseguito. Opzioni:');
    stderr.writeln('  • Installa gcloud e ripeti questo comando');
    stderr.writeln('  • Oppure usa GitHub Actions (workflow publish-start-content)');
    exit(1);
  }

  stdout.writeln('✓ start_content pubblicato su Firebase Storage');
}

Future<int> _runDart(List<String> scriptArgs) async {
  final result = await Process.run('dart', scriptArgs, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  return result.exitCode;
}

Future<bool> _uploadWithGcloud({required bool dryRun}) async {
  final gcloud = await _findExecutable('gcloud');
  if (gcloud == null) return false;

  final rsyncArgs = [
    'storage',
    'rsync',
    '-r',
    if (dryRun) '-n',
    kStartContentLocalDir,
    kStartContentGcsUri,
  ];

  final rsync = await Process.run(gcloud, rsyncArgs, runInShell: true);
  stdout.write(rsync.stdout);
  stderr.write(rsync.stderr);
  if (rsync.exitCode != 0) {
    stderr.writeln('gcloud storage rsync fallito (exit ${rsync.exitCode})');
    return false;
  }

  if (dryRun) return true;

  // Content-Type corretto per download ?alt=media in app.
  final jsonFiles = Directory(kStartContentLocalDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));

  for (final file in jsonFiles) {
    final name = file.uri.pathSegments.last;
    final object = 'gs://$kStartContentStorageBucket/'
        '$kStartContentStoragePrefix/$name';
    final update = await Process.run(gcloud, [
      'storage',
      'objects',
      'update',
      object,
      '--content-type=application/json; charset=utf-8',
      '--cache-control=public,max-age=3600',
    ], runInShell: true);
    if (update.exitCode != 0) {
      stderr.write(update.stderr);
      stderr.writeln('metadata update fallita per $name');
      return false;
    }
  }

  return true;
}

Future<String?> _findExecutable(String name) async {
  if (Platform.isWindows) {
    final where = await Process.run('where', [name], runInShell: true);
    if (where.exitCode == 0) {
      final line = '${where.stdout}'.trim().split(RegExp(r'\r?\n')).first;
      if (line.isNotEmpty) return line;
    }
    return null;
  }
  final which = await Process.run('which', [name]);
  if (which.exitCode == 0) {
    final path = '${which.stdout}'.trim();
    if (path.isNotEmpty) return path;
  }
  return null;
}

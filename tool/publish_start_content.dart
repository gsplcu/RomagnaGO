// Sincronizza start_content in locale (stesso flusso della CI, senza commit).
//
//   dart run tool/publish_start_content.dart          # gen + sync
//   dart run tool/publish_start_content.dart --no-gen
//
// Per pubblicare in app: fai push dei JSON su GitHub (main).
// La CI giornaliera committa automaticamente se Start Romagna cambia.

import 'dart:io';

Future<void> main(List<String> args) async {
  final skipGen = args.contains('--no-gen');
  final skipSync = args.contains('--no-sync');

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

  stdout.writeln('');
  stdout.writeln('Fatto. Se ci sono modifiche in assets/data/start_content/:');
  stdout.writeln('  git add assets/data/start_content && git commit && git push');
  stdout.writeln('');
  stdout.writeln('L\'app scaricherà i JSON da GitHub al prossimo refresh.');
}

Future<int> _runDart(List<String> scriptArgs) async {
  final result = await Process.run('dart', scriptArgs, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  return result.exitCode;
}

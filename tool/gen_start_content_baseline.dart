// Genera assets/data/start_content/*.json e manifest.json dai baseline in lib/.
// dart run tool/gen_start_content_baseline.dart

import 'dart:convert';
import 'dart:io';

import 'package:RomagnaGO/start_content/baseline/start_content_baselines.dart';
import 'package:RomagnaGO/start_content/start_content_hash.dart';
import 'package:RomagnaGO/start_content/start_content_id.dart';
import 'package:RomagnaGO/start_content/start_content_manifest.dart';

const _outDir = 'assets/data/start_content';

Future<void> main() async {
  final dir = Directory(_outDir);
  if (!await dir.exists()) await dir.create(recursive: true);

  final entries = <StartContentManifestEntry>[];
  for (final id in StartContentId.values) {
    final baseline = baselineFor(id);
    if (baseline == null) {
      stdout.writeln('skip ${id.fileKey} (no baseline)');
      continue;
    }
    final hash = startContentPayloadHash(baseline);
    final path = '$_outDir/${id.fileKey}.json';
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(baseline),
    );
    entries.add(
      StartContentManifestEntry(
        id: id.fileKey,
        sourceUrl: id.sourceUrl,
        contentHash: hash,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    stdout.writeln('wrote $path ($hash)');
  }

  final manifest = StartContentManifest(
    version: 1,
    publishedAt: DateTime.now().toUtc().toIso8601String(),
    entries: entries,
  );
  await File('$_outDir/manifest.json').writeAsString(manifest.encode());
  stdout.writeln('manifest: ${entries.length} sources');
}

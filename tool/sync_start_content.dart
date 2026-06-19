// Sincronizza JSON Start da web (CI / manuale). In errore mantiene i file esistenti.
// dart run tool/sync_start_content.dart

import 'dart:convert';
import 'dart:io';

import 'package:RomagnaGO/start_content/baseline/start_content_baselines.dart';
import 'package:RomagnaGO/start_content/start_content_hash.dart';
import 'package:RomagnaGO/start_content/start_content_id.dart';
import 'package:RomagnaGO/start_content/start_content_manifest.dart';
import 'package:RomagnaGO/start_content/start_content_registry.dart';

const _outDir = 'assets/data/start_content';

Future<void> main() async {
  final dir = Directory(_outDir);
  if (!await dir.exists()) await dir.create(recursive: true);

  StartContentManifest? existing;
  final manifestFile = File('$_outDir/manifest.json');
  if (await manifestFile.exists()) {
    try {
      existing = StartContentManifest.decode(await manifestFile.readAsString());
    } catch (_) {}
  }

  final entries = <StartContentManifestEntry>[];
  for (final id in StartContentId.values) {
    final path = '$_outDir/${id.fileKey}.json';
    final file = File(path);

    Map<String, dynamic> current;
    if (await file.exists()) {
      current = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } else {
      current = baselineFor(id) ?? {};
    }
    if (current.isEmpty) {
      stdout.writeln('skip ${id.fileKey}: no baseline');
      continue;
    }

    final parser = startContentParserFor(id);
    var next = Map<String, dynamic>.from(current);
    if (parser != null) {
      try {
        final patch = await parser.fetchFromWeb();
        if (patch != null && patch.isNotEmpty) {
          next = _merge(next, patch);
          final err = parser.validate(next);
          if (err != null) {
            stdout.writeln('${id.fileKey}: validate failed ($err), keep file');
            next = current;
          } else {
            stdout.writeln('${id.fileKey}: updated from web');
          }
        } else {
          stdout.writeln('${id.fileKey}: web parse skipped, keep file');
        }
      } catch (e) {
        stdout.writeln('${id.fileKey}: error $e, keep file');
        next = current;
      }
    }

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(next),
    );
    entries.add(
      StartContentManifestEntry(
        id: id.fileKey,
        sourceUrl: id.sourceUrl,
        contentHash: startContentPayloadHash(next),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  final manifest = StartContentManifest(
    version: (existing?.version ?? 0) + 1,
    publishedAt: DateTime.now().toUtc().toIso8601String(),
    entries: entries,
  );
  await manifestFile.writeAsString(manifest.encode());
  stdout.writeln('manifest v${manifest.version} (${entries.length} sources)');
}

Map<String, dynamic> _merge(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  final out = Map<String, dynamic>.from(base);
  for (final e in patch.entries) {
    final v = e.value;
    final existing = out[e.key];
    if (v is Map<String, dynamic> && existing is Map<String, dynamic>) {
      out[e.key] = _merge(existing, v);
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

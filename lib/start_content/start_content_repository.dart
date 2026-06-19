import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'start_content_config.dart';
import 'start_content_hash.dart';
import 'start_content_id.dart';
import 'start_content_manifest.dart';
import 'start_content_registry.dart';

/// Caricamento contenuti Start con cache su disco, asset nel bundle e refresh opzionale.
class StartContentRepository {
  StartContentRepository._();

  static final StartContentRepository instance = StartContentRepository._();

  final Map<StartContentId, Map<String, dynamic>> _memory = {};
  final Map<StartContentId, DateTime> _lastRefreshAttempt = {};
  StartContentManifest? _localManifest;
  bool _diskReady = false;
  String? _cacheDir;

  static const _manifestFileName = 'manifest.json';

  Future<void> warmUp({bool tryRefresh = true}) async {
    await _ensureDisk();
    await _loadLocalManifest();
    if (tryRefresh) {
      unawaited(refreshAll(force: false));
    }
  }

  /// Contenuto per [id]: memoria → disco → bundle. Non lancia eccezioni.
  Future<Map<String, dynamic>> load(StartContentId id) async {
    if (_memory.containsKey(id)) return Map<String, dynamic>.from(_memory[id]!);

    await _ensureDisk();

    final disk = await _readDisk(id);
    if (disk != null) {
      _memory[id] = disk;
      return Map<String, dynamic>.from(disk);
    }

    final bundled = await _readBundled(id);
    _memory[id] = bundled;
    return Map<String, dynamic>.from(bundled);
  }

  /// Refresh in background: remoto → parser web. In errore mantiene cache esistente.
  Future<void> refreshAll({bool force = false}) async {
    await _ensureDisk();
    await _loadLocalManifest();

    await _tryRefreshRemoteManifest(force: force);

    for (final id in StartContentId.values) {
      await refreshOne(id, force: force);
    }
  }

  Future<void> refreshOne(StartContentId id, {bool force = false}) async {
    await _ensureDisk();

    if (!force) {
      final last = _lastRefreshAttempt[id];
      if (last != null &&
          DateTime.now().difference(last) < kStartContentRefreshMinInterval) {
        return;
      }
    }
    _lastRefreshAttempt[id] = DateTime.now();

    // 1) Remoto da manifest (JSON già normalizzato da CI)
    final remote = await _tryDownloadRemoteJson(id);
    if (remote != null) {
      final err = _validate(id, remote);
      if (err == null) {
        await _commit(id, remote);
        return;
      }
    }

    // 2) Parser diretto dal sito
    final parser = startContentParserFor(id);
    if (parser == null) return;

    try {
      final parsed = await parser.fetchFromWeb();
      if (parsed == null) return;

      final current = await load(id);
      final merged = _deepMerge(current, parsed);
      final err = parser.validate(merged);
      if (err != null) return;

      await _commit(id, merged);
    } catch (_) {
      // Mantieni cache esistente.
    }
  }

  Future<void> _commit(StartContentId id, Map<String, dynamic> json) async {
    final hash = startContentPayloadHash(json);
    final entry = StartContentManifestEntry(
      id: id.fileKey,
      sourceUrl: id.sourceUrl,
      contentHash: hash,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );

    _memory[id] = Map<String, dynamic>.from(json);
    await _writeDisk(id, json);

    final entries = {
      for (final e in _localManifest?.entries ?? const <StartContentManifestEntry>[])
        e.id: e,
    };
    entries[id.fileKey] = entry;
    _localManifest = StartContentManifest(
      version: (_localManifest?.version ?? 0) + 1,
      publishedAt: DateTime.now().toUtc().toIso8601String(),
      entries: entries.values.toList(),
    );
    await _writeLocalManifest();
  }

  String? _validate(StartContentId id, Map<String, dynamic> json) {
    return startContentParserFor(id)?.validate(json);
  }

  Future<void> _ensureDisk() async {
    if (_diskReady) return;
    if (kIsWeb) {
      _diskReady = true;
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = '${dir.path}/start_content';
    await Directory(_cacheDir!).create(recursive: true);
    _diskReady = true;
  }

  Future<void> _loadLocalManifest() async {
    if (_cacheDir == null) {
      _localManifest = await _readBundledManifest();
      return;
    }
    final file = File('$_cacheDir/$_manifestFileName');
    if (await file.exists()) {
      try {
        _localManifest = StartContentManifest.decode(await file.readAsString());
        return;
      } catch (_) {}
    }
    _localManifest = await _readBundledManifest();
  }

  Future<void> _writeLocalManifest() async {
    if (_cacheDir == null || _localManifest == null) return;
    final file = File('$_cacheDir/$_manifestFileName');
    await file.writeAsString(_localManifest!.encode());
  }

  Future<StartContentManifest?> _readBundledManifest() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/start_content/manifest.json',
      );
      return StartContentManifest.decode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readDisk(StartContentId id) async {
    if (_cacheDir == null) return null;
    final file = File('$_cacheDir/${id.fileKey}.json');
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(StartContentId id, Map<String, dynamic> json) async {
    if (_cacheDir == null) return;
    final file = File('$_cacheDir/${id.fileKey}.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  Future<Map<String, dynamic>> _readBundled(StartContentId id) async {
    final raw = await rootBundle.loadString(id.bundledAsset);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _tryRefreshRemoteManifest({required bool force}) async {
    if (kStartContentRemoteManifestUrl.isEmpty) return;
    try {
      final uri = Uri.parse(kStartContentRemoteManifestUrl).replace(
        queryParameters: force
            ? {'t': '${DateTime.now().toUtc().millisecondsSinceEpoch}'}
            : null,
      );
      final res = await http
          .get(uri, headers: kStartContentHttpHeaders)
          .timeout(kStartContentHttpTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final remote = StartContentManifest.decode(res.body);
      final localHash = _localManifest?.encode() ?? '';
      final remoteHash = remote.encode();
      if (!force && localHash == remoteHash) return;
      // Il manifest remoto guida i download per singolo file.
      _localManifest = remote;
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _tryDownloadRemoteJson(StartContentId id) async {
    final entry = _localManifest?.entryFor(id);
    final localDisk = await _readDisk(id);
    if (entry != null && localDisk != null) {
      final localHash = startContentPayloadHash(localDisk);
      if (localHash == entry.contentHash) return null;
    }

    try {
      final url = startContentRemoteJsonUrl(
        id.fileKey,
        cacheBust: entry?.contentHash,
      );
      final res = await http
          .get(Uri.parse(url), headers: kStartContentHttpHeaders)
          .timeout(kStartContentHttpTimeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _deepMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  final out = Map<String, dynamic>.from(base);
  for (final e in patch.entries) {
    final v = e.value;
    final existing = out[e.key];
    if (v is Map<String, dynamic> && existing is Map<String, dynamic>) {
      out[e.key] = _deepMerge(existing, v);
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

void unawaited(Future<void> f) {}

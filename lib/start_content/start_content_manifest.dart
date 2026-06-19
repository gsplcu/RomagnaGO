import 'dart:convert';

import 'start_content_id.dart';

class StartContentManifestEntry {
  const StartContentManifestEntry({
    required this.id,
    required this.sourceUrl,
    required this.contentHash,
    this.updatedAt,
  });

  final String id;
  final String sourceUrl;
  final String contentHash;
  final String? updatedAt;

  factory StartContentManifestEntry.fromJson(Map<String, dynamic> j) {
    return StartContentManifestEntry(
      id: j['id'] as String,
      sourceUrl: j['sourceUrl'] as String? ?? '',
      contentHash: j['contentHash'] as String? ?? '',
      updatedAt: j['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceUrl': sourceUrl,
    'contentHash': contentHash,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}

class StartContentManifest {
  const StartContentManifest({
    required this.version,
    required this.entries,
    this.publishedAt,
  });

  final int version;
  final String? publishedAt;
  final List<StartContentManifestEntry> entries;

  StartContentManifestEntry? entryFor(StartContentId id) {
    for (final e in entries) {
      if (e.id == id.fileKey) return e;
    }
    return null;
  }

  factory StartContentManifest.fromJson(Map<String, dynamic> j) {
    final raw = j['sources'] ?? j['entries'];
    final list = raw is List ? raw : const [];
    return StartContentManifest(
      version: j['version'] is int
          ? j['version'] as int
          : int.tryParse('${j['version']}') ?? 1,
      publishedAt: j['publishedAt'] as String?,
      entries: [
        for (final item in list)
          if (item is Map<String, dynamic>)
            StartContentManifestEntry.fromJson(item),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    if (publishedAt != null) 'publishedAt': publishedAt,
    'sources': entries.map((e) => e.toJson()).toList(),
  };

  static StartContentManifest decode(String raw) =>
      StartContentManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

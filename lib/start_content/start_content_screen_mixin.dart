import 'dart:async';

import 'package:flutter/material.dart';

import 'start_content_id.dart';
import 'start_content_json.dart';
import 'start_content_repository.dart';

/// Carica contenuto Start con refresh opzionale; in errore usa cache/bundle.
mixin StartContentScreenMixin<T extends StatefulWidget> on State<T> {
  StartContentId get startContentId;

  Map<String, dynamic>? _content;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final id = startContentId;
    try {
      unawaited(StartContentRepository.instance.refreshOne(id));
      final json = await StartContentRepository.instance.load(id);
      if (!mounted) return;
      setState(() {
        _content = json;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get content =>
      _content ?? const <String, dynamic>{};

  bool get contentLoading => _loading;

  Map<String, dynamic> contentSection(String key) =>
      scMap(content, key) ?? const {};

  List<Map<String, String>> fareRows(String key) => scFareRows(content, key);

  List<Map<String, String>> fareRowsIn(
    Map<String, dynamic> section,
    String key,
  ) =>
      scFareRows(section, key);

  List<String> stringList(String key) => scStringList(content, key);

  List<String> stringListIn(Map<String, dynamic> section, String key) =>
      scStringList(section, key);

  String contentString(String key, {String fallback = ''}) =>
      scText(content, key, fallback: fallback);
}

/// Carica più pacchetti Start sulla stessa schermata.
mixin StartContentMultiMixin<T extends StatefulWidget> on State<T> {
  List<StartContentId> get startContentIds;

  final Map<StartContentId, Map<String, dynamic>> _contents = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      for (final id in startContentIds) {
        unawaited(StartContentRepository.instance.refreshOne(id));
      }
      await Future.wait([
        for (final id in startContentIds)
          StartContentRepository.instance.load(id).then((json) {
            _contents[id] = json;
          }),
      ]);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  bool get contentLoading => _loading;

  Map<String, dynamic> contentFor(StartContentId id) =>
      _contents[id] ?? const <String, dynamic>{};
}
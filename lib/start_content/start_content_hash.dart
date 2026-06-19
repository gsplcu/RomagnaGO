import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Hash stabile del payload JSON (chiavi ordinate, senza metadati di sync).
String startContentPayloadHash(Map<String, dynamic> json) {
  final copy = Map<String, dynamic>.from(json)
    ..remove('_meta');
  final canonical = jsonEncode(_canonicalize(copy));
  return sha256.convert(utf8.encode(canonical)).toString();
}

dynamic _canonicalize(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canonicalize(value[k])};
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

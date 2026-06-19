import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> main() async {
  const target = 'https://www.startromagna.it/trova-zona-3/';
  for (final name in ['corsproxy', 'allorigins']) {
    final Uri uri;
    if (name == 'corsproxy') {
      uri = Uri.parse('https://corsproxy.io/?${Uri.encodeComponent(target)}');
    } else {
      uri = Uri.parse(
        'https://api.allorigins.win/get?url=${Uri.encodeComponent(target)}',
      );
    }
    final res = await http.get(uri);
    var body = res.body;
    if (name == 'allorigins' && res.statusCode == 200) {
      final j = jsonDecode(body) as Map<String, dynamic>;
      body = j['contents'] as String? ?? '';
    }
    print('$name: ${res.statusCode} len=${body.length} fc=${body.contains('select_trova_zona_fc')}');
  }
}

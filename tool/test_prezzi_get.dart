import 'package:http/http.dart' as http;

import '../lib/start_trova_zona_api.dart';

Future<void> main() async {
  final uri = Uri.parse(kStartRomagnaAjaxUrl).replace(
    queryParameters: {
      'action': 'get_zone_prezzi',
      'partenza': '884',
      'arrivo': '860',
    },
  );
  final res = await http.get(uri, headers: kStartTrovaZonaHeaders);
  print('GET prezzi: ${res.statusCode}');
  print(res.body.substring(0, res.body.length.clamp(0, 400)));
}

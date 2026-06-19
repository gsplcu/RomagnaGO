import 'package:http/http.dart' as http;

import '../lib/start_trova_zona_api.dart';

Future<void> main() async {
  final uri = Uri.parse(kStartRomagnaAjaxUrl).replace(
    queryParameters: {'action': 'gat_zone_da_zona', 'codice': '884', 'bacino': '4'},
  );
  final res = await http.get(uri, headers: kStartTrovaZonaHeaders);
  print(res.body.substring(0, 800));
}

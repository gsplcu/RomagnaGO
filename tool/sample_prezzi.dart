import 'package:http/http.dart' as http;

import '../lib/start_trova_zona_api.dart';

Future<void> main() async {
  final c = http.Client();
  final r = await fetchZonePrezzi(
    partenza: '884',
    arrivo: '860',
    bacino: TrovaZonaBacino.fc,
    client: c,
  );
  print('zone=${r.zoneAttraversate}');
  for (final row in r.righe) {
    print('${row.descrizione} | ${row.validita} | ${row.prezzo}');
  }
  c.close();
}

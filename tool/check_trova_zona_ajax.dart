import '../lib/start_trova_zona_api.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final client = http.Client();
  try {
    final m = await fetchTrovaZonaPartenze(client: client);
    final fc = m[TrovaZonaBacino.fc]!.first;
    print('partenza sample: ${fc.label} (${fc.code})');
    final arr = await fetchZoneArrivo(
      codicePartenza: fc.code,
      bacino: TrovaZonaBacino.fc,
      client: client,
    );
    print('arrivi: ${arr.length}');
    if (arr.length > 2) {
      final prezzi = await fetchZonePrezzi(
        partenza: fc.code,
        arrivo: arr[2].code,
        bacino: TrovaZonaBacino.fc,
        client: client,
      );
      print('zone: ${prezzi.zoneAttraversate}, righe: ${prezzi.righe.length}');
    }
  } finally {
    client.close();
  }
}

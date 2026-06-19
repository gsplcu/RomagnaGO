import 'package:http/http.dart' as http;
import '../lib/start_trova_zona_api.dart';

Future<void> main() async {
  final res = await http.get(
    Uri.parse(kStartTrovaZonaPageUrl),
    headers: kStartTrovaZonaHeaders,
  );
  print('status: ${res.statusCode}');
  final m = parseZonePartenzaFromPage(res.body);
  for (final b in TrovaZonaBacino.values) {
    print('${b.label}: ${m[b]?.length ?? 0} zone');
  }
}

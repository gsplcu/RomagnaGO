import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Ravenna → Rimini non crasha e suggerisce treno', () async {
    final svc = await PercorsoSearchService.load();
    expect(svc, isNotNull);

    const ravenna = LatLng(44.4171, 12.2012);
    const rimini = LatLng(44.0594, 12.5683);

    final result = await svc!.planDetailed(
      from: const PercorsoEndpoint(label: 'Ravenna', point: ravenna),
      to: const PercorsoEndpoint(label: 'Rimini', point: rimini),
      departAt: DateTime(2026, 6, 15, 10, 0),
      profile: PercorsoProfile.fastest,
    );

    expect(result.itineraries, isNotEmpty);
    expect(result.suggestTrain, isTrue);
    expect(result.userHint, isNotNull);
  }, timeout: const Timeout(Duration(seconds: 15)));
}

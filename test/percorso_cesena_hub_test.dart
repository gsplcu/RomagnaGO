import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Cesenatico -> Santa Sofia uses Cesena hub 94 then 92', () async {
    final svc = await PercorsoSearchService.load();
    expect(svc, isNotNull);
    const from = LatLng(44.1944465362708, 12.4018502577375);
    const to = LatLng(43.9476125586956, 11.9082208395099);
    final r = await svc!.planDetailed(
      from: const PercorsoEndpoint(label: 'Cesenatico', point: from),
      to: const PercorsoEndpoint(label: 'Santa Sofia', point: to),
      departAt: DateTime(2026, 6, 16, 9, 0),
      profile: PercorsoProfile.fastest,
    );
    expect(r.hasTransit, isTrue);
    final rides = r.itineraries.first.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.lineLabel ?? '')
        .join(',');
    expect(rides.contains('94'), isTrue, reason: rides);
    expect(rides.contains('92'), isTrue, reason: rides);
    expect(rides.contains('132'), isTrue, reason: rides);
    expect(rides.contains('93'), isFalse, reason: rides);
    expect(rides.contains('133'), isFalse, reason: rides);
    expect(
      r.itineraries.first.totalDuration.inMinutes,
      lessThan(360),
      reason: 'dur=${r.itineraries.first.totalDuration.inMinutes}m',
    );
  });
}

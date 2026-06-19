import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:RomagnaGO/percorso/percorso_shapes.dart';
import 'package:RomagnaGO/percorso/percorso_walk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PercorsoSearchService svc;

  setUpAll(() async {
    svc = (await PercorsoSearchService.load())!;
  });

  test('F126 Gatteo Mare → Zadina shape follows travel direction', () async {
    const gatteo = LatLng(44.1730044004041, 12.4352937073703);
    const zadinaDest = LatLng(44.2210475341269, 12.380355066799);
    const zadinaStop = LatLng(44.2181613193626, 12.3772291891894);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|F126',
      from: gatteo,
      to: zadinaDest,
      boardStopId: '11800',
      alightStopId: '11772',
    );

    expect(pts.length, greaterThan(4));
    const dist = Distance();
    expect(pts.last.latitude - pts.first.latitude, greaterThan(0));
    expect(
      dist.as(LengthUnit.Meter, gatteo, pts.first),
      lessThan(dist.as(LengthUnit.Meter, gatteo, pts.last)),
    );
    expect(dist.as(LengthUnit.Meter, zadinaStop, pts.last), lessThan(280));
    expect(dist.as(LengthUnit.Meter, gatteo, pts.first), lessThan(120));
    expect(_lastSegment(pts), lessThan(280));
    expect(_maxSegment(pts), lessThan(720));
  });

  test('Gatteo Mare → Zadina alights at Via Mosca not Campeggi', () async {
    const gatteo = LatLng(44.1730044004041, 12.4352937073703);
    const zadina = LatLng(44.2210475341269, 12.380355066799);
    final r = await svc.planDetailed(
      from: const PercorsoEndpoint(label: 'Gatteo Mare', point: gatteo),
      to: const PercorsoEndpoint(label: 'Zadina', point: zadina),
      departAt: DateTime(2026, 6, 15, 14, 0),
      profile: PercorsoProfile.fastest,
    );
    expect(r.hasTransit, isTrue);
    final ride = r.itineraries.first.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .last;
    expect(
      ride.alightStopId == '11771' || ride.alightStopId == '11772',
      isTrue,
      reason: 'alight=${ride.alightStopId}',
    );
    expect(ride.alightStopId, isNot('10861'));
    expect(ride.alightStopId, isNot('10862'));

    var egress = 0.0;
    for (final l in r.itineraries.first.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.from != null &&
          l.to != null &&
          !l.title.contains('Cambio')) {
        egress += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    expect(egress, lessThan(600));
  });
}

double _lastSegment(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const dist = Distance();
  return dist.as(LengthUnit.Meter, pts[pts.length - 2], pts.last);
}

double _maxSegment(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const dist = Distance();
  var maxSeg = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final seg = dist.as(LengthUnit.Meter, pts[i - 1], pts[i]);
    if (seg > maxSeg) maxSeg = seg;
  }
  return maxSeg;
}

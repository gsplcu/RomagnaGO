import 'package:RomagnaGO/percorso/percorso_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('2CO returns enough map points', () async {
    const from = LatLng(44.1999643171576, 12.4005967675276);
    const to = LatLng(44.2020421092627, 12.3946303292486);
    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: from,
      to: to,
    );
    expect(pts.length, greaterThanOrEqualTo(2));
    const dist = Distance();
    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, from, to);
    expect(path, greaterThan(direct * 0.5));
    expect(path, lessThan(direct * 2.6));
    expect(_maxSegment(pts), lessThan(direct * 1.05));
  });

  test('S094 Saffi-Donizetti → Bv.Cannuceto uses short urban GPX', () async {
    const from = LatLng(44.196426476595, 12.3984934094714);
    const to = LatLng(44.1952574896653, 12.3895932343068);
    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|S094',
      from: from,
      to: to,
    );
    const dist = Distance();
    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, from, to);
    expect(pts.length, greaterThanOrEqualTo(2));
    expect(path, lessThan(direct * 2.2));
    expect(path, greaterThan(direct * 0.5));
    expect(_maxSegment(pts), lessThan(direct * 0.95));
  });

  test('S094 Cesenatico → Cesena follows travel direction', () async {
    const cesenatico = LatLng(44.1999283, 12.3969692);
    const cesena = LatLng(44.1363520, 12.2422442);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|S094',
      from: cesenatico,
      to: cesena,
    );

    expect(pts.length, greaterThan(10));
    const dist = Distance();
    final travelLat = cesena.latitude - cesenatico.latitude;
    final sliceLat = pts.last.latitude - pts.first.latitude;
    expect(travelLat, lessThan(0));
    expect(sliceLat, lessThan(0));

    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, cesenatico, cesena);
    expect(path, greaterThan(direct * 0.85));
    expect(_maxSegment(pts), lessThan(direct * 0.12));
  });

  test('3CO Celle → Cesenatico (P. Comandini) avoids straight fallback', () async {
    const celle = LatLng(44.1572834420996, 12.3935819536724);
    const comandini = LatLng(44.1987074789226, 12.4005533391186);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|3CO',
      from: celle,
      to: comandini,
      tripId: '833_1086269',
      boardStopId: '30220',
      alightStopId: '10721',
    );

    expect(pts.length, greaterThanOrEqualTo(4));
    const dist = Distance();
    final direct = dist.as(LengthUnit.Meter, celle, comandini);
    final path = _polylineLength(pts);
    expect(path, greaterThan(direct * 1.05));
    expect(_maxSegment(pts), lessThan(direct * 0.35));
    expect(dist.as(LengthUnit.Meter, comandini, pts.last), lessThan(350));
  });
}

double _polylineLength(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const dist = Distance();
  var sum = 0.0;
  for (var i = 1; i < pts.length; i++) {
    sum += dist.as(LengthUnit.Meter, pts[i - 1], pts[i]);
  }
  return sum;
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

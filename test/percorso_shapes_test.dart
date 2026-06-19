import 'package:RomagnaGO/percorso/percorso_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('line 201 Tagliata → Milano Marittima follows travel direction', () async {
    const tagliata = LatLng(44.2237721617758, 12.3759016646437);
    const milano = LatLng(44.2771926256671, 12.3512768198668);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'RA|201',
      from: tagliata,
      to: milano,
      tripId: '674_2795934',
      boardStopId: '733080',
      alightStopId: '734100',
    );

    expect(pts.length, greaterThan(2));
    for (final p in pts) {
      expect(p.latitude.isFinite, isTrue);
      expect(p.longitude.isFinite, isTrue);
    }

    const dist = Distance();
    final startErr = dist.as(LengthUnit.Meter, tagliata, pts.first);
    final endErr = dist.as(LengthUnit.Meter, milano, pts.last);
    expect(startErr, lessThan(120));
    expect(endErr, lessThan(350));
    expect(_lastSegment(pts), lessThan(350));

    final travelLat = milano.latitude - tagliata.latitude;
    final sliceLat = pts.last.latitude - pts.first.latitude;
    expect(travelLat * sliceLat, greaterThan(0));
  });

  test('line 201 rejects Lido di Classe → Tagliata when traveling inland', () async {
    const tagliata = LatLng(44.2237721617758, 12.3759016646437);
    const milano = LatLng(44.2771926256671, 12.3512768198668);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'RA|201',
      from: tagliata,
      to: milano,
    );

    const dist = Distance();
    final sliceLat = pts.last.latitude - pts.first.latitude;
    final travelLat = milano.latitude - tagliata.latitude;
    expect(sliceLat, greaterThan(0));
    expect(travelLat, greaterThan(0));
    expect(
      dist.as(LengthUnit.Meter, tagliata, pts.first),
      lessThan(dist.as(LengthUnit.Meter, tagliata, pts.last)),
    );
  });

  test('line 2CO L. Da Vinci → Darsena uses short porto-canale GPX', () async {
    const daVinci = LatLng(44.1999643171576, 12.4005967675276);
    const darsena = LatLng(44.2020421092627, 12.3946303292486);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: daVinci,
      to: darsena,
    );

    expect(pts.length, greaterThanOrEqualTo(2));
    const dist = Distance();
    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, daVinci, darsena);
    expect(path, lessThan(direct * 2.5));
    expect(path, greaterThan(direct * 0.5));
    expect(_maxSegment(pts), lessThan(direct * 1.05));
    expect(dist.as(LengthUnit.Meter, darsena, pts.last), lessThan(550));
  });

  test('FC F165 Gatteo Mare → Scuole El. Dante follows road GPX', () async {
    const gatteo = LatLng(44.1730044004041, 12.4352937073703);
    const dante = LatLng(44.0936985635194, 12.401395990985);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|F165',
      from: gatteo,
      to: dante,
    );

    expect(pts.length, greaterThan(20));
    const dist = Distance();
    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, gatteo, dante);
    expect(path, greaterThan(direct * 0.95));
    expect(_maxSegment(pts), lessThan(direct * 0.12));
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

double _polylineLength(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const dist = Distance();
  var sum = 0.0;
  for (var i = 1; i < pts.length; i++) {
    sum += dist.as(LengthUnit.Meter, pts[i - 1], pts[i]);
  }
  return sum;
}

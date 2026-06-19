import 'package:RomagnaGO/percorso/percorso_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('2CO Cesenatico (P.To Canale) → Zadina follows travel direction', () async {
    const cesenatico = LatLng(44.2023335760511, 12.3986565374992);
    const zadina = LatLng(44.2210475341269, 12.380355066799);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: cesenatico,
      to: zadina,
      tripId: '833_1086543',
      boardStopId: '30111',
      alightStopId: '30090',
    );

    expect(pts.length, greaterThan(4));
    const dist = Distance();
    final travelLat = zadina.latitude - cesenatico.latitude;
    final sliceLat = pts.last.latitude - pts.first.latitude;
    expect(travelLat, greaterThan(0));
    expect(sliceLat, greaterThan(0));

    expect(
      dist.as(LengthUnit.Meter, cesenatico, pts.first),
      lessThan(dist.as(LengthUnit.Meter, cesenatico, pts.last)),
    );
    expect(dist.as(LengthUnit.Meter, zadina, pts.last), lessThan(500));
    expect(_lastSegment(pts), lessThan(250));
  });

  test('2CO trip 08:59 Cesenatico → Zadina uses correct GPX direction', () async {
    const cesenatico = LatLng(44.2023660348951, 12.39841670666);
    const zadina = LatLng(44.2210475341269, 12.380355066799);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: cesenatico,
      to: zadina,
      tripId: '833_1086543',
      boardStopId: '30111',
      alightStopId: '30090',
    );

    expect(pts.length, greaterThan(4));
    const dist = Distance();
    expect(pts.last.latitude - pts.first.latitude, greaterThan(0));
    expect(
      dist.as(LengthUnit.Meter, cesenatico, pts.first),
      lessThan(dist.as(LengthUnit.Meter, cesenatico, zadina)),
    );
  });

  test('2CO Stazione Cesenatico → Zadina follows travel direction', () async {
    const stazione = LatLng(44.2010692509683, 12.3923788846493);
    const zadina = LatLng(44.2210475341269, 12.380355066799);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: stazione,
      to: zadina,
      tripId: '833_1086543',
      boardStopId: '10712',
      alightStopId: '30090',
    );

    expect(pts.length, greaterThan(3));
    const dist = Distance();
    expect(pts.last.latitude - pts.first.latitude, greaterThan(0));
    expect(
      dist.as(LengthUnit.Meter, stazione, pts.first),
      lessThan(dist.as(LengthUnit.Meter, stazione, pts.last)),
    );
  });

  test('2CO Zadina → Cesenatico (P.To Canale) follows travel direction', () async {
    const cesenatico = LatLng(44.2023335760511, 12.3986565374992);
    const zadina = LatLng(44.2210475341269, 12.380355066799);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|2CO',
      from: zadina,
      to: cesenatico,
    );

    expect(pts.length, greaterThan(4));
    const dist = Distance();
    final travelLat = cesenatico.latitude - zadina.latitude;
    final sliceLat = pts.last.latitude - pts.first.latitude;
    expect(travelLat, lessThan(0.0001));
    expect(sliceLat, lessThan(0.0001));

    expect(
      dist.as(LengthUnit.Meter, zadina, pts.first),
      lessThan(dist.as(LengthUnit.Meter, zadina, pts.last)),
    );
    expect(dist.as(LengthUnit.Meter, cesenatico, pts.last), lessThan(280));
    expect(_lastSegment(pts), lessThan(250));
  });
}

double _lastSegment(List<LatLng> pts) {
  if (pts.length < 2) return 0;
  const dist = Distance();
  return dist.as(LengthUnit.Meter, pts[pts.length - 2], pts.last);
}

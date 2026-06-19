import 'package:RomagnaGO/percorso/percorso_shapes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CE03 Barriera Terminal → Largo Virgilio draws road shape', () async {
    const barriera = LatLng(44.1390379257514, 12.2469797221223);
    const virgilio = LatLng(44.142253941682, 12.2541394064578);

    final pts = await PercorsoShapeCache.pointsForRideLeg(
      routeKey: 'FC|CE03',
      from: barriera,
      to: virgilio,
      tripId: '818_trip_ce03_test',
      boardStopId: '5120',
      alightStopId: '5211',
    );

    expect(pts.length, greaterThan(10));
    const dist = Distance();
    final path = _polylineLength(pts);
    final direct = dist.as(LengthUnit.Meter, barriera, virgilio);
    expect(path, greaterThan(direct * 0.9));
    expect(path, lessThan(direct * 5.0));
    expect(_maxSegment(pts), lessThan(direct * 0.5));
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

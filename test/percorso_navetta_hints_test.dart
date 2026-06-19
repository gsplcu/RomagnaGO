import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:RomagnaGO/percorso/percorso_navetta_hints.dart';

void main() {
  test('navettaCesenaticoIsActiveAt sabato estate in fascia', () {
    final sat = DateTime(2026, 7, 11, 10, 0);
    expect(navettaCesenaticoIsActiveAt(sat), isTrue);
  });

  test('navettaCesenaticoIsActiveAt feriale escluso', () {
    final mon = DateTime(2026, 7, 13, 10, 0);
    expect(navettaCesenaticoIsActiveAt(mon), isFalse);
  });

  test('bussiIsActiveAt mattina estiva', () {
    final d = DateTime(2026, 7, 10, 9, 0);
    expect(bussiIsActiveAt(d), isTrue);
  });

  test('bussiIsActiveAt pausa pranzo esclusa', () {
    final d = DateTime(2026, 7, 10, 13, 0);
    expect(bussiIsActiveAt(d), isFalse);
  });

  test('minDistanceToPolylineMeters su segmento', () {
    const a = LatLng(44.0, 12.0);
    const b = LatLng(44.01, 12.0);
    const p = LatLng(44.005, 12.0);
    final d = minDistanceToPolylineMeters(p, [a, b]);
    expect(d, lessThan(50));
  });
}

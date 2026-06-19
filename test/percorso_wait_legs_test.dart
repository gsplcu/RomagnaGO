import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapsePercorsoWaitLegs merges consecutive waits', () {
    final start = DateTime(2026, 5, 27, 7, 0);
    final mid = DateTime(2026, 5, 27, 7, 3);
    final end = DateTime(2026, 5, 27, 7, 12);

    final merged = collapsePercorsoWaitLegs([
      PercorsoLeg(
        kind: PercorsoLegKind.wait,
        title: 'Attesa cambio',
        subtitle: 'Minimo 3 min',
        start: start,
        end: mid,
      ),
      PercorsoLeg(
        kind: PercorsoLegKind.wait,
        title: 'Attesa',
        subtitle: '9 min',
        start: mid,
        end: end,
      ),
      const PercorsoLeg(
        kind: PercorsoLegKind.ride,
        title: 'Linea 2',
        subtitle: 'A → B',
      ),
    ]);

    expect(merged.length, 2);
    expect(merged.first.kind, PercorsoLegKind.wait);
    expect(merged.first.title, 'Attesa');
    expect(merged.first.start, start);
    expect(merged.first.end, end);
    expect(merged.first.subtitle, '12 min');
  });
}

import 'package:RomagnaGO/percorso/route_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ev = RouteEvaluator.standard;

  group('Regola 1 - costo Pareto-ottimale', () {
    test('penalità fissa 15 min per cambio', () {
      expect(ev.transferPenalty.inMinutes, 15);
      expect(ev.boardingTransferPenalty.inMinutes, 2);
      expect(ev.transferPenaltyMinutes(0), 0);
      expect(ev.transferPenaltyMinutes(1), 15);
      expect(ev.transferPenaltyMinutes(2), 30);
    });

    test('linea diretta più lenta vince su 1 cambio più veloce entro 15 min',
        () {
      final diretta = ev.cost(
        travelTime: const Duration(minutes: 70),
        walkMeters: 200,
        transferCount: 0,
      );
      final unCambio = ev.cost(
        travelTime: const Duration(minutes: 60),
        walkMeters: 200,
        transferCount: 1,
      );
      // 70 < 60 + 15 → la diretta (più lenta di 10') resta preferibile.
      expect(diretta, lessThan(unCambio));
    });

    test('se il cambio fa risparmiare oltre la penalità, vince il cambio', () {
      final diretta = ev.cost(
        travelTime: const Duration(minutes: 120),
        walkMeters: 200,
        transferCount: 0,
      );
      final unCambio = ev.cost(
        travelTime: const Duration(minutes: 60),
        walkMeters: 200,
        transferCount: 1,
      );
      expect(unCambio, lessThan(diretta));
    });
  });

  group('Regola 2 - walk progressiva', () {
    test('accesso/egress ≤ 1000 m', () {
      expect(ev.accessEgressWalkAllowed(900), isTrue);
      expect(ev.accessEgressWalkAllowed(1000), isTrue);
      expect(ev.accessEgressWalkAllowed(1001), isFalse);
    });

    test('interscambio intermedio ≤ 300 m', () {
      expect(ev.intermediateTransferWalkAllowed(300), isTrue);
      expect(ev.intermediateTransferWalkAllowed(301), isFalse);
    });
  });

  group('Regola 3 - massimizzazione di bordo', () {
    test('a parità di arrivo, più cammino di uscita è dominato', () {
      expect(
        ev.dominatedByBoardMaximization(
          candidateArriveSec: 36000,
          candidateEgressWalkMeters: 600,
          incumbentArriveSec: 36030,
          incumbentEgressWalkMeters: 50,
        ),
        isTrue,
      );
    });

    test('arrivi non pari: nessuna dominanza di bordo', () {
      expect(
        ev.dominatedByBoardMaximization(
          candidateArriveSec: 36000,
          candidateEgressWalkMeters: 600,
          incumbentArriveSec: 40000,
          incumbentEgressWalkMeters: 50,
        ),
        isFalse,
      );
    });

    test('differenza di cammino piccola: non dominato', () {
      expect(
        ev.dominatedByBoardMaximization(
          candidateArriveSec: 36000,
          candidateEgressWalkMeters: 180,
          incumbentArriveSec: 36000,
          incumbentEgressWalkMeters: 100,
        ),
        isFalse,
      );
    });
  });
}

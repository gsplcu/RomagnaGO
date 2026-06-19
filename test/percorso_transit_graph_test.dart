import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:RomagnaGO/percorso/percorso_constants.dart';
import 'package:RomagnaGO/percorso/percorso_stop_areas.dart';
import 'package:RomagnaGO/percorso/percorso_transfer_graph.dart';
import 'package:RomagnaGO/percorso/percorso_transit_graph.dart';
import 'package:RomagnaGO/percorso/route_evaluator.dart';
import 'package:RomagnaGO/transit_stops.dart';

TransitStopPin _pin({
  required String id,
  required String name,
  required LatLng point,
  String comune = 'Test (FC)',
  String basin = 'fc',
}) {
  return TransitStopPin(
    stopId: id,
    stopName: name,
    point: point,
    comune: comune,
    basin: basin,
  );
}

void main() {
  group('StopAreaIndex', () {
    test('unisce fermate entro 60 m', () {
      final a = _pin(
        id: 'A',
        name: 'Alpha',
        point: const LatLng(44.0, 12.0),
      );
      final b = _pin(
        id: 'B',
        name: 'Beta',
        point: const LatLng(44.0004, 12.0001),
      );
      final idx = StopAreaIndex.build([a, b]);
      expect(idx.areaCount, 1);
      expect(idx.sameArea('A', 'B'), isTrue);
    });

    test('unisce stesso nome e comune anche oltre 60 m', () {
      final a = _pin(
        id: '10821',
        name: 'Stazione Test',
        point: const LatLng(44.0, 12.0),
        comune: 'Cesena (FC)',
      );
      final b = _pin(
        id: '10822',
        name: 'Stazione Test',
        point: const LatLng(44.0012, 12.0),
        comune: 'Cesena (FC)',
      );
      final idx = StopAreaIndex.build([a, b]);
      expect(idx.sameArea('10821', '10822'), isTrue);
    });
  });

  group('TransferEdge', () {
    test('applica walk + min transfer + boarding penalty', () {
      const edge = TransferEdge(
        fromStopId: 'A',
        toStopId: 'B',
        fromAreaIndex: 0,
        toAreaIndex: 1,
        walkSeconds: 90,
        gtfsMinTransferSeconds: 180,
        sameStopArea: false,
      );
      const ev = RouteEvaluator(
        boardingTransferPenalty: Duration(minutes: 3),
      );
      final delta = edge.arrivalDeltaSeconds(
        evaluator: ev,
        followsTransitRide: true,
      );
      expect(delta, 90 + 180 + 180);
    });

    test('stessa area: nessuna boarding penalty', () {
      const edge = TransferEdge(
        fromStopId: 'A',
        toStopId: 'B',
        fromAreaIndex: 0,
        toAreaIndex: 0,
        walkSeconds: 40,
        sameStopArea: true,
      );
      final delta = edge.arrivalDeltaSeconds(
        evaluator: RouteEvaluator.standard,
        followsTransitRide: true,
      );
      expect(
        delta,
        40 + PercorsoConstants.minTransferWaitMinutes * 60,
      );
    });
  });

  group('PercorsoTransitGraph', () {
    test('build popola adjacency con walk detour', () {
      final a = _pin(
        id: 'X',
        name: 'Hub A',
        point: const LatLng(44.1, 12.1),
      );
      final b = _pin(
        id: 'Y',
        name: 'Hub B',
        point: const LatLng(44.1005, 12.1002),
      );
      final graph = PercorsoTransitGraph.build(stops: [a, b]);
      final edges = graph.transfers.edgesFrom('X').toList();
      expect(edges, isNotEmpty);
      expect(edges.first.walkSeconds, greaterThan(0));
      expect(graph.stopAreas.areaCount, greaterThan(0));
    });
  });
}

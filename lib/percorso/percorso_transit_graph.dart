import '../transit_stops.dart';
import 'percorso_stop_areas.dart';
import 'percorso_transfer_graph.dart';
import 'route_evaluator.dart';

/// Grafo di preprocessing TPL (aree fermata + trasferimenti a piedi).
///
/// Costruito una volta al load insieme a fermate e trip index; il motore
/// RAPTOR consumerà [stopAreas] e [transfers] in una fase successiva senza
/// ricalcolare cluster o distanze euclidee grezze a ogni round.
class PercorsoTransitGraph {
  const PercorsoTransitGraph({
    required this.stopAreas,
    required this.transfers,
    this.evaluator = RouteEvaluator.standard,
  });

  final StopAreaIndex stopAreas;
  final TransferGraphIndex transfers;
  final RouteEvaluator evaluator;

  /// Costruisce indici in memoria a partire dalle fermate caricate.
  factory PercorsoTransitGraph.build({
    required Iterable<TransitStopPin> stops,
    Iterable<GtfsTransferRule> gtfsTransfers = const [],
    RouteEvaluator evaluator = RouteEvaluator.standard,
  }) {
    final stopList = stops.toList(growable: false);
    final stopById = <String, TransitStopPin>{};
    for (final s in stopList) {
      final id = s.stopId.trim();
      if (id.isNotEmpty) stopById[id] = s;
    }

    final areas = StopAreaIndex.build(stopList);
    final transferGraph = TransferGraphIndex.build(
      stopById: stopById,
      stopAreas: areas,
      gtfsTransfers: gtfsTransfers,
    );

    return PercorsoTransitGraph(
      stopAreas: areas,
      transfers: transferGraph,
      evaluator: evaluator,
    );
  }

  static Future<PercorsoTransitGraph> loadFromAssets({
    RouteEvaluator evaluator = RouteEvaluator.standard,
  }) async {
    final stops = await loadTransitStopsFromAssets();
    final gtfs = await GtfsTransferIndex.tryLoadFromAssets();
    return PercorsoTransitGraph.build(
      stops: stops,
      gtfsTransfers: gtfs.rules,
      evaluator: evaluator,
    );
  }

  /// Tutti gli stop_id equivalenti per routing verso una fermata utente.
  List<String> equivalentStopIds(String stopId) =>
      stopAreas.siblingStopIds(stopId);

  /// Insieme ordinato di ID fermata equivalenti (UI + endpoint).
  Set<String> resolveEquivalentStopIds(String stopId) {
    final out = <String>{};
    for (final id in equivalentStopIds(stopId)) {
      final t = id.trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }

  int stopAreaBestArrival(Map<String, int> arrivalsByStopId, String stopId) =>
      stopAreas.bestArrivalSec(arrivalsByStopId, stopId);

  bool improvesStopAreaArrival(
    Map<String, int> arrivalsByStopId,
    String stopId,
    int arrSec,
  ) =>
      stopAreas.improvesAreaArrival(arrivalsByStopId, stopId, arrSec);

  /// Archi di trasferimento a piedi uscenti da una fermata (per round RAPTOR).
  Iterable<TransferEdge> footTransfersFrom(String fromStopId) =>
      transfers.edgesFrom(fromStopId);

  /// Delta temporale OTP-like per propagare un'etichetta dopo una corsa.
  int footTransferDeltaSeconds(
    TransferEdge edge, {
    required bool followsTransitRide,
  }) =>
      edge.arrivalDeltaSeconds(
        evaluator: evaluator,
        followsTransitRide: followsTransitRide,
      );
}

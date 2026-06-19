import 'package:flutter/foundation.dart';

import '../transit_stops.dart';
import 'percorso_transfer_graph.dart';
import 'percorso_transit_graph.dart';

/// Payload per [compute] durante il build del grafo trasferimenti.
class PercorsoTransitGraphBuildMessage {
  const PercorsoTransitGraphBuildMessage({
    required this.stops,
    required this.gtfsTransfers,
  });

  final List<TransitStopPin> stops;
  final List<GtfsTransferRule> gtfsTransfers;
}

PercorsoTransitGraph buildPercorsoTransitGraphIsolate(
  PercorsoTransitGraphBuildMessage message,
) {
  return PercorsoTransitGraph.build(
    stops: message.stops,
    gtfsTransfers: message.gtfsTransfers,
  );
}

/// Costruisce il grafo in un isolate quando possibile (evita jank UI).
Future<PercorsoTransitGraph> buildPercorsoTransitGraphAsync({
  required List<TransitStopPin> stops,
  Iterable<GtfsTransferRule> gtfsTransfers = const [],
}) {
  final rules = gtfsTransfers.toList(growable: false);
  final message = PercorsoTransitGraphBuildMessage(
    stops: stops,
    gtfsTransfers: rules,
  );
  if (kIsWeb) {
    return Future.value(buildPercorsoTransitGraphIsolate(message));
  }
  return compute(buildPercorsoTransitGraphIsolate, message);
}

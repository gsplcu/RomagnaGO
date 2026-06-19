import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../transit_stops.dart';
import 'percorso_constants.dart';
import 'percorso_stop_areas.dart';
import 'percorso_stops.dart';
import 'percorso_walk.dart';
import 'route_evaluator.dart';

/// Griglia spaziale (~1 km) per accelerare il build del grafo trasferimenti.
class _TransitStopSpatialBucket {
  _TransitStopSpatialBucket(List<TransitStopPin> pins) : _cells = _buildCells(pins);

  static const _cellDeg = 0.01;

  final Map<String, List<TransitStopPin>> _cells;

  static Map<String, List<TransitStopPin>> _buildCells(List<TransitStopPin> pins) {
    final cells = <String, List<TransitStopPin>>{};
    for (final pin in pins) {
      final key = _keyFor(pin.point);
      (cells[key] ??= []).add(pin);
    }
    return cells;
  }

  static String _keyFor(LatLng p) {
    final i = (p.latitude / _cellDeg).floor();
    final j = (p.longitude / _cellDeg).floor();
    return '$i|$j';
  }

  Iterable<TransitStopPin> candidatesNear(LatLng origin, double radiusMeters) sync* {
    final radiusDeg = radiusMeters / 111000.0;
    final cellRadius = (radiusDeg / _cellDeg).ceil().clamp(1, 96);
    final ci = (origin.latitude / _cellDeg).floor();
    final cj = (origin.longitude / _cellDeg).floor();
    for (var di = -cellRadius; di <= cellRadius; di++) {
      for (var dj = -cellRadius; dj <= cellRadius; dj++) {
        final list = _cells['${ci + di}|${cj + dj}'];
        if (list == null) continue;
        for (final pin in list) {
          yield pin;
        }
      }
    }
  }
}

/// Regola GTFS `transfers.txt` (o equivalente precompilato in JSON).
class GtfsTransferRule {
  const GtfsTransferRule({
    required this.fromStopId,
    required this.toStopId,
    required this.minTransferSeconds,
    this.transferType,
  });

  final String fromStopId;
  final String toStopId;

  /// `minimum_transfer_time` in secondi; `0` = tempo minimo di default del feed.
  final int minTransferSeconds;

  /// GTFS `transfer_type` (0=consigliato, 1=proibito, 2=min time, 3=non possibile).
  final int? transferType;

  bool get isForbidden => transferType == 1 || transferType == 3;
}

/// Arco del grafo di trasferimento pedonale tra due fermate.
///
/// Non usa la distanza euclidea grezza: [walkSeconds] deriva da
/// [percorsoWalkEstimate] (Haversine × fattore di deviazione su strada).
class TransferEdge {
  const TransferEdge({
    required this.fromStopId,
    required this.toStopId,
    required this.fromAreaIndex,
    required this.toAreaIndex,
    required this.walkSeconds,
    this.gtfsMinTransferSeconds,
    this.sameStopArea = false,
  });

  final String fromStopId;
  final String toStopId;
  final int fromAreaIndex;
  final int toAreaIndex;

  /// Tempo di cammino pedonale stimato (secondi).
  final int walkSeconds;

  /// Da `transfers.txt` / asset JSON; ha precedenza sul default se > 0.
  final int? gtfsMinTransferSeconds;

  /// `true` se origine e destinazione appartengono alla stessa [StopArea].
  final bool sameStopArea;

  /// Secondi da aggiungere all'orario di arrivo a [fromStopId] per propagare
  /// un'etichetta RAPTOR verso [toStopId] dopo una corsa.
  ///
  /// [followsTransitRide]: se `true`, applica anche la penalità di boarding
  /// (stress del cambio mezzo) definita in [RouteEvaluator].
  int arrivalDeltaSeconds({
    required RouteEvaluator evaluator,
    required bool followsTransitRide,
  }) {
    var sec = walkSeconds;

    final minXfer = _effectiveMinTransferSeconds();
    if (minXfer > 0) sec += minXfer;

    if (followsTransitRide &&
        !sameStopArea &&
        evaluator.boardingTransferPenalty.inSeconds > 0) {
      sec += evaluator.boardingTransferPenalty.inSeconds;
    }

    return sec;
  }

  int _effectiveMinTransferSeconds() {
    final gtfs = gtfsMinTransferSeconds;
    if (gtfs != null && gtfs > 0) return gtfs;
    return PercorsoConstants.minTransferWaitMinutes * 60;
  }
}

/// Grafo sparso fermata → archi di trasferimento a piedi.
class TransferGraphIndex {
  TransferGraphIndex._({
    required this.adjacency,
    required this.gtfsRuleCount,
  });

  /// `fromStopId` → archi uscenti (ordinati per `toStopId`).
  final Map<String, List<TransferEdge>> adjacency;

  final int gtfsRuleCount;

  Iterable<TransferEdge> edgesFrom(String fromStopId) =>
      adjacency[fromStopId.trim()] ?? const [];

  TransferEdge? edgeBetween(String fromStopId, String toStopId) {
    final list = adjacency[fromStopId.trim()];
    if (list == null) return null;
    final to = toStopId.trim();
    for (final e in list) {
      if (e.toStopId == to) return e;
    }
    return null;
  }

  /// Costruisce archi entro [maxWalkMeters] usando la stima pedonale del planner.
  /// Le regole [gtfsTransfers] sovrascrivono o integrano i tempi minimi.
  factory TransferGraphIndex.build({
    required Map<String, TransitStopPin> stopById,
    required StopAreaIndex stopAreas,
    Iterable<GtfsTransferRule> gtfsTransfers = const [],
    double maxWalkMeters = PercorsoConstants.maxTransferGraphBuildRadiusMeters,
    int maxNeighborsPerStop = 32,
  }) {
    final pins = stopById.values.toList(growable: false);
    final gtfsByPair = <String, GtfsTransferRule>{};
    var gtfsCount = 0;
    for (final r in gtfsTransfers) {
      if (r.isForbidden) continue;
      final from = r.fromStopId.trim();
      final to = r.toStopId.trim();
      if (from.isEmpty || to.isEmpty) continue;
      gtfsByPair['$from|$to'] = r;
      gtfsCount++;
    }

    final adjacency = <String, List<TransferEdge>>{};
    final spatial = _TransitStopSpatialBucket(pins);

    void addEdge(TransferEdge edge) {
      final list = adjacency.putIfAbsent(edge.fromStopId, () => []);
      if (list.any((e) => e.toStopId == edge.toStopId)) return;
      list.add(edge);
    }

    for (final from in pins) {
      final fromId = from.stopId.trim();
      if (fromId.isEmpty) continue;
      final fromArea = stopAreas.areaIndexForStop(fromId) ?? -1;

      final neighbors = transitStopsWithinMeters(
        from.point,
        spatial.candidatesNear(from.point, maxWalkMeters),
        maxWalkMeters,
        maxResults: maxNeighborsPerStop,
      );

      for (final to in neighbors) {
        final toId = to.stopId.trim();
        if (toId.isEmpty || toId == fromId) continue;

        final gtfs = gtfsByPair['$fromId|$toId'];
        if (gtfs?.isForbidden == true) continue;

        final walk = percorsoWalkEstimate(from.point, to.point);
        final toArea = stopAreas.areaIndexForStop(toId) ?? -1;
        final sameArea = fromArea >= 0 && fromArea == toArea;

        addEdge(
          TransferEdge(
            fromStopId: fromId,
            toStopId: toId,
            fromAreaIndex: fromArea,
            toAreaIndex: toArea,
            walkSeconds: walk.duration.inSeconds,
            gtfsMinTransferSeconds:
                gtfs != null && gtfs.minTransferSeconds > 0
                    ? gtfs.minTransferSeconds
                    : null,
            sameStopArea: sameArea,
          ),
        );
      }
    }

    // Archi espliciti GTFS oltre il raggio geometrico (es. tunnel stazione).
    for (final r in gtfsTransfers) {
      if (r.isForbidden) continue;
      final fromId = r.fromStopId.trim();
      final toId = r.toStopId.trim();
      if (fromId.isEmpty || toId.isEmpty || fromId == toId) continue;
      final fromPin = stopById[fromId];
      final toPin = stopById[toId];
      if (fromPin == null || toPin == null) continue;

      final walk = percorsoWalkEstimate(fromPin.point, toPin.point);
      final fromArea = stopAreas.areaIndexForStop(fromId) ?? -1;
      final toArea = stopAreas.areaIndexForStop(toId) ?? -1;

      addEdge(
        TransferEdge(
          fromStopId: fromId,
          toStopId: toId,
          fromAreaIndex: fromArea,
          toAreaIndex: toArea,
          walkSeconds: walk.duration.inSeconds,
          gtfsMinTransferSeconds:
              r.minTransferSeconds > 0 ? r.minTransferSeconds : null,
          sameStopArea: fromArea >= 0 && fromArea == toArea,
        ),
      );
    }

    for (final list in adjacency.values) {
      list.sort((a, b) => a.toStopId.compareTo(b.toStopId));
    }

    return TransferGraphIndex._(
      adjacency: adjacency,
      gtfsRuleCount: gtfsCount,
    );
  }
}

/// Caricamento opzionale di `transfers_*.json` generati offline dal feed GTFS.
///
/// Schema asset:
/// ```json
/// { "transfers": [
///     {"from":"10821","to":"10822","min":120,"type":0}
/// ]}
/// ```
class GtfsTransferIndex {
  const GtfsTransferIndex({required this.rules});

  final List<GtfsTransferRule> rules;

  static const _assetPaths = [
    'assets/data/transfers_fc.json',
    'assets/data/transfers_ra.json',
    'assets/data/transfers_rn.json',
  ];

  static Future<GtfsTransferIndex> tryLoadFromAssets() async {
    final rules = <GtfsTransferRule>[];
    for (final path in _assetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        rules.addAll(_parseFile(raw));
      } catch (_) {
        // Asset assente: feed senza transfers.txt esportato.
      }
    }
    return GtfsTransferIndex(rules: rules);
  }

  static List<GtfsTransferRule> _parseFile(String raw) {
    final d = json.decode(raw);
    if (d is! Map<String, dynamic>) return const [];
    final list = d['transfers'];
    if (list is! List) return const [];
    final out = <GtfsTransferRule>[];
    for (final row in list) {
      if (row is! Map<String, dynamic>) continue;
      final from = row['from']?.toString().trim() ?? '';
      final to = row['to']?.toString().trim() ?? '';
      if (from.isEmpty || to.isEmpty) continue;
      final min =
          row['min'] is int
              ? row['min'] as int
              : int.tryParse(row['min']?.toString() ?? '') ?? 0;
      final type =
          row['type'] is int
              ? row['type'] as int
              : int.tryParse(row['type']?.toString() ?? '');
      out.add(
        GtfsTransferRule(
          fromStopId: from,
          toStopId: to,
          minTransferSeconds: min,
          transferType: type,
        ),
      );
    }
    return out;
  }
}

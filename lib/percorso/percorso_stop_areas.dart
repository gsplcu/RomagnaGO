import 'package:latlong2/latlong.dart';

import '../quick_address_nearby_stops.dart';
import '../transit_stops.dart';
import 'percorso_constants.dart';

/// Area fermata in stile OTP (StopArea / SuperStop): insieme di [stop_id] che
/// l'utente considera lo stesso luogo fisico (stazione, banchina, Punto Bus).
///
/// Il motore RAPTOR può continuare a ragionare su `stop_id` granulari; l'area
/// serve per interscambi intra-stazione, destinazioni equivalenti e per
/// evitare doppi conteggi nei trasferimenti a piedi tra piattaforme gemelle.
class StopArea {
  const StopArea({
    required this.index,
    required this.label,
    required this.centroid,
    required this.stopIds,
    required this.representativeStopId,
  });

  /// Indice denso `0 .. areaCount-1`.
  final int index;

  /// Nome mostrato (dal pin rappresentativo).
  final String label;

  final LatLng centroid;

  /// Tutti gli `stop_id` GTFS nell'area (ordinati).
  final List<String> stopIds;

  /// Pin preferito per access/egress e lookup coordinate.
  final String representativeStopId;

  bool containsStop(String stopId) => stopIds.contains(stopId.trim());
}

/// Indice fermata → area + query inverse.
class StopAreaIndex {
  StopAreaIndex._({
    required this.areas,
    required this.stopIdToAreaIndex,
  });

  final List<StopArea> areas;
  final Map<String, int> stopIdToAreaIndex;

  int get areaCount => areas.length;

  int? areaIndexForStop(String stopId) => stopIdToAreaIndex[stopId.trim()];

  StopArea? areaForStop(String stopId) {
    final i = areaIndexForStop(stopId);
    if (i == null) return null;
    return areas[i];
  }

  bool sameArea(String stopIdA, String stopIdB) {
    final a = areaIndexForStop(stopIdA);
    final b = areaIndexForStop(stopIdB);
    return a != null && a == b;
  }

  List<String> siblingStopIds(String stopId) {
    final area = areaForStop(stopId);
    if (area == null) return [stopId.trim()];
    return area.stopIds;
  }

  /// Miglior arrivo noto (secondi GTFS) tra tutti gli stop della stessa area.
  int bestArrivalSec(Map<String, int> arrivalsByStopId, String anyStopId) {
    final area = areaForStop(anyStopId);
    if (area == null) {
      return arrivalsByStopId[anyStopId.trim()] ?? 0x7FFFFFFF;
    }
    var min = 0x7FFFFFFF;
    for (final sid in area.stopIds) {
      final t = arrivalsByStopId[sid];
      if (t != null && t < min) min = t;
    }
    return min;
  }

  /// `true` se [arrSec] migliora l'arrivo migliore dell'intera area.
  bool improvesAreaArrival(
    Map<String, int> arrivalsByStopId,
    String stopId,
    int arrSec,
  ) {
    return arrSec < bestArrivalSec(arrivalsByStopId, stopId);
  }

  /// Costruisce aree unendo fermate se:
  /// - distanza ≤ [clusterRadiusMeters], oppure
  /// - stesso nome visualizzato e stesso comune (evita omonimi in comuni diversi).
  ///
  /// Riutilizza [transitStopsLikelySamePlatform] per piattaforme gemelle note
  /// (codici consecutivi, stesso bacino).
  factory StopAreaIndex.build(
    Iterable<TransitStopPin> stops, {
    double clusterRadiusMeters =
        PercorsoConstants.stopAreaClusterRadiusMeters,
  }) {
    final pins =
        stops
            .where((s) => s.stopId.trim().isNotEmpty)
            .toList(growable: false);
    if (pins.isEmpty) {
      return StopAreaIndex._(areas: const [], stopIdToAreaIndex: const {});
    }

    final n = pins.length;
    final parent = List<int>.generate(n, (i) => i);
    final rank = List<int>.filled(n, 0);

    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int a, int b) {
      var ra = find(a);
      var rb = find(b);
      if (ra == rb) return;
      if (rank[ra] < rank[rb]) {
        final t = ra;
        ra = rb;
        rb = t;
      }
      parent[rb] = ra;
      if (rank[ra] == rank[rb]) rank[ra]++;
    }

    const dist = Distance();
    final radiusM = clusterRadiusMeters;

    // Griglia spaziale ~60 m per vicinanza geometrica.
    final cellDeg = radiusM / 111000.0;
    final grid = <String, List<int>>{};
    String cellKey(double lat, double lon) {
      final gx = (lat / cellDeg).floor();
      final gy = (lon / cellDeg).floor();
      return '$gx:$gy';
    }

    for (var i = 0; i < n; i++) {
      final p = pins[i].point;
      if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
      grid.putIfAbsent(cellKey(p.latitude, p.longitude), () => []).add(i);
    }

    for (var i = 0; i < n; i++) {
      final pi = pins[i].point;
      if (!pi.latitude.isFinite) continue;
      final gx = (pi.latitude / cellDeg).floor();
      final gy = (pi.longitude / cellDeg).floor();
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final bucket = grid['${gx + dx}:${gy + dy}'];
          if (bucket == null) continue;
          for (final j in bucket) {
            if (j <= i) continue;
            final pj = pins[j].point;
            final m = dist.as(LengthUnit.Meter, pi, pj);
            if (m <= radiusM) {
              union(i, j);
              continue;
            }
            if (transitStopsLikelySamePlatform(pins[i], pins[j])) {
              union(i, j);
            }
          }
        }
      }
    }

    // Stesso nome + stesso comune (stazione omonima nel territorio).
    final byNameComune = <String, List<int>>{};
    for (var i = 0; i < n; i++) {
      final name = transitStopNameForDisplay(pins[i].stopName);
      if (name.isEmpty) continue;
      final comune = pins[i].comune.toLowerCase().trim();
      final key = '$comune|$name';
      byNameComune.putIfAbsent(key, () => []).add(i);
    }
    for (final group in byNameComune.values) {
      if (group.length < 2) continue;
      for (var a = 1; a < group.length; a++) {
        union(group[0], group[a]);
      }
    }

    final rootToMembers = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      rootToMembers.putIfAbsent(find(i), () => []).add(i);
    }

    final areas = <StopArea>[];
    final stopIdToAreaIndex = <String, int>{};
    var areaIdx = 0;
    for (final members in rootToMembers.values) {
      members.sort();
      final ids =
          members.map((i) => pins[i].stopId.trim()).toList()..sort();
      final repIndex = _pickRepresentativeIndex(members, pins);
      final rep = pins[repIndex];
      var lat = 0.0;
      var lon = 0.0;
      var count = 0;
      for (final i in members) {
        final p = pins[i].point;
        if (!p.latitude.isFinite) continue;
        lat += p.latitude;
        lon += p.longitude;
        count++;
      }
      final centroid =
          count > 0
              ? LatLng(lat / count, lon / count)
              : rep.point;

      final area = StopArea(
        index: areaIdx,
        label: transitStopNameForDisplay(rep.stopName),
        centroid: centroid,
        stopIds: ids,
        representativeStopId: rep.stopId,
      );
      areas.add(area);
      for (final id in ids) {
        stopIdToAreaIndex[id] = areaIdx;
      }
      areaIdx++;
    }

    areas.sort((a, b) => a.index.compareTo(b.index));
    return StopAreaIndex._(areas: areas, stopIdToAreaIndex: stopIdToAreaIndex);
  }

  static int _pickRepresentativeIndex(
    List<int> members,
    List<TransitStopPin> pins,
  ) {
    // Preferisce l'id lessicograficamente minimo (stabile tra build).
    var best = members.first;
    for (final i in members) {
      if (pins[i].stopId.compareTo(pins[best].stopId) < 0) best = i;
    }
    return best;
  }
}

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'transit_stops.dart';

/// Distanza approssimata al quadrato (solo per ordinare; ordine ~Vincenty su scala locale).
double _quickDistSq(LatLng o, LatLng p) {
  final dx =
      (p.longitude - o.longitude) * math.cos(o.latitude * math.pi / 180);
  final dy = p.latitude - o.latitude;
  return dx * dx + dy * dy;
}

/// Riduce i candidati prima del sort pesante (± [radiusKm] km).
List<TransitStopPin> _stopsInRoughBoundingBox(
  LatLng origin,
  List<TransitStopPin> stops,
  double radiusKm,
) {
  if (radiusKm <= 0 || stops.isEmpty) return stops;
  final padLat = radiusKm / 111.0;
  final cosLat =
      math.cos(origin.latitude * math.pi / 180).clamp(0.22, 1.0);
  final padLon = radiusKm / (111.0 * cosLat);
  final minLat = origin.latitude - padLat;
  final maxLat = origin.latitude + padLat;
  final minLon = origin.longitude - padLon;
  final maxLon = origin.longitude + padLon;
  final out = <TransitStopPin>[];
  for (final s in stops) {
    final p = s.point;
    if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
    if (p.latitude >= minLat &&
        p.latitude <= maxLat &&
        p.longitude >= minLon &&
        p.longitude <= maxLon) {
      out.add(s);
    }
  }
  return out;
}

bool _validLatLng(LatLng p) {
  return p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90.0 &&
      p.longitude.abs() <= 180.0;
}

/// Due fermate con stesso nome su due marciapiedi (es. codici 10821 e 10822).
bool transitStopsLikelySamePlatform(TransitStopPin a, TransitStopPin b) {
  if (a.basin != b.basin) return false;
  if (transitStopNameForDisplay(a.stopName) !=
      transitStopNameForDisplay(b.stopName)) {
    return false;
  }
  final ia = int.tryParse(a.stopId.trim());
  final ib = int.tryParse(b.stopId.trim());
  if (ia != null && ib != null) {
    return (ia - ib).abs() <= 8;
  }
  final distance = Distance();
  final m = distance.as(LengthUnit.Meter, a.point, b.point);
  return m < 14;
}

/// Ordina per distanza dall’origine, accorpa piattaforme gemelle, restituisce
/// un [TransitStopPin] rappresentativo per ciascuno dei primi [maxResults] gruppi
/// (il pin del gruppo più vicino al punto utente).
List<TransitStopPin> nearestMergedTransitStops(
  LatLng origin,
  List<TransitStopPin> stops, {
  int maxResults = 2,
}) {
  if (maxResults <= 0) return const [];
  const maxCandidates = 720;
  const bboxKm = 26.0;

  var pool = _stopsInRoughBoundingBox(origin, stops, bboxKm);
  if (pool.isEmpty) {
    pool = stops;
  }

  final scored =
      pool
          .where((s) => _validLatLng(s.point))
          .map((s) => MapEntry(s, _quickDistSq(origin, s.point)))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  if (scored.length > maxCandidates) {
    scored.removeRange(maxCandidates, scored.length);
  }

  final dist = Distance();

  final clusters = <List<TransitStopPin>>[];

  for (final e in scored) {
    final s = e.key;
    var placed = false;
    for (var i = 0; i < clusters.length; i++) {
      if (clusters[i].any((c) => transitStopsLikelySamePlatform(s, c))) {
        clusters[i].add(s);
        placed = true;
        break;
      }
    }
    if (!placed) clusters.add([s]);
  }

  TransitStopPin representative(List<TransitStopPin> cluster) {
    TransitStopPin? best;
    var bestD = double.infinity;
    for (final p in cluster) {
      final d = dist.as(LengthUnit.Meter, origin, p.point);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best!;
  }

  double clusterMinDist(List<TransitStopPin> cluster) {
    var m = double.infinity;
    for (final p in cluster) {
      final d = dist.as(LengthUnit.Meter, origin, p.point);
      if (d < m) m = d;
    }
    return m;
  }

  clusters.sort((a, b) => clusterMinDist(a).compareTo(clusterMinDist(b)));

  return clusters
      .take(maxResults)
      .map(representative)
      .toList(growable: false);
}

/// Raggruppa [pins] per nome/piattaforma gemella (stesso criterio della mappa).
List<List<TransitStopPin>> clusterTransitStopsByPlatform(
  List<TransitStopPin> pins,
) {
  final clusters = <List<TransitStopPin>>[];
  for (final s in pins) {
    var placed = false;
    for (var i = 0; i < clusters.length; i++) {
      if (clusters[i].any((c) => transitStopsLikelySamePlatform(s, c))) {
        clusters[i].add(s);
        placed = true;
        break;
      }
    }
    if (!placed) clusters.add([s]);
  }
  return clusters;
}

/// Da una lista già ordinata per rilevanza, restituisce un pin per gruppo
/// (il più vicino a [origin] se fornito, altrimenti il primo del gruppo).
List<({TransitStopPin rep, List<String> stopIds})> mergedStopGroupsFromRanked(
  List<TransitStopPin> rankedPins, {
  LatLng? origin,
  int maxGroups = 8,
}) {
  if (rankedPins.isEmpty || maxGroups <= 0) return const [];
  final clusters = clusterTransitStopsByPlatform(rankedPins);
  final dist = Distance();

  ({TransitStopPin rep, List<String> stopIds}) pack(List<TransitStopPin> cluster) {
    TransitStopPin rep = cluster.first;
    if (origin != null) {
      var bestD = double.infinity;
      for (final p in cluster) {
        final d = dist.as(LengthUnit.Meter, origin, p.point);
        if (d < bestD) {
          bestD = d;
          rep = p;
        }
      }
    }
    final ids =
        cluster.map((p) => p.stopId.trim()).where((id) => id.isNotEmpty).toSet().toList()
          ..sort();
    return (rep: rep, stopIds: ids);
  }

  if (origin != null) {
    clusters.sort((a, b) {
      double minD(List<TransitStopPin> c) {
        var m = double.infinity;
        for (final p in c) {
          final d = dist.as(LengthUnit.Meter, origin, p.point);
          if (d < m) m = d;
        }
        return m;
      }

      return minD(a).compareTo(minD(b));
    });
  }

  return clusters.take(maxGroups).map(pack).toList(growable: false);
}

String formatWalkingDistanceMeters(double meters) {
  if (!meters.isFinite || meters < 0) return '';
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  final km = meters / 1000.0;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
}

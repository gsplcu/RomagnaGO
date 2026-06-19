import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../transit_stops.dart';

/// Fermate entro [radiusMeters] da [origin] (bbox + Haversine).
List<TransitStopPin> transitStopsWithinMeters(
  LatLng origin,
  Iterable<TransitStopPin> stops,
  double radiusMeters, {
  int maxResults = 64,
}) {
  if (radiusMeters <= 0 || maxResults <= 0) return const [];
  final radiusKm = radiusMeters / 1000.0;
  final padLat = radiusKm / 111.0;
  final cosLat = math.cos(origin.latitude * math.pi / 180).clamp(0.22, 1.0);
  final padLon = radiusKm / (111.0 * cosLat);
  final minLat = origin.latitude - padLat;
  final maxLat = origin.latitude + padLat;
  final minLon = origin.longitude - padLon;
  final maxLon = origin.longitude + padLon;

  const dist = Distance();
  final scored = <MapEntry<TransitStopPin, double>>[];

  for (final s in stops) {
    final p = s.point;
    if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
    if (p.latitude < minLat ||
        p.latitude > maxLat ||
        p.longitude < minLon ||
        p.longitude > maxLon) {
      continue;
    }
    final m = dist.as(LengthUnit.Meter, origin, p);
    if (m <= radiusMeters) scored.add(MapEntry(s, m));
  }

  scored.sort((a, b) => a.value.compareTo(b.value));
  if (scored.length > maxResults) {
    scored.removeRange(maxResults, scored.length);
  }
  return scored.map((e) => e.key).toList(growable: false);
}

/// Per indirizzi generici: fermata più vicina per ciascun bacino FC/RA/RN.
List<TransitStopPin> nearestStopPerBasin(
  LatLng origin,
  Iterable<TransitStopPin> stops, {
  double radiusMeters = 3500,
}) {
  const basins = ['FC', 'RA', 'RN'];
  final out = <TransitStopPin>[];
  for (final b in basins) {
    final pool = stops.where((s) => s.basin == b);
    final near = transitStopsWithinMeters(
      origin,
      pool,
      radiusMeters,
      maxResults: 1,
    );
    if (near.isNotEmpty) out.add(near.first);
  }
  return out;
}

bool isValidPlannerLatLng(LatLng p) {
  return p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      !(p.latitude == 0 && p.longitude == 0);
}

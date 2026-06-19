import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fermata su una corsa GTFS (da trip_index).
class TripStopPoint {
  const TripStopPoint({
    required this.stopId,
    required this.sequence,
    required this.depSec,
    required this.depRaw,
  });

  final String stopId;
  final int sequence;
  final int depSec;
  final String depRaw;
}

class TripRecord {
  const TripRecord({
    required this.tripId,
    required this.routeKey,
    required this.serviceId,
    required this.stops,
  });

  final String tripId;
  final String routeKey;
  final String serviceId;
  final List<TripStopPoint> stops;

  String get basin => routeKey.split('|').first;

  TripStopPoint? stopById(String stopId) {
    for (final s in stops) {
      if (s.stopId == stopId) return s;
    }
    return null;
  }

  /// Tutte le occorrenze di una fermata sulla corsa. Su linee ad anello/circolari
  /// (es. 2CO, 126) la stessa `stopId` compare più volte: il boarding e gli
  /// ottimizzatori di discesa NON devono assumere la prima occorrenza.
  Iterable<TripStopPoint> stopOccurrences(String stopId) =>
      stops.where((s) => s.stopId == stopId);

  /// Fermata identificata in modo univoco dalla sua [sequence] sulla corsa.
  /// È l'unico modo affidabile di puntare a un preciso passaggio su un anello.
  TripStopPoint? stopBySequence(int sequence) {
    for (final s in stops) {
      if (s.sequence == sequence) return s;
    }
    return null;
  }

  /// Prima occorrenza di [stopId] con `sequence > afterSequence`. Su una linea
  /// ad anello disambigua il passaggio a valle di un punto di salita noto.
  TripStopPoint? stopByIdAfter(String stopId, {int afterSequence = -1}) {
    for (final s in stops) {
      if (s.stopId == stopId && s.sequence > afterSequence) return s;
    }
    return null;
  }
}

/// Indice corse + fermata→linee, caricato da trip_index_{fc,ra,rn}.json.
class PercorsoPlannerIndex {
  PercorsoPlannerIndex._({
    required this.trips,
    required this.stopRoutes,
    required this.stopTrips,
    required this.loadFailed,
  });

  final Map<String, TripRecord> trips;
  final Map<String, List<String>> stopRoutes;
  final Map<String, List<String>> stopTrips;
  final bool loadFailed;

  static PercorsoPlannerIndex? _cached;
  static Future<PercorsoPlannerIndex>? _loading;

  static Future<PercorsoPlannerIndex> load() {
    final c = _cached;
    if (c != null) return Future.value(c);
    return _loading ??= _loadInternal().then((idx) {
      _cached = idx;
      return idx;
    });
  }

  static Future<PercorsoPlannerIndex> _loadInternal() async {
    try {
      final trips = <String, TripRecord>{};
      final stopRoutes = <String, List<String>>{};
      final stopTrips = <String, List<String>>{};

      for (final asset in const [
        'assets/data/trip_index_fc.json',
        'assets/data/trip_index_ra.json',
        'assets/data/trip_index_rn.json',
      ]) {
        final raw = await rootBundle.loadString(asset);
        final d = json.decode(raw) as Map<String, dynamic>;
        _mergeBasinFile(d, trips, stopRoutes, stopTrips);
      }

      return PercorsoPlannerIndex._(
        trips: trips,
        stopRoutes: stopRoutes,
        stopTrips: stopTrips,
        loadFailed: false,
      );
    } catch (e, st) {
      debugPrint('PercorsoPlannerIndex.load: $e\n$st');
      return PercorsoPlannerIndex._(
        trips: {},
        stopRoutes: {},
        stopTrips: {},
        loadFailed: true,
      );
    }
  }

  static void _mergeBasinFile(
    Map<String, dynamic> d,
    Map<String, TripRecord> trips,
    Map<String, List<String>> stopRoutes,
    Map<String, List<String>> stopTrips,
  ) {
    final tripsDyn = d['trips'];
    if (tripsDyn is Map<String, dynamic>) {
      for (final e in tripsDyn.entries) {
        final tid = e.key.trim();
        if (tid.isEmpty || e.value is! Map<String, dynamic>) continue;
        final m = e.value as Map<String, dynamic>;
        final rk = m['rk']?.toString().trim() ?? '';
        final svc = m['svc']?.toString().trim() ?? '';
        final st = m['st'];
        if (rk.isEmpty || st is! List) continue;
        final stops = <TripStopPoint>[];
        for (final row in st) {
          if (row is! List || row.length < 3) continue;
          final sid = row[0]?.toString().trim() ?? '';
          final seq = row[1] is int
              ? row[1] as int
              : int.tryParse(row[1]?.toString() ?? '') ?? 0;
          final depRaw = row[2]?.toString().trim() ?? '';
          final depSec = gtfsTimeToSeconds(depRaw);
          if (sid.isEmpty || depSec == null) continue;
          stops.add(
            TripStopPoint(
              stopId: sid,
              sequence: seq,
              depSec: depSec,
              depRaw: depRaw,
            ),
          );
        }
        if (stops.isEmpty) continue;
        stops.sort((a, b) => a.sequence.compareTo(b.sequence));
        trips[tid] = TripRecord(
          tripId: tid,
          routeKey: rk,
          serviceId: svc,
          stops: stops,
        );
        for (final s in stops) {
          stopTrips.putIfAbsent(s.stopId, () => []).add(tid);
        }
      }
    }

    final sr = d['stopRoutes'];
    if (sr is Map<String, dynamic>) {
      for (final e in sr.entries) {
        final sid = e.key.trim();
        if (sid.isEmpty || e.value is! List) continue;
        final list = <String>[];
        for (final x in e.value as List) {
          final rk = x?.toString().trim() ?? '';
          if (rk.isNotEmpty) list.add(rk);
        }
        if (list.isEmpty) continue;
        stopRoutes.putIfAbsent(sid, () => []).addAll(list);
        stopRoutes[sid] = stopRoutes[sid]!.toSet().toList()..sort();
      }
    }
  }

  List<String> tripIdsAtStop(String stopId) =>
      stopTrips[stopId.trim()] ?? const [];

  List<String> routeKeysAtStop(String stopId) =>
      stopRoutes[stopId.trim()] ?? const [];
}

/// Secondi dall'inizio giornata servizio GTFS (ore ≥ 24 ammesse).
int? gtfsTimeToSeconds(String raw) {
  final p = raw.split(':');
  if (p.length != 3) return null;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  final s = int.tryParse(p[2].trim());
  if (h == null || m == null || s == null) return null;
  if (m < 0 || m > 59 || s < 0 || s > 59 || h < 0) return null;
  return h * 3600 + m * 60 + s;
}

/// [baseDay] = giorno locale scelto dall'utente; [depSec] = orario GTFS.
DateTime dateTimeFromGtfsSec(DateTime baseDay, int depSec) {
  final d = DateTime(baseDay.year, baseDay.month, baseDay.day);
  return d.add(Duration(seconds: depSec));
}

/// Durata tra due orari GTFS (supporta ore ≥ 24 e attraversamento mezzanotte).
int gtfsSecDelta(int fromSec, int toSec) {
  var d = toSec - fromSec;
  if (d <= 0) d += 24 * 3600;
  return d;
}

/// Durata di corsa plausibile tra due fermate sulla stessa trip.
bool gtfsTripTimesAreOrdered(int boardSec, int alightSec) {
  final d = gtfsSecDelta(boardSec, alightSec);
  return d >= 60 && d <= 8 * 3600;
}

/// Passaggio di salita sulla corsa (sequenza GTFS se disponibile).
TripStopPoint? resolveRideBoardOnTrip(
  TripRecord trip, {
  required String boardStopId,
  int? boardSeq,
}) {
  if (boardSeq != null) {
    final s = trip.stopBySequence(boardSeq);
    if (s != null && s.stopId == boardStopId) return s;
  }
  for (final occ in trip.stopOccurrences(boardStopId)) {
    return occ;
  }
  return null;
}

/// Passaggio di discesa a valle di [boardOnTrip] sulla stessa corsa.
TripStopPoint? resolveRideAlightOnTrip(
  TripRecord trip, {
  required String alightStopId,
  int? alightSeq,
  required TripStopPoint boardOnTrip,
}) {
  if (alightSeq != null) {
    final s = trip.stopBySequence(alightSeq);
    if (s != null &&
        s.stopId == alightStopId &&
        s.sequence > boardOnTrip.sequence &&
        gtfsTripTimesAreOrdered(boardOnTrip.depSec, s.depSec)) {
      return s;
    }
  }
  for (final s in trip.stops) {
    if (s.sequence <= boardOnTrip.sequence) continue;
    if (s.stopId != alightStopId) continue;
    if (!gtfsTripTimesAreOrdered(boardOnTrip.depSec, s.depSec)) continue;
    return s;
  }
  return null;
}

/// True se salita e discesa sono sullo stesso viaggio GTFS (nessun mix di varianti).
bool tripServesRideSegment(
  TripRecord trip, {
  required String boardStopId,
  required String alightStopId,
  int? boardSeq,
  int? alightSeq,
}) {
  final board = resolveRideBoardOnTrip(
    trip,
    boardStopId: boardStopId,
    boardSeq: boardSeq,
  );
  if (board == null) return false;
  return resolveRideAlightOnTrip(
        trip,
        alightStopId: alightStopId,
        alightSeq: alightSeq,
        boardOnTrip: board,
      ) !=
      null;
}

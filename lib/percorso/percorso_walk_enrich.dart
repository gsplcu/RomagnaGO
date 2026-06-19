import 'package:latlong2/latlong.dart';

import 'graphhopper_walk.dart';
import 'percorso_models.dart';
import 'percorso_walk.dart';

/// Arricchisce le gambe walk con distanza/tempo/polilinee su strada (GraphHopper).
abstract final class PercorsoWalkEnricher {
  /// Passo (metri) della densificazione lineare di backup quando GraphHopper
  /// non risponde: evita il singolo segmento retto sostituendolo con una
  /// spezzata fitta lungo la congiungente (Punto D).
  static const double _backupStepMeters = 30;

  static Future<List<PercorsoItinerary>> enrichItineraries(
    List<PercorsoItinerary> itineraries,
  ) async {
    if (itineraries.isEmpty) return itineraries;
    final out = <PercorsoItinerary>[];
    for (final it in itineraries) {
      out.add(await enrichItinerary(it));
    }
    return out;
  }

  static Future<PercorsoItinerary> enrichItinerary(PercorsoItinerary it) async {
    final gh = GraphHopperWalkService.instance;
    final ghReady = gh.isReady;
    var walkMeters = 0.0;
    final newLegs = <PercorsoLeg>[];

    // Cursore = fine reale della gamba precedente. Serve a ri-temporizzare le
    // gambe a piedi: una camminata reale più lunga sposta in avanti tutto ciò
    // che la segue, così non si nasconde uno sfasamento.
    DateTime? cursor;
    var brokenConnection = false;

    for (final leg in it.legs) {
      // Le corse hanno orario fisso da quadro orario: NON si spostano. Se la
      // camminata reale ha già sforato la salita, la coincidenza è persa.
      if (leg.kind == PercorsoLegKind.ride) {
        if (cursor != null &&
            leg.start != null &&
            cursor.isAfter(leg.start!.add(const Duration(seconds: 30)))) {
          brokenConnection = true;
        }
        newLegs.add(leg);
        cursor = leg.end ?? cursor;
        continue;
      }

      if (leg.kind != PercorsoLegKind.walk ||
          leg.from == null ||
          leg.to == null) {
        newLegs.add(leg);
        cursor = leg.end ?? cursor;
        continue;
      }

      final start = cursor ?? leg.start;
      final route = ghReady ? await gh.routeFoot(leg.from!, leg.to!) : null;

      final double meters;
      final Duration dur;
      final List<LatLng> path;
      if (route != null) {
        meters = route.meters;
        dur = route.duration;
        path = route.points;
      } else {
        // Backup: stima + densificazione lineare (no rette/buchi sulla mappa).
        final est = percorsoWalkEstimate(leg.from!, leg.to!);
        meters = est.meters;
        dur = est.duration;
        path = _densifyStraightLine(leg.from!, leg.to!, est.meters);
      }

      walkMeters += meters;
      final end = start != null ? start.add(dur) : leg.end;
      newLegs.add(
        leg.copyWith(
          walkPath: path,
          subtitle: _walkSubtitle(meters, leg.subtitle),
          start: start,
          end: end,
        ),
      );
      cursor = end ?? cursor;
    }

    final totalDuration = _spanDuration(newLegs) ?? it.totalDuration;

    return it.copyWith(
      legs: newLegs,
      walkMeters: walkMeters > 0 ? walkMeters : it.walkMeters,
      totalDuration: totalDuration,
      hasBrokenWalkConnection: brokenConnection,
    );
  }

  /// Spezzata fitta lungo il segmento [from]→[to]. È sempre geometricamente una
  /// retta, ma con vertici intermedi: backup uniforme quando manca la rete
  /// pedonale GraphHopper, così la mappa non disegna mai un singolo salto secco.
  static List<LatLng> _densifyStraightLine(
    LatLng from,
    LatLng to,
    double meters,
  ) {
    final segments = (meters / _backupStepMeters).ceil().clamp(1, 400);
    final pts = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      pts.add(LatLng(
        from.latitude + (to.latitude - from.latitude) * t,
        from.longitude + (to.longitude - from.longitude) * t,
      ));
    }
    return pts;
  }

  static Future<PercorsoLeg> enrichWalkLeg(PercorsoLeg leg) async {
    if (leg.kind != PercorsoLegKind.walk ||
        leg.from == null ||
        leg.to == null) {
      return leg;
    }
    final gh = GraphHopperWalkService.instance;
    final route = gh.isReady ? await gh.routeFoot(leg.from!, leg.to!) : null;
    final start = leg.start;
    if (route == null) {
      // Backup: densificazione lineare, mai un segmento retto secco.
      final est = percorsoWalkEstimate(leg.from!, leg.to!);
      return leg.copyWith(
        walkPath: _densifyStraightLine(leg.from!, leg.to!, est.meters),
        subtitle: _walkSubtitle(est.meters, leg.subtitle),
        end: start?.add(est.duration) ?? leg.end,
      );
    }
    return leg.copyWith(
      walkPath: route.points,
      subtitle: _walkSubtitle(route.meters, leg.subtitle),
      end: start?.add(route.duration) ?? leg.end,
    );
  }

  static String _walkSubtitle(double meters, String previous) {
    final dist = percorsoFormatWalkDistance(meters);
    if (!previous.contains(' · ')) return dist;
    final tail = previous.substring(previous.indexOf(' · ') + 3).trim();
    return tail.isEmpty ? dist : '$dist · $tail';
  }

  static Duration? _spanDuration(List<PercorsoLeg> legs) {
    DateTime? minStart;
    DateTime? maxEnd;
    for (final leg in legs) {
      if (leg.kind == PercorsoLegKind.wait) continue;
      final s = leg.start;
      final e = leg.end;
      if (s != null && (minStart == null || s.isBefore(minStart))) {
        minStart = s;
      }
      if (e != null && (maxEnd == null || e.isAfter(maxEnd))) {
        maxEnd = e;
      }
    }
    if (minStart == null || maxEnd == null) return null;
    final d = maxEnd.difference(minStart);
    if (d.isNegative) return null;
    return d;
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../linee_percorsi.dart';
import '../navette_bussi_data.dart';
import '../navette_milano_marittima_data.dart';
import '../navette_navettomare_data.dart';
import 'percorso_models.dart';
import 'percorso_walk.dart';

/// Suggerimento navetta da mostrare prima degli itinerari TPL in [PercorsoPage].
enum PercorsoNavettaHintKind {
  cesenatico,
  navettoMare65,
  navettoMare66,
  milanoMarittima,
  busSi,
}

class PercorsoNavettaHint {
  const PercorsoNavettaHint({
    required this.kind,
    required this.title,
    required this.message,
    required this.accent,
    required this.accentDark,
  });

  final PercorsoNavettaHintKind kind;
  final String title;
  final String message;
  final Color accent;
  final Color accentDark;
}

const _distance = Distance();

const _kWalkToParkingMaxMeters = 2000.0;
const _kNearStopMaxMeters = 450.0;
const _kNearCorridorMaxMeters = 550.0;

const _kParcheggioCimitero = LatLng(44.20575811292511, 12.388519068476837);

const _kCesenaticoDestinationStops = [
  LatLng(44.21152168619593, 12.388710618544446),
  LatLng(44.21535666971264, 12.387248034467962),
  LatLng(44.21867569856016, 12.384610408604605),
  LatLng(44.21456067441028, 12.387839695184384),
  LatLng(44.2117541768743, 12.388461529661793),
];

/// Zona urbana Cesena (es. Barriera–Stazione), senza frazioni limitrofe.
const _kCesenaUrbanPolygon = [
  LatLng(44.1492, 12.2265),
  LatLng(44.1495, 12.2645),
  LatLng(44.1265, 12.2655),
  LatLng(44.1260, 12.2270),
];

final Map<String, List<LatLng>> _gpxCache = {};

abstract final class PercorsoNavettaHints {
  static Future<List<PercorsoNavettaHint>> detect({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
  }) async {
    final hints = <PercorsoNavettaHint>[];

    if (_matchCesenatico(from, to, departAt)) {
      hints.add(
        PercorsoNavettaHint(
          kind: PercorsoNavettaHintKind.cesenatico,
          title: 'Navetta Cesenatico',
          message: 'Consigliato per raggiungere il lungomare di Ponente',
          accent: NavettaCesenaticoColors.green,
          accentDark: NavettaCesenaticoColors.greenDark,
        ),
      );
    }

    final line65 = await _loadGpx(kNavettoMareGpxMarinaM1M12);
    if (line65.length >= 2 &&
        _matchNavettoMareCorridor(
          from: from.point,
          to: to.point,
          corridor: line65,
          departAt: departAt,
        )) {
      hints.add(
        PercorsoNavettaHint(
          kind: PercorsoNavettaHintKind.navettoMare65,
          title: 'Navetto Mare · Linea 65',
          message:
              'Navetta gratuita per raggiungere il lungomare di Marina di Ravenna',
          accent: NavettoMareColors.accent,
          accentDark: NavettoMareColors.accentDark,
        ),
      );
    }

    final line66 = await _loadGpx(kNavettoMareGpxPuntaP1P10);
    if (line66.length >= 2 &&
        _matchNavettoMareCorridor(
          from: from.point,
          to: to.point,
          corridor: line66,
          departAt: departAt,
        )) {
      hints.add(
        PercorsoNavettaHint(
          kind: PercorsoNavettaHintKind.navettoMare66,
          title: 'Navetto Mare · Linea 66',
          message:
              'Navetta gratuita per raggiungere il lungomare di Punta Marina',
          accent: NavettoMareColors.accent,
          accentDark: NavettoMareColors.accentDark,
        ),
      );
    }

    final mimaA = await _loadGpx(kNavettaMiMaGpxCongressiCorelli);
    final mimaB = await _loadGpx(kNavettaMiMaGpxCorelliCongressi);
    if (_matchMilanoMarittima(
      from: from.point,
      to: to.point,
      corridors: [mimaA, mimaB],
      departAt: departAt,
    )) {
      hints.add(
        PercorsoNavettaHint(
          kind: PercorsoNavettaHintKind.milanoMarittima,
          title: 'Navetta gratuita Milano Marittima',
          message: 'Collegamento gratuito per il lungomare di Milano Marittima',
          accent: NavettaCesenaticoColors.green,
          accentDark: NavettaCesenaticoColors.greenDark,
        ),
      );
    }

    if (_matchBusSi(from.point, to.point, departAt)) {
      hints.add(
        PercorsoNavettaHint(
          kind: PercorsoNavettaHintKind.busSi,
          title: 'BusSì',
          message: 'Trasporto a chiamata a Cesena · Biglietto € 0,50',
          accent: BusSiColors.accent,
          accentDark: BusSiColors.accentDark,
        ),
      );
    }

    return hints;
  }

  static bool _matchCesenatico(
    PercorsoEndpoint from,
    PercorsoEndpoint to,
    DateTime departAt,
  ) {
    if (!navettaCesenaticoIsActiveAt(departAt)) return false;
    return _cesenaticoPairMatches(from.point, to.point);
  }

  static bool _cesenaticoPairMatches(LatLng a, LatLng b) {
    final aNearParking =
        percorsoWalkEstimate(a, _kParcheggioCimitero).meters <=
        _kWalkToParkingMaxMeters;
    final bNearParking =
        percorsoWalkEstimate(b, _kParcheggioCimitero).meters <=
        _kWalkToParkingMaxMeters;
    final aNearStops = _isNearCesenaticoStop(a);
    final bNearStops = _isNearCesenaticoStop(b);
    return (aNearParking && bNearStops) || (bNearParking && aNearStops);
  }

  static bool _isNearCesenaticoStop(LatLng point) {
    for (final stop in _kCesenaticoDestinationStops) {
      if (_distance.as(LengthUnit.Meter, point, stop) <= _kNearStopMaxMeters) {
        return true;
      }
    }
    return false;
  }

  static bool _matchNavettoMareCorridor({
    required LatLng from,
    required LatLng to,
    required List<LatLng> corridor,
    required DateTime departAt,
  }) {
    if (!navettomareIsActiveAt(departAt)) return false;
    if (!_pointInCorridorArea(from, corridor)) return false;
    if (!_pointInCorridorArea(to, corridor)) return false;
    if (minDistanceToPolylineMeters(from, corridor) > _kNearCorridorMaxMeters) {
      return false;
    }
    if (minDistanceToPolylineMeters(to, corridor) > _kNearCorridorMaxMeters) {
      return false;
    }
    return true;
  }

  static bool _matchMilanoMarittima({
    required LatLng from,
    required LatLng to,
    required List<List<LatLng>> corridors,
    required DateTime departAt,
  }) {
    if (!navettaMiMaIsActiveAt(departAt)) return false;
    return corridors.any(
      (line) =>
          line.length >= 2 &&
          _pointOnMilanoMarittimaCorridor(from, line) &&
          _pointOnMilanoMarittimaCorridor(to, line),
    );
  }

  static bool _pointOnMilanoMarittimaCorridor(LatLng p, List<LatLng> line) {
    return minDistanceToPolylineMeters(p, line) <= _kNearCorridorMaxMeters;
  }

  static bool _matchBusSi(LatLng from, LatLng to, DateTime departAt) {
    if (!bussiIsActiveAt(departAt)) return false;
    return _isInCesenaUrban(from) && _isInCesenaUrban(to);
  }

  static bool _isInCesenaUrban(LatLng p) {
    return _pointInPolygon(p, _kCesenaUrbanPolygon);
  }

  static bool _pointInCorridorArea(LatLng p, List<LatLng> line) {
    final box = _boundsOf(line, paddingDegrees: 0.012);
    return p.latitude >= box.south &&
        p.latitude <= box.north &&
        p.longitude >= box.west &&
        p.longitude <= box.east;
  }

  static ({double south, double north, double west, double east}) _boundsOf(
    List<LatLng> points, {
    required double paddingDegrees,
  }) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final p in points) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return (
      south: south - paddingDegrees,
      north: north + paddingDegrees,
      west: west - paddingDegrees,
      east: east + paddingDegrees,
    );
  }

  static Future<List<LatLng>> _loadGpx(String asset) async {
    final cached = _gpxCache[asset];
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(asset);
      final pts = latLngsFromGpxString(raw);
      _gpxCache[asset] = pts;
      return pts;
    } catch (e, st) {
      debugPrint('PercorsoNavettaHints._loadGpx($asset): $e\n$st');
      _gpxCache[asset] = const [];
      return const [];
    }
  }
}

/// Navetta Cesenatico: sabato, domenica e festivi · 08:30–18:40 · estate.
bool navettaCesenaticoIsActiveAt(DateTime departAt) {
  final day = DateTime(departAt.year, departAt.month, departAt.day);
  if (day.isBefore(DateTime(2026, 5, 30)) ||
      day.isAfter(DateTime(2026, 9, 30))) {
    return false;
  }
  if (departAt.weekday != DateTime.saturday &&
      departAt.weekday != DateTime.sunday &&
      !_isItalianPublicHoliday(day)) {
    return false;
  }
  final minutes = departAt.hour * 60 + departAt.minute;
  return minutes >= 8 * 60 + 30 && minutes <= 18 * 60 + 40;
}

bool navettomareIsActiveAt(DateTime departAt) {
  if (!navettomareIsActiveDay(departAt)) return false;
  final minutes = departAt.hour * 60 + departAt.minute;
  if (minutes < 10 * 60) return false;
  if (departAt.month == 8) {
    return minutes < 24 * 60 || minutes <= 60;
  }
  return minutes < 24 * 60;
}

bool navettaMiMaIsActiveAt(DateTime departAt) {
  if (!navettaMiMaIsActiveDay(departAt)) return false;
  final minutes = departAt.hour * 60 + departAt.minute;
  if (minutes < 10 * 60) return false;
  if (departAt.month == 8) {
    return minutes < 24 * 60 || minutes <= 60;
  }
  return minutes < 24 * 60;
}

/// BusSì: orario estivo (7 giu – 14 set) come in pagina Navette.
bool bussiIsActiveAt(DateTime departAt) {
  final day = DateTime(departAt.year, departAt.month, departAt.day);
  if (day.isBefore(DateTime(2026, 6, 7)) ||
      day.isAfter(DateTime(2026, 9, 14))) {
    return false;
  }
  final minutes = departAt.hour * 60 + departAt.minute;
  final morning = minutes >= 8 * 60 + 30 && minutes <= 12 * 60 + 30;
  final afternoon = minutes >= 14 * 60 + 30 && minutes <= 19 * 60 + 30;
  return morning || afternoon;
}

bool _isItalianPublicHoliday(DateTime day) {
  final d = DateTime(day.year, day.month, day.day);
  final fixed = <DateTime>{
    DateTime(d.year, 1, 1),
    DateTime(d.year, 1, 6),
    DateTime(d.year, 4, 25),
    DateTime(d.year, 5, 1),
    DateTime(d.year, 6, 2),
    DateTime(d.year, 8, 15),
    DateTime(d.year, 11, 1),
    DateTime(d.year, 12, 8),
    DateTime(d.year, 12, 25),
    DateTime(d.year, 12, 26),
  };
  if (fixed.contains(d)) return true;
  return _easterMonday(d.year) == d;
}

DateTime _easterMonday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  final easter = DateTime(year, month, day);
  return easter.add(const Duration(days: 1));
}

double minDistanceToPolylineMeters(LatLng point, List<LatLng> line) {
  if (line.isEmpty) return double.infinity;
  if (line.length == 1) {
    return _distance.as(LengthUnit.Meter, point, line.first);
  }
  var min = double.infinity;
  for (var i = 0; i < line.length; i++) {
    final d = _distance.as(LengthUnit.Meter, point, line[i]);
    if (d < min) min = d;
  }
  for (var i = 0; i < line.length - 1; i++) {
    final d = _pointToSegmentMeters(point, line[i], line[i + 1]);
    if (d < min) min = d;
  }
  return min;
}

double _pointToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  final ax = a.longitude;
  final ay = a.latitude;
  final bx = b.longitude;
  final by = b.latitude;
  final px = p.longitude;
  final py = p.latitude;
  final dx = bx - ax;
  final dy = by - ay;
  if (dx == 0 && dy == 0) {
    return _distance.as(LengthUnit.Meter, p, a);
  }
  final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
  final tc = t.clamp(0.0, 1.0);
  final proj = LatLng(ay + tc * dy, ax + tc * dx);
  return _distance.as(LengthUnit.Meter, p, proj);
}

bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude;
    final yi = polygon[i].latitude;
    final xj = polygon[j].longitude;
    final yj = polygon[j].latitude;
    final intersect =
        ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-12) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

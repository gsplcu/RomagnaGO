// Genera assets/data/transit_times_by_stop.json da Open Data/{FC,RA,RN}/route_*.json.
// Per ogni stop_id raccoglie gli orari in cui parte un mezzo da quella fermata (solo «partenza» dal
// punto di vista utente): l’ultimo stop_time di ogni viaggio non conta come partenza utente, ma
// viene comunque scritto con `"end":1` (orario di arrivo al capolinea) per ricostruire il tabellone
// corsa completo nell’app senza inquinare le liste «prossime partenze».
//
// Uso (dalla root del progetto): dart run tool/gen_transit_times.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  const encoder = JsonEncoder.withIndent('  ');
  if (!_writeMergedServiceCalendars(root, encoder)) {
    exitCode = 1;
    return;
  }

  final outFile = File('${root.path}/assets/data/transit_times_by_stop.json');
  final stopNames = <String, String>{};
  for (final path in [
    '${root.path}/assets/data/fermate_fc.json',
    '${root.path}/assets/data/fermate_ra.json',
    '${root.path}/assets/data/fermate_rn.json',
  ]) {
    _mergeStopNames(File(path), stopNames);
  }

  final byStop = <String, Map<String, List<_Entry>>>{};

  for (final basinFolder in ['FC', 'RA', 'RN']) {
    final dir = Directory('${root.path}/Open Data/$basinFolder');
    if (!dir.existsSync()) {
      stderr.writeln('Cartella mancante: ${dir.path}');
      exitCode = 1;
      return;
    }
    for (final e in dir.listSync()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.isNotEmpty
          ? e.uri.pathSegments.last
          : e.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('route_') || !name.endsWith('.json')) continue;
      if (name == 'services.json') continue;
      _ingestRouteFile(e, basinFolder, stopNames, byStop);
    }
  }

  _dedupeAll(byStop);

  final stopsJson = <String, dynamic>{};
  final sortedStopIds = byStop.keys.toList()..sort();
  for (final sid in sortedStopIds) {
    final routes = byStop[sid]!;
    final routesOut = <String, dynamic>{};
    final rk = routes.keys.toList()..sort();
    for (final k in rk) {
      final list = routes[k]!;
      list.sort((a, b) => a.depSec.compareTo(b.depSec));
      routesOut[k] =
          list
              .map((e) {
                final m = <String, dynamic>{
                  'dep': e.depRaw,
                  'dest': e.dest,
                  'svc': e.serviceId,
                  'trip': e.tripId,
                  'seq': e.stopSequence,
                };
                if (e.isTripEnd) m['end'] = 1;
                return m;
              })
              .toList();
    }
    stopsJson[sid] = routesOut;
  }

  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(encoder.convert(<String, dynamic>{
    'version': 4,
    'stops': stopsJson,
  }));
  stderr.writeln(
    'OK: ${outFile.path} (${sortedStopIds.length} fermate, '
    '${_countRouteInstances(stopsJson)} combinazioni fermata×linea)',
  );
}

bool _writeMergedServiceCalendars(Directory root, JsonEncoder encoder) {
  final merged = <String, dynamic>{};
  for (final basin in ['FC', 'RA', 'RN']) {
    final sf = File('${root.path}/Open Data/$basin/services.json');
    if (!sf.existsSync()) {
      stderr.writeln('Manca ${sf.path}; impossibile generare service_calendars.json.');
      return false;
    }
    final d = json.decode(sf.readAsStringSync()) as Map<String, dynamic>;
    merged[basin] = d['service_dates'] ?? <String, dynamic>{};
  }
  final out = File('${root.path}/assets/data/service_calendars.json');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(encoder.convert(merged));
  stderr.writeln('OK: ${out.path}');
  return true;
}

int _countRouteInstances(Map<String, dynamic> stops) {
  var n = 0;
  for (final r in stops.values) {
    if (r is Map<String, dynamic>) n += r.length;
  }
  return n;
}

void _mergeStopNames(File f, Map<String, String> out) {
  if (!f.existsSync()) return;
  Map<String, dynamic>? root;
  try {
    root = json.decode(f.readAsStringSync()) as Map<String, dynamic>?;
  } catch (_) {
    return;
  }
  final stops = root!['stops'];
  if (stops is! List) return;
  for (final s in stops) {
    if (s is! Map<String, dynamic>) continue;
    final id = _normStopId(s['id']);
    final name = s['name']?.toString().trim() ?? '';
    if (id.isEmpty || name.isEmpty) continue;
    out[id] = name;
  }
}

void _ingestRouteFile(
  File f,
  String basinUpper,
  Map<String, String> stopNames,
  Map<String, Map<String, List<_Entry>>> byStop,
) {
  Map<String, dynamic> root;
  try {
    root = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    stderr.writeln('Skip (JSON invalido): ${f.path}');
    return;
  }
  final route = root['route'];
  if (route is! Map<String, dynamic>) return;
  final routeId = route['route_id']?.toString().trim() ?? '';
  if (routeId.isEmpty) return;
  final basinFromFile = route['basin']?.toString().trim().toUpperCase() ?? '';
  final basin = basinFromFile.isNotEmpty ? basinFromFile : basinUpper;
  final composite = '$basin|$routeId';

  final trips = root['trips'];
  if (trips is! List) return;

  for (final t in trips) {
    if (t is! Map<String, dynamic>) continue;
    final tripId = t['trip_id']?.toString().trim() ?? '';
    final serviceId = t['service_id']?.toString().trim() ?? '';
    final sts = t['stop_times'];
    if (sts is! List || sts.isEmpty) continue;
    final lastSt = sts.last;
    if (lastSt is! Map<String, dynamic>) continue;
    final lastId = _normStopId(lastSt['stop_id']);
    final dest =
        (lastId.isNotEmpty ? stopNames[lastId] : null) ?? 'Capolinea';

    final termIx = _tripTerminusStopIndex(sts);
    for (var i = 0; i < sts.length; i++) {
      if (sts.length > 1 && i == termIx) {
        continue;
      }
      final st = sts[i];
      if (st is! Map<String, dynamic>) continue;
      final sid = _normStopId(st['stop_id']);
      if (sid.isEmpty) continue;
      final dep =
          st['departure_time']?.toString().trim() ??
          st['arrival_time']?.toString().trim() ??
          '';
      if (dep.isEmpty) continue;
      final seq = _stopSequence(st) ?? (i + 1);
      final sec = _gtfsDepSeconds(dep);
      if (sec == null) continue;

      final map = byStop.putIfAbsent(sid, () => {});
      final list = map.putIfAbsent(composite, () => []);
      list.add(
        _Entry(
          depRaw: dep,
          depSec: sec,
          dest: dest,
          tripId: tripId,
          stopSequence: seq,
          serviceId: serviceId,
          isTripEnd: false,
        ),
      );
    }

    // Capolinea di arrivo: tabellone corsa; `end` esclude dalla UI «partenze».
    final termSt = sts[termIx];
    if (termSt is Map<String, dynamic>) {
      final sid = _normStopId(termSt['stop_id']);
      if (sid.isNotEmpty) {
        final timeRaw =
            termSt['arrival_time']?.toString().trim() ??
            termSt['departure_time']?.toString().trim() ??
            '';
        if (timeRaw.isNotEmpty) {
          final sec = _gtfsDepSeconds(timeRaw);
          if (sec != null) {
            final seq = _stopSequence(termSt) ?? (termIx + 1);
            final map = byStop.putIfAbsent(sid, () => {});
            final list = map.putIfAbsent(composite, () => []);
            list.add(
              _Entry(
                depRaw: timeRaw,
                depSec: sec,
                dest: dest,
                tripId: tripId,
                stopSequence: seq,
                serviceId: serviceId,
                isTripEnd: true,
              ),
            );
          }
        }
      }
    }
  }
}

/// Indice dello stop_time con [stop_sequence] massimo (empate: il più avanti nell’array).
int _tripTerminusStopIndex(List<dynamic> sts) {
  if (sts.isEmpty) return -1;
  var bestI = sts.length - 1;
  var bestSeq = -1;
  for (var i = 0; i < sts.length; i++) {
    final raw = sts[i];
    if (raw is! Map<String, dynamic>) continue;
    final s = _stopSequence(raw) ?? (i + 1);
    if (s > bestSeq || (s == bestSeq && i > bestI)) {
      bestSeq = s;
      bestI = i;
    }
  }
  return bestI;
}

int? _stopSequence(Map<String, dynamic> st) {
  final v = st['stop_sequence'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

void _dedupeAll(Map<String, Map<String, List<_Entry>>> byStop) {
  for (final m in byStop.values) {
    for (final list in m.values) {
      final seen = <String>{};
      final kept = <_Entry>[];
      for (final e in list) {
        final k =
            e.tripId.isNotEmpty
                ? '${e.tripId}|${e.stopSequence}'
                : '${e.depRaw}|${e.dest}|${e.serviceId}';
        if (seen.add(k)) kept.add(e);
      }
      list
        ..clear()
        ..addAll(kept);
    }
  }
}

String _normStopId(dynamic raw) {
  if (raw == null) return '';
  if (raw is num) return raw.toString().trim();
  final s = raw.toString().trim();
  return s.isEmpty ? '' : s;
}

/// Secondi dall’inizio della «giornata servizio» GTFS (ore possono essere ≥24).
int? _gtfsDepSeconds(String raw) {
  final p = raw.split(':');
  if (p.length != 3) return null;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  final s = int.tryParse(p[2].trim());
  if (h == null || m == null || s == null) return null;
  if (m < 0 || m > 59 || s < 0 || s > 59) return null;
  if (h < 0) return null;
  return h * 3600 + m * 60 + s;
}

class _Entry {
  _Entry({
    required this.depRaw,
    required this.depSec,
    required this.dest,
    required this.tripId,
    required this.stopSequence,
    required this.serviceId,
    this.isTripEnd = false,
  });

  final String depRaw;
  final int depSec;
  final String dest;
  final String tripId;
  final int stopSequence;
  final String serviceId;

  /// Ultimo stop del viaggio (orario mostrato = arrivo al capolinea).
  final bool isTripEnd;
}

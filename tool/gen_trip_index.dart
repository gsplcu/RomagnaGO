// Genera assets/data/trip_index_{fc,ra,rn}.json da Open Data/{FC,RA,RN}/route_*.json
// Uso: dart run tool/gen_trip_index.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current;
  const encoder = JsonEncoder.withIndent('  ');

  for (final basinFolder in ['FC', 'RA', 'RN']) {
    final dir = Directory('${root.path}/Open Data/$basinFolder');
    if (!dir.existsSync()) {
      stderr.writeln('Cartella mancante: ${dir.path}');
      exitCode = 1;
      return;
    }

    final trips = <String, Map<String, dynamic>>{};
    final stopRoutes = <String, Set<String>>{};

    for (final e in dir.listSync()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.isNotEmpty
          ? e.uri.pathSegments.last
          : e.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('route_') || !name.endsWith('.json')) continue;
      if (name == 'services.json') continue;
      _ingestRouteFile(e, basinFolder, trips, stopRoutes);
    }

    final tripsOut = <String, dynamic>{};
    for (final e in trips.entries) {
      tripsOut[e.key] = e.value;
    }
    final stopRoutesOut = <String, dynamic>{};
    for (final e in stopRoutes.entries) {
      stopRoutesOut[e.key] = (e.value.toList()..sort());
    }

    final outName = 'trip_index_${basinFolder.toLowerCase()}.json';
    final outFile = File('${root.path}/assets/data/$outName');
    outFile.parent.createSync(recursive: true);
    outFile.writeAsStringSync(
      encoder.convert(<String, dynamic>{
        'version': 1,
        'basin': basinFolder,
        'trips': tripsOut,
        'stopRoutes': stopRoutesOut,
      }),
    );
    stderr.writeln(
      'OK: ${outFile.path} (${tripsOut.length} trips, '
      '${stopRoutesOut.length} stops)',
    );
  }
}

void _ingestRouteFile(
  File f,
  String basinUpper,
  Map<String, Map<String, dynamic>> trips,
  Map<String, Set<String>> stopRoutes,
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

  final list = root['trips'];
  if (list is! List) return;

  for (final t in list) {
    if (t is! Map<String, dynamic>) continue;
    final tripId = t['trip_id']?.toString().trim() ?? '';
    final serviceId = t['service_id']?.toString().trim() ?? '';
    final sts = t['stop_times'];
    if (tripId.isEmpty || sts is! List || sts.isEmpty) continue;

    final compact = <List<dynamic>>[];
    for (var i = 0; i < sts.length; i++) {
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
      compact.add([sid, seq, dep]);
      stopRoutes.putIfAbsent(sid, () => {}).add(composite);
    }
    if (compact.isEmpty) continue;
    compact.sort((a, b) => (a[1] as int).compareTo(b[1] as int));

    trips[tripId] = <String, dynamic>{
      'rk': composite,
      'svc': serviceId,
      'st': compact,
    };
  }
}

int? _stopSequence(Map<String, dynamic> st) {
  final v = st['stop_sequence'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String _normStopId(dynamic raw) {
  if (raw == null) return '';
  if (raw is num) return raw.toString().trim();
  final s = raw.toString().trim();
  return s.isEmpty ? '' : s;
}

// Genera assets/data/trova_zona_*.json da startromagna.it (CLI).
// dart run tool/gen_trova_zona_cache.dart
// dart run tool/gen_trova_zona_cache.dart --zones-only

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../lib/start_trova_zona_api.dart';

const _outDir = 'assets/data';
const _arriviConcurrency = 8;
const _zoneConcurrency = 16;
const _maxRetries = 4;

Future<void> main(List<String> args) async {
  final zonesOnly = args.contains('--zones-only');
  final client = http.Client();
  try {
    if (!zonesOnly) {
      await _genPartenzeArrivi(client);
    }
    await _genZonePairs(client);
    stdout.writeln('Fatto.');
  } finally {
    client.close();
  }
}

Future<void> _genPartenzeArrivi(http.Client client) async {
  stdout.writeln('Carico zone partenza…');
  final partenze = await fetchTrovaZonaPartenze(client: client);
  final partenzeJson = <String, dynamic>{
    for (final b in TrovaZonaBacino.values)
      _key(b): [
        for (final o in partenze[b] ?? const [])
          {'code': o.code, 'label': o.label},
      ],
  };
  await _write('trova_zona_partenze.json', partenzeJson);

  final arriviJson = <String, dynamic>{
    for (final b in TrovaZonaBacino.values) _key(b): <String, dynamic>{},
  };

  for (final bacino in TrovaZonaBacino.values) {
    final bk = _key(bacino);
    final list = partenze[bacino] ?? const [];
    stdout.writeln('${bacino.label}: ${list.length} partenze → arrivi');
    var done = 0;
    for (var i = 0; i < list.length; i += _arriviConcurrency) {
      final chunk = list.skip(i).take(_arriviConcurrency).toList();
      await Future.wait([
        for (final p in chunk)
          () async {
            final arr = await _retry(
              () => fetchZoneArrivo(
                codicePartenza: p.code,
                bacino: bacino,
                client: client,
              ),
            );
            (arriviJson[bk] as Map<String, dynamic>)[p.code] = [
              for (final a in arr)
                {'code': a.code, 'label': a.label},
            ];
            done++;
            if (done % 50 == 0) stdout.writeln('  arrivi $done / ${list.length}');
          }(),
      ]);
    }
    await _write('trova_zona_arrivi.json', arriviJson);
  }

  await _write('trova_zona_arrivi.json', arriviJson);
}

Future<void> _genZonePairs(http.Client client) async {
  final arriviPath = '$_outDir/trova_zona_arrivi.json';
  if (!File(arriviPath).existsSync()) {
    stderr.writeln('Manca trova_zona_arrivi.json: esegui senza --zones-only.');
    exit(1);
  }
  final arriviRaw =
      jsonDecode(await File(arriviPath).readAsString()) as Map<String, dynamic>;

  final zoneJson = <String, dynamic>{
    for (final b in TrovaZonaBacino.values) _key(b): <String, dynamic>{},
  };

  for (final bacino in TrovaZonaBacino.values) {
    final bk = _key(bacino);
    final bacinoArrivi = arriviRaw[bk];
    if (bacinoArrivi is! Map) continue;
    final zoneMap = zoneJson[bk] as Map<String, dynamic>;

    final pairs = <(String partenza, String arrivo)>[];
    for (final entry in bacinoArrivi.entries) {
      final partenza = entry.key.toString();
      final arrList = entry.value;
      if (arrList is! List) continue;
      for (final a in arrList) {
        if (a is! Map) continue;
        final arrivo = '${a['code']}';
        if (arrivo.isEmpty || arrivo == partenza) continue;
        final pairKey = '$partenza-$arrivo';
        if (zoneMap.containsKey(pairKey)) continue;
        pairs.add((partenza, arrivo));
      }
    }

    stdout.writeln('${bacino.label}: ${pairs.length} coppie da calcolare');
    var done = 0;
    for (var i = 0; i < pairs.length; i += _zoneConcurrency) {
      final chunk = pairs.skip(i).take(_zoneConcurrency).toList();
      await Future.wait([
        for (final pair in chunk)
          () async {
            final pairKey = '${pair.$1}-${pair.$2}';
            try {
              final prezzi = await _retry(
                () => fetchZonePrezzi(
                  partenza: pair.$1,
                  arrivo: pair.$2,
                  bacino: bacino,
                  client: client,
                ),
              );
              zoneMap[pairKey] = prezzi.zoneAttraversate;
            } catch (_) {}
            done++;
            if (done % 100 == 0) {
              stdout.writeln('  ${bacino.label} $done / ${pairs.length}');
              if (done % 1000 == 0) {
                await _write('trova_zona_zone_pairs.json', zoneJson);
              }
            }
          }(),
      ]);
    }
    stdout.writeln('${bacino.label}: completato ($done coppie)');
    await _write('trova_zona_zone_pairs.json', zoneJson);
  }

  await _write('trova_zona_zone_pairs.json', zoneJson);
}

Future<T> _retry<T>(Future<T> Function() fn) async {
  Object? last;
  for (var i = 0; i < _maxRetries; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      await Future<void>.delayed(Duration(milliseconds: 400 * (i + 1)));
    }
  }
  throw last!;
}

String _key(TrovaZonaBacino b) => switch (b) {
  TrovaZonaBacino.fc => 'fc',
  TrovaZonaBacino.ra => 'ra',
  TrovaZonaBacino.rn => 'rn',
};

Future<void> _write(String name, Object data) async {
  final path = '$_outDir/$name';
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final enc = const JsonEncoder.withIndent('  ');
  await File(path).writeAsString('${enc.convert(data)}\n');
  stdout.writeln('Scritto $path (${File(path).lengthSync()} byte)');
}

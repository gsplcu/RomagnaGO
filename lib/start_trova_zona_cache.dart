// Caricamento asset cache Trova Zona (solo Flutter Web / app).

import 'dart:convert';

import 'package:flutter/services.dart';

import 'start_trova_zona_api.dart';

const String kTrovaZonaPartenzeAsset = 'assets/data/trova_zona_partenze.json';
const String kTrovaZonaArriviAsset = 'assets/data/trova_zona_arrivi.json';
const String kTrovaZonaZonePairsAsset = 'assets/data/trova_zona_zone_pairs.json';

class TrovaZonaCacheLoader {
  TrovaZonaCacheLoader._();

  static TrovaZonaOfflineData? _instance;

  static Future<TrovaZonaOfflineData> load() async {
    if (_instance != null) return _instance!;
    final partenzeRaw =
        jsonDecode(await rootBundle.loadString(kTrovaZonaPartenzeAsset))
            as Map<String, dynamic>;
    final arriviRaw =
        jsonDecode(await rootBundle.loadString(kTrovaZonaArriviAsset))
            as Map<String, dynamic>;
    final zoneRaw = await _loadZonePairsJson();

    final partenze = <TrovaZonaBacino, List<TrovaZonaOption>>{};
    final arrivi = <TrovaZonaBacino, Map<String, List<TrovaZonaOption>>>{};
    final zonePairs = <TrovaZonaBacino, Map<String, int>>{};

    for (final b in TrovaZonaBacino.values) {
      final key = _bacinoKey(b);
      partenze[b] = _parseOptionsList(partenzeRaw[key]);
      arrivi[b] = _parseArriviMap(arriviRaw[key]);
      zonePairs[b] = _parseZoneMap(zoneRaw[key]);
    }

    _instance = TrovaZonaOfflineData(
      partenze: partenze,
      arrivi: arrivi,
      zonePairs: zonePairs,
    );
    return _instance!;
  }

  static Future<Map<String, dynamic>> _loadZonePairsJson() async {
    try {
      return jsonDecode(
            await rootBundle.loadString(kTrovaZonaZonePairsAsset),
          )
          as Map<String, dynamic>;
    } catch (_) {
      return {'fc': {}, 'ra': {}, 'rn': {}};
    }
  }

  static String _bacinoKey(TrovaZonaBacino b) => switch (b) {
    TrovaZonaBacino.fc => 'fc',
    TrovaZonaBacino.ra => 'ra',
    TrovaZonaBacino.rn => 'rn',
  };

  static List<TrovaZonaOption> _parseOptionsList(Object? raw) {
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map)
          TrovaZonaOption(
            code: '${e['code']}',
            label: '${e['label']}',
          ),
    ];
  }

  static Map<String, List<TrovaZonaOption>> _parseArriviMap(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): _parseOptionsList(entry.value),
    };
  }

  static Map<String, int> _parseZoneMap(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.value is int) entry.key.toString(): entry.value as int,
    };
  }
}

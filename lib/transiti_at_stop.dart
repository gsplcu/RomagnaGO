// Indice fermata → linee in transito da assets/data/transiti.json + metadati da linee.json.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'line_display.dart';
import 'linee_percorsi.dart';
import 'quick_addresses.dart';
import 'transit_stops.dart';

/// Valore di [RomagnaLineaRow.area] per linee extraurbane in [linee.json] (bubble blu scuro / bubble «E»).
const String kRomagnaExtraurbanAreaLabel = 'Extraurbano';

/// Dati per una bubble «numero linea» + bacino in UI.
class StopTransitLineBubble {
  const StopTransitLineBubble({
    required this.lineaLabel,
    required this.bacinoUpper,
    required this.isExtraurban,
    this.secondaryGrey,
    this.scheduleRouteKeys = const [],
  });

  final String lineaLabel;
  final String bacinoUpper;
  final bool isExtraurban;

  /// Se valorizzato, sostituisce [bacinoUpper] nella parte secondaria grigia/bianca (es. `CO` per Cesenatico).
  final String? secondaryGrey;

  /// Chiavi `BACINO|route_id` in [assets/data/transit_times_by_stop.json] (vuoto = orari non consultabili).
  final List<String> scheduleRouteKeys;
}

/// Legacy: CO è ora bacino primario ([displayBasinUpper]); non usare in nuove bubble.
@Deprecated('CO è bacino primario in bubbleFromLineRow')
String? secondaryGreyForCesenaticoCoLine(RomagnaLineaRow row) => null;

/// Stato foglio inferiore: linee alla fermata + se il catalogo transiti non è stato caricato.
class BusStopSheetLinesPayload {
  const BusStopSheetLinesPayload({
    this.stopId,
    this.stopNameRaw,
    this.basinLower,
    this.isFerry = false,
    this.ferryComuneProvincia,
    required this.bubbles,
    required this.catalogLoadFailed,
    this.scheduleLoadFailed = false,
    this.quickAddressDetail,
    this.quickAddressNearbyStops = const [],
    this.quickAddressNearbyPending = false,
    this.nearbyOriginPoint,
    this.nearbyStops = const [],
    this.nearbyPending = false,
    this.nearbyAnchoredToUserLocation = true,
    this.nearbyAnchorLabel,
  });

  /// Codice fermata TPL (`TransitStopPin.stopId`), per orari da [transit_times_by_stop.json].
  final String? stopId;

  /// Bacino Start (`fc` / `ra` / `rn`) per InfoBus in tempo reale; `null` se assente o non TPL.
  final String? basinLower;

  /// Nome grezzo dal JSON fermate (titoli dialog orari).
  final String? stopNameRaw;
  final bool isFerry;
  final String? ferryComuneProvincia;
  final List<StopTransitLineBubble> bubbles;
  final bool catalogLoadFailed;

  /// `true` se il file orari generato non è stato caricato.
  final bool scheduleLoadFailed;

  /// Se valorizzato, il foglio inferiore mostra il pannello indirizzo rapido (al posto dell’elenco linee).
  final QuickAddressMarkerTapDetails? quickAddressDetail;

  /// Fermate TPL accorpate vicine al punto salvato (max 3).
  final List<TransitStopPin> quickAddressNearbyStops;

  /// `true` mentre si calcolano le fermate vicine (UI immediata come il pinpoint bus).
  final bool quickAddressNearbyPending;

  /// Origine usata per mostrare fermate vicine al punto corrente dell’utente.
  final LatLng? nearbyOriginPoint;

  /// Fermate TPL accorpate vicine al punto corrente dell’utente.
  final List<TransitStopPin> nearbyStops;

  /// `true` mentre si calcolano le fermate vicine dalla posizione corrente.
  final bool nearbyPending;

  /// `true` se [nearbyOriginPoint] è la posizione GPS; `false` se è un indirizzo da ricerca.
  final bool nearbyAnchoredToUserLocation;

  /// Etichetta indirizzo (ricerca mappa) quando [nearbyAnchoredToUserLocation] è `false`.
  final String? nearbyAnchorLabel;
}

/// Indice strict nome fermata (come in JSON fermate) → linee in transito.
class TransitiStopLinesIndex {
  TransitiStopLinesIndex._(
    this._stopToCompositeKeys,
    this._rowByComposite,
    this.unmatchedCompositeKeys,
  );

  final Map<String, List<String>> _stopToCompositeKeys;
  final Map<String, RomagnaLineaRow> _rowByComposite;
  final List<String> unmatchedCompositeKeys;

  /// Indice vuoto (errore di caricamento o assenza dati).
  factory TransitiStopLinesIndex.empty() =>
      TransitiStopLinesIndex._({}, {}, []);

  static Future<TransitiStopLinesIndex> load() async {
    final catalog = await loadLineeCatalog();
    final rowByComposite = buildLineeByComposite(catalog);

    final raw = await rootBundle.loadString('assets/data/transiti.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final list = decoded['transiti'] as List<dynamic>? ?? const [];
    final stopToKeys = <String, List<String>>{};
    final unmatched = <String>{};

    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final nome = e['nome_fermata']?.toString().trim();
      final linee = e['linee'];
      if (nome == null || nome.isEmpty || linee is! List<dynamic>) continue;
      final keys = <String>[];
      final seen = <String>{};
      for (final x in linee) {
        if (x is! String) continue;
        final normalized = _normalizeCompositeKey(x);
        if (normalized == null) continue;
        if (seen.add(normalized)) keys.add(normalized);
        if (!rowByComposite.containsKey(normalized) &&
            !_compositeResolvedByAlias(normalized, rowByComposite)) {
          unmatched.add(normalized);
        }
      }
      if (keys.isNotEmpty) {
        stopToKeys[nome] = keys;
      }
    }

    final unmatchedSorted = unmatched.toList()..sort();
    if (unmatchedSorted.isNotEmpty) {
      final preview = unmatchedSorted.take(40).join(', ');
      debugPrint(
        'TransitiStopLinesIndex: ${unmatchedSorted.length} chiavi '
        'BACINO|route_id in transiti.json senza match in linee.json. '
        'Prime 40: $preview',
      );
    }

    return TransitiStopLinesIndex._(stopToKeys, rowByComposite, unmatchedSorted);
  }

  /// Chiavi presenti solo in [transiti.json] ma risolvibili tramite alias (senza toccare i JSON).
  static bool _compositeResolvedByAlias(
    String k,
    Map<String, RomagnaLineaRow> rows,
  ) {
    if (k == 'FC|1-2CO') {
      return rows.containsKey('FC|1CO') && rows.containsKey('FC|2CO');
    }
    return false;
  }

  static String? _normalizeCompositeKey(String raw) {
    final s = raw.trim();
    final i = s.indexOf('|');
    if (i <= 0 || i >= s.length - 1) return null;
    final bacino = s.substring(0, i).trim().toUpperCase();
    final route = s.substring(i + 1).trim();
    if (bacino.isEmpty || route.isEmpty) return null;
    return '$bacino|$route';
  }

  /// True se alla fermata transita almeno una linea con [RomagnaLineaRow.area] ==
  /// [kRomagnaExtraurbanAreaLabel] in [linee.json] (incrocio con [transiti.json]).
  bool stopHasExtraurbanLineInTransit(String stopName) {
    for (final b in linesForStopNameStrict(stopName)) {
      if (b.isExtraurban) return true;
    }
    return false;
  }

  /// Strict: [stopName] deve coincidere esattamente con `nome_fermata` / `TransitStopPin.stopName`.
  /// Chiavi senza riga in [linee.json] sono omesse dall’elenco (già segnalate in log al load).
  List<StopTransitLineBubble> linesForStopNameStrict(String stopName) {
    final keys = _stopToCompositeKeys[stopName];
    if (keys == null) return [];
    final out = <StopTransitLineBubble>[];
    final seen = <String>{};
    for (final k in keys) {
      final bubble = _bubbleForCompositeKey(k);
      if (bubble == null) continue;
      if (seen.add(bubbleDisplaySignature(bubble))) out.add(bubble);
    }
    out.sort(_compareBubbles);
    return out;
  }

  StopTransitLineBubble? _bubbleForCompositeKey(String k) {
    final row = _rowByComposite[k];
    if (row == null) return null;
    return bubbleFromLineRow(row, scheduleRouteKeys: [k]);
  }

  static int _leadingIntForSort(String linea) {
    final m = RegExp(r'^(\d+)').firstMatch(linea.trim());
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }

  static int _compareBubbles(StopTransitLineBubble a, StopTransitLineBubble b) {
    final ia = _leadingIntForSort(a.lineaLabel);
    final ib = _leadingIntForSort(b.lineaLabel);
    if (ia != ib) return ia.compareTo(ib);
    return a.lineaLabel.toLowerCase().compareTo(b.lineaLabel.toLowerCase());
  }
}

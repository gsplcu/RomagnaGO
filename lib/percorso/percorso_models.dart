import 'package:latlong2/latlong.dart';

enum PercorsoProfile { fastest, minWalk, fewTransfers }

extension PercorsoProfileX on PercorsoProfile {
  String get label => switch (this) {
    PercorsoProfile.fastest => 'Più veloce',
    PercorsoProfile.minWalk => 'Meno a piedi',
    PercorsoProfile.fewTransfers => 'Meno cambi',
  };
}

/// Classificazione di un itinerario all'interno del set di risultati mostrato
/// all'utente. Permette alla UI di etichettare le 3 opzioni e mostrare un
/// banner che spiega in cosa si distingue ciascuna alternativa.
enum PercorsoRoutingLabel {
  /// Opzione 1 (tassativa): arrivo reale più rapido in assoluto.
  fastest,

  /// Riduce nettamente i metri totali a piedi (accettando un arrivo posticipato).
  lessWalking,

  /// Riduce il numero di cambi (anche se il viaggio totale è più lungo).
  fewerTransfers,

  /// Riduce i tempi morti di attesa tra un mezzo e l'altro.
  smootherTravel,
}

extension PercorsoRoutingLabelX on PercorsoRoutingLabel {
  /// Tag breve per il chip in lista.
  String get tag => switch (this) {
    PercorsoRoutingLabel.fastest => 'Più rapido',
    PercorsoRoutingLabel.lessWalking => 'Meno a piedi',
    PercorsoRoutingLabel.fewerTransfers => 'Meno cambi',
    PercorsoRoutingLabel.smootherTravel => 'Più fluido',
  };

  /// Banner esteso per il dettaglio.
  String get banner => switch (this) {
    PercorsoRoutingLabel.fastest => 'Arrivo più rapido in assoluto',
    PercorsoRoutingLabel.lessWalking =>
      'Arrivo più tardi ma con meno strada a piedi',
    PercorsoRoutingLabel.fewerTransfers => 'Più lento ma con meno cambi',
    PercorsoRoutingLabel.smootherTravel =>
      'Meno attese tra un mezzo e l\'altro',
  };
}

enum PercorsoLegKind { walk, wait, ride }

class PercorsoLeg {
  const PercorsoLeg({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.start,
    this.end,
    this.from,
    this.to,
    this.routeKey,
    this.tripId,
    this.boardStopId,
    this.alightStopId,
    this.boardSeq,
    this.alightSeq,
    this.lineLabel,
    this.isPrenotazione = false,
    this.walkPath,
  });

  final PercorsoLegKind kind;
  final String title;
  final String subtitle;
  final DateTime? start;
  final DateTime? end;
  final LatLng? from;
  final LatLng? to;
  final String? routeKey;
  final String? tripId;
  final String? boardStopId;
  final String? alightStopId;

  /// Sequenza GTFS della fermata di salita/discesa sulla corsa. Identifica il
  /// preciso passaggio su linee ad anello (dove `boardStopId`/`alightStopId`
  /// sono ambigui perché la stessa fermata compare più volte).
  final int? boardSeq;
  final int? alightSeq;

  final String? lineLabel;
  final bool isPrenotazione;

  /// Polilinea su strada (GraphHopper); se assente, fallback segmento retto in mappa.
  final List<LatLng>? walkPath;

  PercorsoLeg copyWith({
    PercorsoLegKind? kind,
    String? title,
    String? subtitle,
    DateTime? start,
    DateTime? end,
    LatLng? from,
    LatLng? to,
    String? routeKey,
    String? tripId,
    String? boardStopId,
    String? alightStopId,
    int? boardSeq,
    int? alightSeq,
    String? lineLabel,
    bool? isPrenotazione,
    List<LatLng>? walkPath,
  }) {
    return PercorsoLeg(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      start: start ?? this.start,
      end: end ?? this.end,
      from: from ?? this.from,
      to: to ?? this.to,
      routeKey: routeKey ?? this.routeKey,
      tripId: tripId ?? this.tripId,
      boardStopId: boardStopId ?? this.boardStopId,
      alightStopId: alightStopId ?? this.alightStopId,
      boardSeq: boardSeq ?? this.boardSeq,
      alightSeq: alightSeq ?? this.alightSeq,
      lineLabel: lineLabel ?? this.lineLabel,
      isPrenotazione: isPrenotazione ?? this.isPrenotazione,
      walkPath: walkPath ?? this.walkPath,
    );
  }
}

/// Unisce [PercorsoLegKind.wait] consecutive in un'unica voce di attesa.
List<PercorsoLeg> collapsePercorsoWaitLegs(List<PercorsoLeg> legs) {
  final out = <PercorsoLeg>[];
  for (final leg in legs) {
    if (leg.kind == PercorsoLegKind.wait &&
        out.isNotEmpty &&
        out.last.kind == PercorsoLegKind.wait) {
      final prev = out.last;
      final mergedEnd = leg.end ?? prev.end;
      final mergedStart = prev.start;
      out[out.length - 1] = prev.copyWith(
        title: 'Attesa',
        end: mergedEnd,
        subtitle: _mergedWaitSubtitle(mergedStart, mergedEnd),
      );
      continue;
    }
    if (leg.kind == PercorsoLegKind.wait) {
      out.add(leg.copyWith(title: 'Attesa'));
      continue;
    }
    out.add(leg);
  }
  return out;
}

String _mergedWaitSubtitle(DateTime? start, DateTime? end) {
  if (start == null || end == null) return '';
  final minutes = end.difference(start).inMinutes;
  if (minutes <= 0) return '';
  return '$minutes min';
}

class PercorsoEndpoint {
  const PercorsoEndpoint({
    required this.label,
    required this.point,
    this.stopId,
    this.stopName,
    this.stopClusterIds = const [],
  });

  final String label;
  final LatLng point;
  final String? stopId;
  final String? stopName;

  /// Tutti gli stop_id della piattaforma (es. 10821+10822); il planner ne sceglie uno.
  final List<String> stopClusterIds;

  bool get isStop =>
      (stopId != null && stopId!.isNotEmpty) || stopClusterIds.isNotEmpty;

  List<String> get effectiveStopIds {
    if (stopClusterIds.isNotEmpty) return stopClusterIds;
    final id = stopId?.trim();
    if (id != null && id.isNotEmpty) return [id];
    return const [];
  }
}

enum PercorsoPlanQuality {
  /// Corrisponde all’orario e al giorno richiesti.
  strict,

  /// Stesso giorno, partenza dopo l’orario richiesto o fermate più lontane.
  laterToday,

  /// Giorno diverso da quello scelto (prossimo servizio in calendario).
  otherDay,

  /// Nessun TPL: solo percorso a piedi indicativo.
  walkOnlyFallback,
}

class PercorsoPlanResult {
  const PercorsoPlanResult({
    required this.itineraries,
    required this.quality,
    this.userHint,
    this.suggestedDayOffset = 0,
    this.suggestTrain = false,
  });

  final List<PercorsoItinerary> itineraries;
  final PercorsoPlanQuality quality;
  final String? userHint;

  /// Giorni rispetto alla data richiesta (es. +1 = domani).
  final int suggestedDayOffset;

  /// Percorso molto frammentato: suggerire di valutare il treno.
  final bool suggestTrain;

  bool get hasTransit =>
      itineraries.any((it) => it.legs.any((l) => l.kind == PercorsoLegKind.ride));
}

/// Percorso interamente a piedi (nessuna corsa TPL, neanche 1 m su mezzo).
bool percorsoItineraryIsPureWalk(PercorsoItinerary it) {
  if (it.legs.any((l) => l.kind == PercorsoLegKind.ride)) return false;
  return it.legs.any((l) => l.kind == PercorsoLegKind.walk);
}

/// Mostra «Indicazioni stradali» solo per fallback calendario senza TPL.
bool percorsoShowsTurnByTurnNavigation({
  required PercorsoItinerary itinerary,
  String? planUserHint,
}) {
  if (!percorsoItineraryIsPureWalk(itinerary)) return false;
  final hint = planUserHint?.trim() ?? '';
  return hint.contains('Nessun servizio TPL in calendario');
}

(LatLng?, LatLng?) percorsoWalkEndpoints(PercorsoItinerary it) {
  LatLng? from;
  LatLng? to;
  for (final leg in it.legs) {
    if (leg.kind != PercorsoLegKind.walk) continue;
    from ??= leg.from;
    if (leg.to != null) to = leg.to;
  }
  return (from, to);
}

class PercorsoItinerary {
  const PercorsoItinerary({
    required this.legs,
    required this.totalDuration,
    required this.walkMeters,
    required this.transfers,
    required this.profile,
    this.recommendedWalkOnly = false,
    this.hasPrenotazione = false,
    this.departsLaterThanRequested = false,
    this.planQuality = PercorsoPlanQuality.strict,
    this.suggestedDayOffset = 0,
    this.score = 0,
    this.hasBrokenWalkConnection = false,
    this.routingLabel,
  });

  final List<PercorsoLeg> legs;
  final Duration totalDuration;
  final double walkMeters;
  final int transfers;
  final PercorsoProfile profile;
  final bool recommendedWalkOnly;
  final bool hasPrenotazione;

  /// Prima salita TPL dopo l’orario di partenza richiesto (attesa lunga).
  final bool departsLaterThanRequested;
  final PercorsoPlanQuality planQuality;
  final int suggestedDayOffset;
  final double score;

  /// `true` se, dopo l'arricchimento pedonale reale (GraphHopper), un tratto a
  /// piedi sfora l'orario di salita della corsa successiva: la coincidenza è
  /// di fatto persa e l'itinerario va segnalato come non garantito.
  final bool hasBrokenWalkConnection;

  /// Classificazione per la UI (Opzione 1/2/3). `null` se non in un set
  /// diversificato (es. fallback a piedi).
  final PercorsoRoutingLabel? routingLabel;

  PercorsoItinerary copyWith({
    List<PercorsoLeg>? legs,
    Duration? totalDuration,
    double? walkMeters,
    int? transfers,
    PercorsoProfile? profile,
    bool? recommendedWalkOnly,
    bool? hasPrenotazione,
    bool? departsLaterThanRequested,
    PercorsoPlanQuality? planQuality,
    int? suggestedDayOffset,
    double? score,
    bool? hasBrokenWalkConnection,
    PercorsoRoutingLabel? routingLabel,
  }) {
    return PercorsoItinerary(
      legs: legs ?? this.legs,
      totalDuration: totalDuration ?? this.totalDuration,
      walkMeters: walkMeters ?? this.walkMeters,
      transfers: transfers ?? this.transfers,
      profile: profile ?? this.profile,
      recommendedWalkOnly: recommendedWalkOnly ?? this.recommendedWalkOnly,
      hasPrenotazione: hasPrenotazione ?? this.hasPrenotazione,
      departsLaterThanRequested:
          departsLaterThanRequested ?? this.departsLaterThanRequested,
      planQuality: planQuality ?? this.planQuality,
      suggestedDayOffset: suggestedDayOffset ?? this.suggestedDayOffset,
      score: score ?? this.score,
      hasBrokenWalkConnection:
          hasBrokenWalkConnection ?? this.hasBrokenWalkConnection,
      routingLabel: routingLabel ?? this.routingLabel,
    );
  }

  String get summaryLine {
    final parts = <String>[];
    parts.add(_formatDur(totalDuration));
    if (walkMeters > 0) {
      parts.add('${_walkMin(walkMeters)} min a piedi');
    }
    if (transfers == 0 && legs.any((l) => l.kind == PercorsoLegKind.ride)) {
      parts.add('diretto');
    } else if (transfers > 0) {
      parts.add(
        transfers == 1 ? '1 cambio' : '$transfers cambi',
      );
    }
    return parts.join(' · ');
  }

  static String _formatDur(Duration d) {
    if (d.isNegative) return '—';
    final m = d.inMinutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}min';
  }

  static int _walkMin(double meters) => (meters / 80).round().clamp(1, 999);
}

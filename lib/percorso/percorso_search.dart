import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../linee_percorsi.dart';
import '../service_calendar.dart';
import '../stop_transit_schedule.dart';
import '../transit_stops.dart';
import 'percorso_constants.dart';
import 'percorso_index.dart';
import '../line_display.dart';
import 'percorso_models.dart';
import 'percorso_service_day.dart';
import 'percorso_stops.dart';
import 'percorso_walk.dart';
import 'percorso_transfer_graph.dart';
import 'percorso_transit_graph.dart';
import 'percorso_transit_graph_build.dart';
import 'route_evaluator.dart';

class PercorsoSearchService {

  PercorsoSearchService({
    required this.planner,
    required this.schedule,
    required this.calendar,
    required this.stopById,
    required this.lineByRouteKey,
    required this.transitGraph,
  });

  final PercorsoPlannerIndex planner;
  final StopTransitScheduleIndex schedule;
  final ServiceCalendarIndex calendar;
  final Map<String, TransitStopPin> stopById;
  final Map<String, RomagnaLineaRow> lineByRouteKey;

  /// Preprocessing OTP-like: StopArea + grafo trasferimenti a piedi.
  final PercorsoTransitGraph transitGraph;

  static PercorsoSearchService? _cached;
  static Future<PercorsoSearchService?>? _loading;

  static Future<PercorsoSearchService?> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _loadInternal().then((svc) {
      if (svc != null) _cached = svc;
      return svc;
    });
  }

  static Future<PercorsoSearchService?> _loadInternal() async {
    final plannerFuture = PercorsoPlannerIndex.load();
    final calendarFuture = ServiceCalendarIndex.load();
    final stopsFuture = loadTransitStopsFromAssets();
    final lineeFuture = loadLineeCatalog();
    final gtfsFuture = GtfsTransferIndex.tryLoadFromAssets();
    final scheduleFuture = calendarFuture.then(
      (cal) => StopTransitScheduleIndex.load(calendar: cal),
    );

    final planner = await plannerFuture;
    if (planner.loadFailed) return null;

    final results = await Future.wait([
      calendarFuture,
      stopsFuture,
      lineeFuture,
      gtfsFuture,
      scheduleFuture,
    ]);
    final calendar = results[0] as ServiceCalendarIndex;
    final stops = results[1] as List<TransitStopPin>;
    final linee = results[2] as List<RomagnaLineaRow>;
    final gtfsTransfers = results[3] as GtfsTransferIndex;
    final schedule = results[4] as StopTransitScheduleIndex;

    final stopById = <String, TransitStopPin>{};
    for (final s in stops) {
      final id = s.stopId.trim();
      if (id.isNotEmpty) stopById[id] = s;
    }

    final transitGraph = await buildPercorsoTransitGraphAsync(
      stops: stops,
      gtfsTransfers: gtfsTransfers.rules,
    );

    final lineByRouteKey = buildLineeByComposite(linee);
    return PercorsoSearchService(
      planner: planner,
      schedule: schedule,
      calendar: schedule.serviceCalendarOrNull ?? calendar,
      stopById: stopById,
      lineByRouteKey: lineByRouteKey,
      transitGraph: transitGraph,
    );
  }

  bool _tripRunsOn(TripRecord trip, DateTime day) {
    if (!calendar.isUsable) return true;
    return calendar.serviceRunsOn(trip.basin, trip.serviceId, day);
  }

  /// Fonte unica di verità per paline gemelle / stazioni multi-bacino.
  Set<String> resolveStopClusterIds(String stopId) =>
      transitGraph.resolveEquivalentStopIds(stopId);

  Future<List<PercorsoItinerary>> plan({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required PercorsoProfile profile,
  }) async =>
      (await planDetailed(
        from: from,
        to: to,
        departAt: departAt,
        profile: profile,
      )).itineraries;

  Future<PercorsoPlanResult> planDetailed({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required PercorsoProfile profile,
  }) async {
    try {
      return await _planDetailedInternal(
        from: from,
        to: to,
        departAt: departAt,
        profile: profile,
      );
    } catch (e, st) {
      debugPrint('PercorsoSearchService.planDetailed: $e\n$st');
      final walk = percorsoWalkEstimate(from.point, to.point);
      return _walkFallback(
        from: from,
        to: to,
        departAt: departAt,
        profile: profile,
        walkDirect: walk,
      );
    }
  }

  Future<PercorsoPlanResult> _planDetailedInternal({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required PercorsoProfile profile,
  }) async {
    if (planner.loadFailed || schedule.loadFailed) {
      return const PercorsoPlanResult(
        itineraries: [],
        quality: PercorsoPlanQuality.walkOnlyFallback,
        userHint: 'Dati percorsi non disponibili',
      );
    }
    if (!isValidPlannerLatLng(from.point) || !isValidPlannerLatLng(to.point)) {
      return const PercorsoPlanResult(
        itineraries: [],
        quality: PercorsoPlanQuality.walkOnlyFallback,
        userHint: 'Coordinate non valide',
      );
    }

    final epFrom = _endpointWithResolvedStopArea(from);
    final epTo = _endpointWithResolvedStopArea(to);

    final walkDirect = percorsoWalkEstimate(epFrom.point, epTo.point);

    if (walkDirect.meters >= PercorsoConstants.longHaulSkipTransitMeters) {
      return _longHaulTrainResult(
        from: epFrom,
        to: epTo,
        departAt: departAt,
        profile: profile,
        walkDirect: walkDirect,
      );
    }

    final isLong =
        walkDirect.meters >= PercorsoConstants.trainHintThresholdMeters;
    final budget = Stopwatch()..start();

    final requestedDay = PercorsoServiceDay.plannerServiceDay(departAt);

    final strict = _searchPhase(
      from: epFrom,
      to: epTo,
      departAt: departAt,
      day: requestedDay,
      profile: profile,
      walkDirect: walkDirect,
      quality: PercorsoPlanQuality.strict,
      dayOffset: 0,
      expandedStops: false,
      longDistance: isLong,
      budget: budget,
    );
    if (strict.hasTransit) {
      final augmented = _augmentForliDovadola(
        partial: strict,
        from: epFrom,
        to: epTo,
        departAt: departAt,
        day: requestedDay,
        profile: profile,
        walkDirectMeters: walkDirect.meters,
        budget: budget,
      );
      var out = augmented ?? strict;
      final cesenaForli = _augmentCesenaForliCorridor(
        partial: out,
        from: epFrom,
        to: epTo,
        departAt: departAt,
        day: requestedDay,
        profile: profile,
        walkDirectMeters: walkDirect.meters,
        budget: budget,
      );
      out = _mergeAugmentedPlans(out, cesenaForli);
      final cesenaSofia = _augmentCesenaSantaSofiaCorridor(
        partial: out,
        from: epFrom,
        to: epTo,
        departAt: departAt,
        day: requestedDay,
        profile: profile,
        walkDirectMeters: walkDirect.meters,
        budget: budget,
      );
      if (cesenaSofia != null) out = cesenaSofia;
      final riminiExtra = _augmentCesenaticoRimini(
        from: epFrom,
        to: epTo,
        departAt: departAt,
        day: requestedDay,
        profile: profile,
        walkDirectMeters: walkDirect.meters,
        budget: budget,
      );
      out = _mergeAugmentedPlans(out, riminiExtra);
      return isLong ? _withTrainHint(out) : out;
    }

    final riminiCorridor = _augmentCesenaticoRimini(
      from: epFrom,
      to: epTo,
      departAt: departAt,
      day: requestedDay,
      profile: profile,
      walkDirectMeters: walkDirect.meters,
      budget: budget,
    );
    if (riminiCorridor != null && riminiCorridor.hasTransit) {
      return isLong ? _withTrainHint(riminiCorridor) : riminiCorridor;
    }

    await Future<void>.delayed(Duration.zero);
    if (budget.elapsedMilliseconds >= PercorsoConstants.searchBudgetMs) {
      return _walkFallback(from: epFrom, to: epTo, departAt: departAt,
          profile: profile, walkDirect: walkDirect, suggestTrain: isLong);
    }

    final later = _searchPhase(
      from: epFrom,
      to: epTo,
      departAt: departAt,
      day: requestedDay,
      profile: profile,
      walkDirect: walkDirect,
      quality: PercorsoPlanQuality.laterToday,
      dayOffset: 0,
      expandedStops: true,
      longDistance: isLong,
      budget: budget,
    );
    if (later.hasTransit) {
      return isLong ? _withTrainHint(later) : later;
    }

    final maxDays = isLong
        ? PercorsoConstants.ldMaxAdjacentDaySearch
        : PercorsoConstants.maxAdjacentDaySearch;

    for (var offset = 1; offset <= maxDays; offset++) {
      for (final sign in const [1, -1]) {
        await Future<void>.delayed(Duration.zero);
        if (budget.elapsedMilliseconds >= PercorsoConstants.searchBudgetMs) {
          return _walkFallback(from: epFrom, to: epTo, departAt: departAt,
              profile: profile, walkDirect: walkDirect, suggestTrain: isLong);
        }
        final shiftedDay = requestedDay.add(Duration(days: sign * offset));
        final shiftedDepart = DateTime(
          shiftedDay.year,
          shiftedDay.month,
          shiftedDay.day,
          departAt.hour,
          departAt.minute,
        );
        final other = _searchPhase(
          from: epFrom,
          to: epTo,
          departAt: shiftedDepart,
          day: shiftedDay,
          profile: profile,
          walkDirect: walkDirect,
          quality: PercorsoPlanQuality.otherDay,
          dayOffset: sign * offset,
          expandedStops: true,
          longDistance: isLong,
          budget: budget,
        );
        if (other.hasTransit) return other;
      }
    }

    final riminiLate = _augmentCesenaticoRimini(
      from: epFrom,
      to: epTo,
      departAt: departAt,
      day: requestedDay,
      profile: profile,
      walkDirectMeters: walkDirect.meters,
      budget: budget,
    );
    if (riminiLate != null && riminiLate.hasTransit) {
      return isLong ? _withTrainHint(riminiLate) : riminiLate;
    }

    return _walkFallback(
      from: epFrom,
      to: epTo,
      departAt: departAt,
      profile: profile,
      walkDirect: walkDirect,
      suggestTrain: isLong,
    );
  }

  /// Zadina→Dovadola: F126 fino a Forlì Punto Bus (1660), poi F127 (evita km a piedi da Carpinello).
  PercorsoPlanResult? _augmentForliDovadola({
    required PercorsoPlanResult partial,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
    Stopwatch? budget,
  }) {
    final preferVia = _preferViaStopIds(to);
    if (!preferVia.contains('1660') || !preferVia.contains('17881')) {
      return null;
    }
    if (partial.itineraries.isNotEmpty &&
        _forliDovadolaCorridorIsGood(partial.itineraries.first)) {
      return null;
    }

    final hub = stopById['1660'];
    if (hub == null) return null;

    final forliEndpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(hub.stopName),
      point: hub.point,
      stopId: '1660',
    );

    final headCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: headCandidates,
      from: from,
      to: forliEndpoint,
      departAt: departAt,
      day: day,
      profile: profile,
      stopsA: _stopCandidates(from, expanded: true),
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (headCandidates.isEmpty) return null;
    headCandidates.sort((a, b) => a.score.compareTo(b.score));

    PercorsoItinerary? headIt;
    for (final c in headCandidates) {
      final rides =
          c.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride);
      final last = rides.lastOrNull;
      if (last?.routeKey != 'FC|F126') continue;
      if (last!.alightStopId == '1660') {
        headIt = c.itinerary;
        break;
      }
      final pin = stopById[last.alightStopId ?? ''];
      if (pin == null) continue;
      final w = percorsoWalkEstimate(pin.point, hub.point);
      if (w.meters <= PercorsoConstants.maxHubTransferWalkMeters) {
        headIt = c.itinerary;
        break;
      }
    }
    if (headIt == null) return null;

    final headRides =
        headIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (headRides.isEmpty) return null;
    final lastHead = headRides.last;
    final alightHeadPin =
        stopById[lastHead.alightStopId ?? '1660'] ?? hub;
    final hubWalk = percorsoWalkEstimate(alightHeadPin.point, hub.point);
    if (lastHead.alightStopId != '1660' &&
        hubWalk.meters > PercorsoConstants.maxHubTransferWalkMeters) {
      return null;
    }

    var hubDepart = lastHead.end ?? departAt;
    if (lastHead.alightStopId != '1660') {
      hubDepart = hubDepart.add(hubWalk.duration).add(
        Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
      );
    }
    final hubDepartAt = DateTime(
      day.year,
      day.month,
      day.day,
      hubDepart.hour,
      hubDepart.minute,
    );
    final hubFrom = PercorsoEndpoint(
      label: transitStopNameForDisplay(hub.stopName),
      point: hub.point,
      stopId: '1660',
    );

    final tailCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: tailCandidates,
      from: hubFrom,
      to: to,
      departAt: hubDepartAt,
      day: day,
      profile: profile,
      stopsA: [
        _StopCandidate(
          pin: hub,
          stopIds: const ['1660'],
          accessWalk: (meters: 0, duration: Duration.zero),
        ),
      ],
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (tailCandidates.isEmpty) return null;
    tailCandidates.sort((a, b) => a.score.compareTo(b.score));
    final tail = tailCandidates.first.itinerary;
    if (!tail.legs.any((l) => l.routeKey == 'FC|F127')) return null;

    final mergedLegs = <PercorsoLeg>[...headIt.legs];
    var cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : departAt;
    if (lastHead.alightStopId != '1660' && hubWalk.meters > 1) {
      final hubWalkEnd = cursor?.add(hubWalk.duration) ?? hubDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(hubWalk.meters),
        start: cursor,
        end: hubWalkEnd,
        from: alightHeadPin.point,
        to: hub.point,
      ));
      cursor = hubWalkEnd;
    }
    for (final l in tail.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.subtitle?.contains('Verso destinazione') == true) {
        continue;
      }
      mergedLegs.add(
        l.copyWith(
          start: l.start != null && cursor != null
              ? (l.start!.isBefore(cursor) ? cursor : l.start)
              : l.start,
        ),
      );
    }

    _optimizeTransferAlightsOnLegs(mergedLegs, day);
    _optimizeFinalEgressAlightOnLegs(mergedLegs, to, day);

    var walkMeters = 0.0;
    for (final l in mergedLegs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    var transfers = 0;
    var sawRide = false;
    for (final l in mergedLegs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (sawRide) transfers++;
        sawRide = true;
      }
    }

    final merged = PercorsoItinerary(
      legs: mergedLegs,
      totalDuration: (mergedLegs.last.end ?? hubDepartAt).difference(departAt),
      walkMeters: walkMeters,
      transfers: transfers,
      profile: profile,
      hasPrenotazione: headIt.hasPrenotazione || tail.hasPrenotazione,
    );

    if (_isNonsensicalItinerary(
      merged,
      day,
      odDirectMeters: walkDirectMeters,
    )) {
      return null;
    }

    return PercorsoPlanResult(
      itineraries: [merged],
      quality: partial.quality,
      suggestedDayOffset: partial.suggestedDayOffset,
      suggestTrain: partial.suggestTrain,
      userHint: partial.userHint,
    );
  }

  bool _forliDovadolaCorridorIsGood(PercorsoItinerary it) {
    if (!it.legs.any((l) => l.routeKey == 'FC|F127')) return false;
    final f126 =
        it.legs.where((l) => l.routeKey == 'FC|F126').lastOrNull;
    if (f126 == null) return false;
    final hub = stopById['1660'];
    if (hub == null) return false;
    if (f126.alightStopId == '1660') return true;
    final pin = stopById[f126.alightStopId ?? ''];
    if (pin == null) return false;
    return percorsoWalkEstimate(pin.point, hub.point).meters <=
        PercorsoConstants.maxHubTransferWalkMeters;
  }

  PercorsoPlanResult _mergeAugmentedPlans(
    PercorsoPlanResult base,
    PercorsoPlanResult? extra,
  ) {
    if (extra == null || extra.itineraries.isEmpty) return base;
    final merged = [...base.itineraries];
    for (final it in extra.itineraries) {
      final sig = _itineraryRideSignature(it);
      if (merged.any((o) => _itineraryRideSignature(o) == sig)) continue;
      merged.add(it);
    }
    merged.sort((a, b) => a.totalDuration.compareTo(b.totalDuration));
    final max = PercorsoConstants.maxItinerariesReturned;
    final capped = merged.length > max ? merged.sublist(0, max) : merged;
    return PercorsoPlanResult(
      itineraries: capped,
      quality: base.quality,
      suggestedDayOffset: base.suggestedDayOffset,
      suggestTrain: base.suggestTrain || extra.suggestTrain,
      userHint: base.userHint,
    );
  }

  String _itineraryRideSignature(PercorsoItinerary it) {
    return it.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map(
          (l) =>
              '${l.routeKey}|${l.tripId}|${l.boardStopId}|${l.alightStopId}',
        )
        .join(';');
  }

  bool _itineraryUsesAllRoutes(PercorsoItinerary it, Set<String> routeKeys) {
    final rides = it.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.routeKey)
        .whereType<String>()
        .toSet();
    return routeKeys.every(rides.contains);
  }

  /// Cesenatico → Forlì: 94 fino a Cesena A2, cambio a piedi su B2, 92 fino a Punto Bus.
  PercorsoPlanResult? _augmentCesenaForliCorridor({
    required PercorsoPlanResult partial,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
    Stopwatch? budget,
  }) {
    final preferVia = _preferViaStopIds(to);
    if (!preferVia.contains('1660') || preferVia.contains('999B2')) {
      return null;
    }
    if (partial.itineraries.any(
      (it) => _itineraryUsesAllRoutes(it, {'FC|S094', 'FC|S092'}),
    )) {
      return null;
    }

    final merged = _buildCesenaA2B2S092Itinerary(
      from: from,
      to: to,
      departAt: departAt,
      day: day,
      profile: profile,
      walkDirectMeters: walkDirectMeters,
      includeTailToDestination: true,
    );
    if (merged == null) return null;

    return PercorsoPlanResult(
      itineraries: [merged],
      quality: partial.quality,
      suggestedDayOffset: partial.suggestedDayOffset,
      suggestTrain: partial.suggestTrain,
      userHint: partial.userHint,
    );
  }

  /// Tratto comune Cesena hub: S094 → A2, a piedi → B2, S092 → Forlì Punto Bus (1660).
  PercorsoItinerary? _buildCesenaA2B2S092Itinerary({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
    required bool includeTailToDestination,
  }) {
    final a2 = stopById['999A2'];
    final b2 = stopById['999B2'];
    final forliHub = stopById['1660'];
    if (a2 == null || b2 == null || forliHub == null) return null;

    final a2Endpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(a2.stopName),
      point: a2.point,
      stopId: '999A2',
    );

    final headCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: headCandidates,
      from: from,
      to: a2Endpoint,
      departAt: departAt,
      day: day,
      profile: profile,
      stopsA: _stopCandidates(from, expanded: true),
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (headCandidates.isEmpty) return null;
    headCandidates.sort((a, b) => a.score.compareTo(b.score));

    PercorsoItinerary? headIt;
    for (final c in headCandidates) {
      if (c.itinerary.legs.any((l) => l.routeKey == 'FC|S094')) {
        headIt = c.itinerary;
        break;
      }
    }
    if (headIt == null) return null;

    final headRides =
        headIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (headRides.isEmpty) return null;

    final lastHead = headRides.last;
    final alightHead =
        stopById[lastHead.alightStopId ?? '999A2'] ?? a2;
    final hubWalk = percorsoWalkEstimate(alightHead.point, b2.point);
    if (hubWalk.meters > _hubTransferWalkMeters(alightHead)) return null;

    var hubDepart = lastHead.end ?? departAt;
    hubDepart = hubDepart.add(hubWalk.duration).add(
      Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
    );
    final hubDepartAt = DateTime(
      day.year,
      day.month,
      day.day,
      hubDepart.hour,
      hubDepart.minute,
    );

    final hubFrom = PercorsoEndpoint(
      label: transitStopNameForDisplay(b2.stopName),
      point: b2.point,
      stopId: '999B2',
    );
    final forliEndpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(forliHub.stopName),
      point: forliHub.point,
      stopId: '1660',
    );
    final b2Stops = resolveStopClusterIds(b2.stopId).toList()..sort();

    final midCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: midCandidates,
      from: hubFrom,
      to: forliEndpoint,
      departAt: hubDepartAt,
      day: day,
      profile: profile,
      stopsA: [
        _StopCandidate(
          pin: b2,
          stopIds: b2Stops,
          accessWalk: (meters: 0, duration: Duration.zero),
        ),
      ],
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (midCandidates.isEmpty) return null;
    midCandidates.sort((a, b) => a.score.compareTo(b.score));

    const forli92AlightIds = {'1660', '3120D', '151', '491', '1891'};
    PercorsoItinerary? midIt;
    for (final c in midCandidates) {
      final rides =
          c.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride);
      final last = rides.lastOrNull;
      if (last?.routeKey == 'FC|S092' &&
          last?.alightStopId != null &&
          forli92AlightIds.contains(last!.alightStopId!)) {
        midIt = c.itinerary;
        break;
      }
    }
    if (midIt == null) {
      for (final c in midCandidates) {
        if (c.itinerary.legs.any((l) => l.routeKey == 'FC|S092')) {
          midIt = c.itinerary;
          break;
        }
      }
    }
    if (midIt == null) return null;

    final midRides =
        midIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (midRides.isEmpty) return null;
    final lastMid = midRides.last;
    final midAlightPin =
        stopById[lastMid.alightStopId ?? '3120D'] ?? forliHub;
    final midToPuntoBus = percorsoWalkEstimate(
      midAlightPin.point,
      forliHub.point,
    );
    if (lastMid.alightStopId != '1660' &&
        midToPuntoBus.meters > PercorsoConstants.maxHubTransferWalkMeters) {
      return null;
    }

    final mergedLegs = <PercorsoLeg>[...headIt.legs];
    var cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : departAt;
    if (hubWalk.meters > 1) {
      final hubWalkEnd = cursor?.add(hubWalk.duration) ?? hubDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(hubWalk.meters),
        start: cursor,
        end: hubWalkEnd,
        from: alightHead.point,
        to: b2.point,
      ));
      cursor = hubWalkEnd;
    }
    for (final l in midIt.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.subtitle?.contains('Verso destinazione') == true) {
        continue;
      }
      mergedLegs.add(
        l.copyWith(
          start: l.start != null && cursor != null
              ? (l.start!.isBefore(cursor) ? cursor : l.start)
              : l.start,
        ),
      );
    }
    cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : cursor;
    if (lastMid.alightStopId != '1660' && midToPuntoBus.meters > 1) {
      final wEnd = cursor?.add(midToPuntoBus.duration) ?? hubDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(midToPuntoBus.meters),
        start: cursor,
        end: wEnd,
        from: midAlightPin.point,
        to: forliHub.point,
      ));
      cursor = wEnd;
    }

    var hasPrenotazione = headIt.hasPrenotazione || midIt.hasPrenotazione;

    if (includeTailToDestination) {
      var forliDepart = lastMid.end ?? hubDepartAt;
      forliDepart = forliDepart
          .add(
            lastMid.alightStopId == '1660'
                ? Duration.zero
                : midToPuntoBus.duration,
          )
          .add(
        Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
      );
      final forliDepartAt = DateTime(
        day.year,
        day.month,
        day.day,
        forliDepart.hour,
        forliDepart.minute,
      );
      final forliFrom = PercorsoEndpoint(
        label: transitStopNameForDisplay(forliHub.stopName),
        point: forliHub.point,
        stopId: '1660',
      );
      final tailCandidates = <_ScoredItinerary>[];
      _searchRaptor(
        candidates: tailCandidates,
        from: forliFrom,
        to: to,
        departAt: forliDepartAt,
        day: day,
        profile: profile,
        stopsA: [
          _StopCandidate(
            pin: forliHub,
            stopIds: const ['1660'],
            accessWalk: (meters: 0, duration: Duration.zero),
          ),
        ],
        longDistance:
            walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
      );
      if (tailCandidates.isNotEmpty) {
        tailCandidates.sort((a, b) => a.score.compareTo(b.score));
        final tail = tailCandidates.first.itinerary;
        for (final l in tail.legs) {
          if (l.kind == PercorsoLegKind.walk &&
              l.subtitle?.contains('Verso destinazione') == true) {
            continue;
          }
          mergedLegs.add(
            l.copyWith(
              start: l.start != null && cursor != null
                  ? (l.start!.isBefore(cursor) ? cursor : l.start)
                  : l.start,
            ),
          );
        }
        hasPrenotazione = hasPrenotazione || tail.hasPrenotazione;
      }
    }

    _optimizeTransferAlightsOnLegs(mergedLegs, day);
    _optimizeFinalEgressAlightOnLegs(mergedLegs, to, day);
    _collapseRedundantTransferWalks(mergedLegs);

    var walkMeters = 0.0;
    for (final l in mergedLegs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    var transfers = 0;
    var sawRide = false;
    for (final l in mergedLegs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (sawRide) transfers++;
        sawRide = true;
      }
    }

    final endTime = mergedLegs.last.end ?? hubDepartAt;
    return PercorsoItinerary(
      legs: mergedLegs,
      totalDuration: endTime.difference(departAt),
      walkMeters: walkMeters,
      transfers: transfers,
      profile: profile,
      hasPrenotazione: hasPrenotazione,
    );
  }

  PercorsoItinerary? _buildCesenaticoRiminiHubItinerary({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required TransitStopPin headHubPin,
    required String headHubStopId,
    required Set<String> preferHeadRoutes,
    required TransitStopPin rnHubPin,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
  }) {
    final headEndpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(headHubPin.stopName),
      point: headHubPin.point,
      stopId: headHubStopId,
    );

    final headCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: headCandidates,
      from: from,
      to: headEndpoint,
      departAt: departAt,
      day: day,
      profile: profile,
      stopsA: _stopCandidates(from, expanded: true),
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (headCandidates.isEmpty) return null;
    headCandidates.sort((a, b) => a.score.compareTo(b.score));

    PercorsoItinerary? headIt;
    for (final c in headCandidates) {
      final keys = c.itinerary.legs
          .where((l) => l.kind == PercorsoLegKind.ride)
          .map((l) => l.routeKey)
          .whereType<String>();
      if (keys.any(preferHeadRoutes.contains)) {
        headIt = c.itinerary;
        break;
      }
    }
    if (headIt == null) return null;

    final headRides =
        headIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (headRides.isEmpty) return null;

    final lastRide = headRides.last;
    final alightPin =
        stopById[lastRide.alightStopId ?? headHubStopId] ?? headHubPin;
    final hubWalk = percorsoWalkEstimate(alightPin.point, rnHubPin.point);
    if (hubWalk.meters > PercorsoConstants.maxCesenaticoHubTransferWalkMeters) {
      return null;
    }

    var hubDepart = lastRide.end ?? departAt;
    hubDepart = hubDepart.add(hubWalk.duration).add(
      Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
    );
    final hubDepartAt = DateTime(
      day.year,
      day.month,
      day.day,
      hubDepart.hour,
      hubDepart.minute,
    );
    final hubFrom = PercorsoEndpoint(
      label: transitStopNameForDisplay(rnHubPin.stopName),
      point: rnHubPin.point,
      stopId: rnHubPin.stopId,
    );

    final tailCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: tailCandidates,
      from: hubFrom,
      to: to,
      departAt: hubDepartAt,
      day: day,
      profile: profile,
      stopsA: [
        _StopCandidate(
          pin: rnHubPin,
          stopIds: [rnHubPin.stopId],
          accessWalk: (meters: 0, duration: Duration.zero),
        ),
      ],
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (tailCandidates.isEmpty) return null;
    tailCandidates.sort((a, b) => a.score.compareTo(b.score));
    final tail = tailCandidates.first.itinerary;
    if (!tail.legs.any((l) => l.routeKey == 'RN|4' || l.routeKey == 'RA|4')) {
      return null;
    }

    final mergedLegs = <PercorsoLeg>[...headIt.legs];
    var cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : departAt;
    if (hubWalk.meters > 1) {
      final hubWalkEnd = cursor?.add(hubWalk.duration) ?? hubDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(hubWalk.meters),
        start: cursor,
        end: hubWalkEnd,
        from: alightPin.point,
        to: rnHubPin.point,
      ));
      cursor = hubWalkEnd;
    }
    for (final l in tail.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.subtitle?.contains('Verso destinazione') == true) {
        continue;
      }
      mergedLegs.add(
        l.copyWith(
          start: l.start != null && cursor != null
              ? (l.start!.isBefore(cursor) ? cursor : l.start)
              : l.start,
        ),
      );
    }

    _optimizeTransferAlightsOnLegs(mergedLegs, day);
    _optimizeFinalEgressAlightOnLegs(mergedLegs, to, day);

    var walkMeters = 0.0;
    for (final l in mergedLegs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    var transfers = 0;
    var sawRide = false;
    for (final l in mergedLegs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (sawRide) transfers++;
        sawRide = true;
      }
    }

    final merged = PercorsoItinerary(
      legs: mergedLegs,
      totalDuration: (mergedLegs.last.end ?? hubDepartAt).difference(departAt),
      walkMeters: walkMeters,
      transfers: transfers,
      profile: profile,
      hasPrenotazione: headIt.hasPrenotazione || tail.hasPrenotazione,
    );

    if (_isNonsensicalItinerary(
      merged,
      day,
      odDirectMeters: walkDirectMeters,
    )) {
      return null;
    }
    return merged;
  }

  /// Cesenatico/San Mauro → Rimini: 94 fino a S.Mauro Mare (pochi orari) o 2CO/1CO, poi RN|4.
  PercorsoPlanResult? _augmentCesenaticoRimini({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
    Stopwatch? budget,
  }) {
    if (!_preferViaStopIds(to).contains('W00001')) return null;
    final coastal = transitStopsWithinMeters(
      from.point,
      _allPins,
      10000,
      maxResults: 6,
    ).any((p) {
      final c = (p.comune ?? '').toLowerCase();
      return c.contains('cesenatico') ||
          c.contains('san mauro') ||
          c.contains('riccione') ||
          c.contains('cattolica');
    });
    if (!coastal) return null;

    final sag = stopById['30412'];
    final smMare = stopById['11830'];
    final rnHub = stopById['W00001'];
    if (rnHub == null) return null;

    final itineraries = <PercorsoItinerary>[];
    if (smMare != null) {
      final via94 = _buildCesenaticoRiminiHubItinerary(
        from: from,
        to: to,
        headHubPin: smMare,
        headHubStopId: '11830',
        preferHeadRoutes: const {'FC|S094'},
        rnHubPin: rnHub,
        departAt: departAt,
        day: day,
        profile: profile,
        walkDirectMeters: walkDirectMeters,
      );
      if (via94 != null) itineraries.add(via94);
    }
    if (sag != null) {
      final viaCo = _buildCesenaticoRiminiHubItinerary(
        from: from,
        to: to,
        headHubPin: sag,
        headHubStopId: '30412',
        preferHeadRoutes: const {'FC|2CO', 'FC|1CO'},
        rnHubPin: rnHub,
        departAt: departAt,
        day: day,
        profile: profile,
        walkDirectMeters: walkDirectMeters,
      );
      if (viaCo != null) itineraries.add(viaCo);
    }
    if (itineraries.isEmpty) return null;

    itineraries.sort((a, b) => a.totalDuration.compareTo(b.totalDuration));
    return PercorsoPlanResult(
      itineraries: itineraries,
      quality: PercorsoPlanQuality.strict,
    );
  }

  /// Cesenatico → Appennino: 94 fino a Cesena A2, 92 da B2, poi 132 (evita 93+133).
  PercorsoPlanResult? _augmentCesenaSantaSofiaCorridor({
    required PercorsoPlanResult partial,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required double walkDirectMeters,
    Stopwatch? budget,
  }) {
    final preferVia = _preferViaStopIds(to);
    if (!preferVia.contains('999B2')) {
      return null;
    }
    if (partial.itineraries.isEmpty) return null;
    final partialIt = partial.itineraries.first;
    if (partialIt.legs.any((l) => l.routeKey == 'FC|S132')) return null;

    final a2 = stopById['999A2'];
    final b2 = stopById['999B2'];
    if (a2 == null || b2 == null) return null;


    final a2Endpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(a2.stopName),
      point: a2.point,
      stopId: '999A2',
    );

    final headCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: headCandidates,
      from: from,
      to: a2Endpoint,
      departAt: departAt,
      day: day,
      profile: profile,
      stopsA: _stopCandidates(from, expanded: true),
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (headCandidates.isEmpty) return null;
    headCandidates.sort((a, b) => a.score.compareTo(b.score));

    PercorsoItinerary? headIt;
    for (final c in headCandidates) {
      if (c.itinerary.legs.any((l) => l.routeKey == 'FC|S094')) {
        headIt = c.itinerary;
        break;
      }
    }
    if (headIt == null) return null;
    final headRides =
        headIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (headRides.isEmpty) return null;

    final lastHead = headRides.last;
    final alightHead =
        stopById[lastHead.alightStopId ?? '999A2'] ?? a2;
    final hubWalk = percorsoWalkEstimate(alightHead.point, b2.point);
    if (hubWalk.meters > _hubTransferWalkMeters(alightHead)) return null;

    var hubDepart = lastHead.end ?? departAt;
    hubDepart = hubDepart.add(hubWalk.duration).add(
      Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
    );
    final hubDepartAt = DateTime(
      day.year,
      day.month,
      day.day,
      hubDepart.hour,
      hubDepart.minute,
    );

    final hubFrom = PercorsoEndpoint(
      label: transitStopNameForDisplay(b2.stopName),
      point: b2.point,
      stopId: '999B2',
    );

    final forliHub = stopById['1660'];
    if (forliHub == null) return null;
    final forliEndpoint = PercorsoEndpoint(
      label: transitStopNameForDisplay(forliHub.stopName),
      point: forliHub.point,
      stopId: '1660',
    );
    final b2Stops = resolveStopClusterIds(b2.stopId).toList()..sort();

    final midCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: midCandidates,
      from: hubFrom,
      to: forliEndpoint,
      departAt: hubDepartAt,
      day: day,
      profile: profile,
      stopsA: [
        _StopCandidate(
          pin: b2,
          stopIds: b2Stops,
          accessWalk: (meters: 0, duration: Duration.zero),
        ),
      ],
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (midCandidates.isEmpty) return null;
    midCandidates.sort((a, b) => a.score.compareTo(b.score));

    const forli92AlightIds = {'1660', '3120D', '151', '491', '1891'};

    PercorsoItinerary? midIt;
    for (final c in midCandidates) {
      final rides =
          c.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride);
      final last = rides.lastOrNull;
      if (last?.routeKey == 'FC|S092' &&
          last?.alightStopId != null &&
          forli92AlightIds.contains(last!.alightStopId!)) {
        midIt = c.itinerary;
        break;
      }
    }
    if (midIt == null) {
      for (final c in midCandidates) {
        if (c.itinerary.legs.any((l) => l.routeKey == 'FC|S092')) {
          midIt = c.itinerary;
          break;
        }
      }
    }
    if (midIt == null) return null;

    final midRides =
        midIt.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    if (midRides.isEmpty) return null;
    final lastMid = midRides.last;
    final midAlightPin =
        stopById[lastMid.alightStopId ?? '3120D'] ?? forliHub;
    final midToPuntoBus = percorsoWalkEstimate(
      midAlightPin.point,
      forliHub.point,
    );
    if (lastMid.alightStopId != '1660' &&
        midToPuntoBus.meters > PercorsoConstants.maxHubTransferWalkMeters) {
      return null;
    }

    var forliDepart = lastMid.end ?? hubDepartAt;
    forliDepart = forliDepart
        .add(
          lastMid.alightStopId == '1660'
              ? Duration.zero
              : midToPuntoBus.duration,
        )
        .add(
      Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
    );
    final forliDepartAt = DateTime(
      day.year,
      day.month,
      day.day,
      forliDepart.hour,
      forliDepart.minute,
    );
    final forliFrom = PercorsoEndpoint(
      label: transitStopNameForDisplay(forliHub.stopName),
      point: forliHub.point,
      stopId: '1660',
    );

    final tailCandidates = <_ScoredItinerary>[];
    _searchRaptor(
      candidates: tailCandidates,
      from: forliFrom,
      to: to,
      departAt: forliDepartAt,
      day: day,
      profile: profile,
      stopsA: [
        _StopCandidate(
          pin: forliHub,
          stopIds: const ['1660'],
          accessWalk: (meters: 0, duration: Duration.zero),
        ),
      ],
      longDistance:
          walkDirectMeters >= PercorsoConstants.trainHintThresholdMeters,
    );
    if (tailCandidates.isEmpty) return null;
    tailCandidates.sort((a, b) {
      final ra =
          a.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride).length;
      final rb =
          b.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride).length;
      if (ra != rb) return ra.compareTo(rb);
      return a.score.compareTo(b.score);
    });

    PercorsoItinerary? tailIt;
    for (final c in tailCandidates) {
      final rides =
          c.itinerary.legs.where((l) => l.kind == PercorsoLegKind.ride);
      if (!rides.any((l) => l.routeKey == 'FC|F132')) continue;
      if (rides.any(
        (l) => l.routeKey == 'FC|S096' || l.routeKey == 'FC|SA96',
      )) {
        continue;
      }
      tailIt = c.itinerary;
      break;
    }
    if (tailIt == null) {
      for (final c in tailCandidates) {
        if (c.itinerary.legs.any((l) => l.routeKey == 'FC|F132')) {
          tailIt = c.itinerary;
          break;
        }
      }
    }
    if (tailIt == null) return null;

    final mergedLegs = <PercorsoLeg>[...headIt.legs];
    var cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : departAt;
    if (hubWalk.meters > 1) {
      final hubWalkEnd = cursor?.add(hubWalk.duration) ?? hubDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(hubWalk.meters),
        start: cursor,
        end: hubWalkEnd,
        from: alightHead.point,
        to: b2.point,
      ));
      cursor = hubWalkEnd;
    }
    for (final l in midIt.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.subtitle?.contains('Verso destinazione') == true) {
        continue;
      }
      mergedLegs.add(
        l.copyWith(
          start: l.start != null && cursor != null
              ? (l.start!.isBefore(cursor) ? cursor : l.start)
              : l.start,
        ),
      );
    }
    cursor = mergedLegs.isNotEmpty ? mergedLegs.last.end : cursor;
    if (lastMid.alightStopId != '1660' && midToPuntoBus.meters > 1) {
      final wEnd = cursor?.add(midToPuntoBus.duration) ?? forliDepartAt;
      mergedLegs.add(PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: 'Cambio · a piedi',
        subtitle: percorsoFormatWalkDistance(midToPuntoBus.meters),
        start: cursor,
        end: wEnd,
        from: midAlightPin.point,
        to: forliHub.point,
      ));
      cursor = wEnd;
    }
    for (final l in tailIt.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.subtitle?.contains('Verso destinazione') == true) {
        continue;
      }
      mergedLegs.add(
        l.copyWith(
          start: l.start != null && cursor != null
              ? (l.start!.isBefore(cursor) ? cursor : l.start)
              : l.start,
        ),
      );
    }

    _optimizeTransferAlightsOnLegs(mergedLegs, day);
    _optimizeFinalEgressAlightOnLegs(mergedLegs, to, day);
    _collapseRedundantTransferWalks(mergedLegs);

    var walkMeters = 0.0;
    for (final l in mergedLegs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    var transfers = 0;
    var sawRide = false;
    for (final l in mergedLegs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (sawRide) transfers++;
        sawRide = true;
      }
    }

    final merged = PercorsoItinerary(
      legs: mergedLegs,
      totalDuration: (mergedLegs.last.end ?? forliDepartAt).difference(departAt),
      walkMeters: walkMeters,
      transfers: transfers,
      profile: profile,
      hasPrenotazione:
          headIt.hasPrenotazione ||
          midIt.hasPrenotazione ||
          tailIt.hasPrenotazione,
    );

    final worseSuboptimal = partialIt.legs.any(
      (l) => l.routeKey == 'FC|S093' || l.routeKey == 'FC|F133',
    );
    if (!worseSuboptimal &&
        merged.totalDuration >= partialIt.totalDuration) {
      return null;
    }

    return PercorsoPlanResult(
      itineraries: [merged],
      quality: partial.quality,
      suggestedDayOffset: partial.suggestedDayOffset,
      suggestTrain: partial.suggestTrain,
      userHint: partial.userHint,
    );
  }

  double _corridorRouteScoreAdj(PercorsoItinerary it) {
    final routes = it.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.routeKey)
        .whereType<String>()
        .toSet();
    var adj = 0.0;
    if (routes.contains('FC|F133') && routes.contains('FC|S093')) adj += 400;
    if (routes.contains('FC|S092')) adj -= 80;
    if (routes.contains('FC|F133')) adj += 80;
    return adj;
  }

  PercorsoPlanResult _searchPhase({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required ({double meters, Duration duration}) walkDirect,
    required PercorsoPlanQuality quality,
    required int dayOffset,
    required bool expandedStops,
    bool longDistance = false,
    Stopwatch? budget,
  }) {
    final candidates = <_ScoredItinerary>[];

    if (walkDirect.meters <= PercorsoConstants.maxDirectWalkMeters) {
      _addCandidate(
        candidates,
        _ScoredItinerary(
          _buildWalkOnly(from, to, departAt, walkDirect),
          _score(
            walkMeters: walkDirect.meters,
            total: walkDirect.duration,
            transfers: 0,
            hasPrenotazione: false,
            profile: profile,
          ),
        ),
      );
    }

    _runTransitSearch(
      candidates: candidates,
      from: from,
      to: to,
      departAt: departAt,
      day: day,
      profile: profile,
      expandedStops: expandedStops,
      longDistance: longDistance,
      budget: budget,
    );

    final itineraries = _finalize(
      candidates,
      profile,
      walkDirect,
      to: to,
      quality: quality,
      dayOffset: dayOffset,
      departAt: departAt,
      day: day,
    );

    final suggestTrain = itineraries.any(
      (it) => it.transfers >= PercorsoConstants.suggestTrainWhenTransfersAtLeast,
    );

    return PercorsoPlanResult(
      itineraries: itineraries,
      quality: quality,
      suggestedDayOffset: dayOffset,
      suggestTrain: suggestTrain,
      userHint: _hintForQuality(
        quality,
        dayOffset: dayOffset,
        day: day,
        hasTransit: itineraries.any(_hasTransit),
        suggestTrain: suggestTrain,
      ),
    );
  }

  PercorsoPlanResult _longHaulTrainResult({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required PercorsoProfile profile,
    required ({double meters, Duration duration}) walkDirect,
  }) {
    final it = _buildWalkOnly(from, to, departAt, walkDirect);
    return PercorsoPlanResult(
      itineraries: [it],
      quality: PercorsoPlanQuality.walkOnlyFallback,
      suggestTrain: true,
      userHint:
          'Distanza elevata: il bus non è una scelta pratica su questa tratta. '
          'Valuta il treno (non ancora disponibile in app). '
          'Sotto, tempo a piedi solo indicativo '
          '(${percorsoFormatWalkDistance(walkDirect.meters)}).',
    );
  }

  PercorsoPlanResult _withTrainHint(PercorsoPlanResult result) {
    return PercorsoPlanResult(
      itineraries: result.itineraries,
      quality: result.quality,
      suggestedDayOffset: result.suggestedDayOffset,
      suggestTrain: false,
      userHint: 'Per distanze elevate, valuta anche il treno '
          '(non ancora disponibile in app).',
    );
  }

  PercorsoPlanResult _walkFallback({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required PercorsoProfile profile,
    required ({double meters, Duration duration}) walkDirect,
    bool suggestTrain = false,
  }) {
    final it = PercorsoItinerary(
      legs: [
        PercorsoLeg(
          kind: PercorsoLegKind.walk,
          title: 'A piedi',
          subtitle:
              '${percorsoFormatWalkDistance(walkDirect.meters)} \u00b7 ${from.label} \u2192 ${to.label}',
          start: departAt,
          end: departAt.add(walkDirect.duration),
          from: from.point,
          to: to.point,
        ),
      ],
      totalDuration: walkDirect.duration,
      walkMeters: walkDirect.meters,
      transfers: 0,
      profile: profile,
      planQuality: PercorsoPlanQuality.walkOnlyFallback,
    );
    final String hint;
    if (suggestTrain) {
      hint = 'Nessun servizio TPL in calendario per la data scelta. '
          'Valuta il treno (non ancora disponibile in app). '
          'Percorso a piedi solo indicativo '
          '(${percorsoFormatWalkDistance(walkDirect.meters)}).';
    } else if (walkDirect.meters > PercorsoConstants.maxDirectWalkMeters) {
      hint = 'Nessun servizio TPL in calendario per la data scelta. '
          'Percorso a piedi indicativo '
          '(${percorsoFormatWalkDistance(walkDirect.meters)}).';
    } else {
      hint = 'Nessun servizio TPL in calendario per la data scelta. '
          'Percorso a piedi suggerito.';
    }
    return PercorsoPlanResult(
      itineraries: [it],
      quality: PercorsoPlanQuality.walkOnlyFallback,
      suggestTrain: suggestTrain,
      userHint: hint,
    );
  }

  String? _hintForQuality(
    PercorsoPlanQuality quality, {
    required int dayOffset,
    required DateTime day,
    required bool hasTransit,
    bool suggestTrain = false,
  }) {
    if (suggestTrain) {
      return 'Percorso con molti cambi o distanza elevata: valuta il treno '
          '(non ancora disponibile in app).';
    }
    if (!hasTransit) return null;
    return switch (quality) {
      PercorsoPlanQuality.strict => null,
      PercorsoPlanQuality.laterToday =>
        'Proposta basata su fermate più distanti o corse successive '
        'rispetto all’orario richiesto.',
      PercorsoPlanQuality.otherDay => _otherDayHint(dayOffset, day),
      PercorsoPlanQuality.walkOnlyFallback => null,
    };
  }

  String _otherDayHint(int dayOffset, DateTime day) {
    const names = [
      'lunedì',
      'martedì',
      'mercoledì',
      'giovedì',
      'venerdì',
      'sabato',
      'domenica',
    ];
    final label = names[day.weekday - 1];
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    if (dayOffset.abs() == 1) {
      return dayOffset > 0
          ? 'Prossimo servizio disponibile: domani ($d/$m, $label).'
          : 'Ultimo servizio disponibile: ieri ($d/$m, $label).';
    }
    return 'Servizio disponibile il $d/$m ($label).';
  }

  bool _overBudget(Stopwatch? budget) =>
      budget != null &&
      budget.elapsedMilliseconds >= PercorsoConstants.searchBudgetMs;

  void _runTransitSearch({
    required List<_ScoredItinerary> candidates,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required bool expandedStops,
    bool longDistance = false,
    Stopwatch? budget,
  }) {
    final stopsA = _stopCandidates(from, expanded: expandedStops);
    if (stopsA.isEmpty) return;

    _searchRaptor(
      candidates: candidates,
      from: from,
      to: to,
      departAt: departAt,
      day: day,
      profile: profile,
      stopsA: stopsA,
      longDistance: longDistance,
      budget: budget,
    );
  }

  // ---------------------------------------------------------------------------
  // RAPTOR round-based transit search
  // ---------------------------------------------------------------------------

  void _searchRaptor({
    required List<_ScoredItinerary> candidates,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required List<_StopCandidate> stopsA,
    bool longDistance = false,
    Stopwatch? budget,
  }) {
    final maxRounds = longDistance
        ? PercorsoConstants.ldMaxRaptorRounds
        : PercorsoConstants.maxRaptorRounds;
    final maxTrips = longDistance
        ? PercorsoConstants.ldMaxTripsPerMarkedStop
        : PercorsoConstants.maxTripsPerMarkedStop;
    final maxMarked = longDistance
        ? PercorsoConstants.ldMaxMarkedStopsPerRound
        : PercorsoConstants.maxMarkedStopsPerRound;

    final depSecFromMidnight =
        PercorsoServiceDay.departureSecondsSinceServiceMidnight(departAt);
    final preferViaStops = _preferViaStopIds(to);
    // Fermata richiesta (+ paline gemelle): essendo terminali, devono mantenere
    // la journey "corsa" se servite da un bus, senza farsi sovrascrivere da un
    // transfer a piedi (che genererebbe discese sbagliate / cammino assurdo).
    final destTargetIds = _destinationTargetStopIds(to);

    // RAPTOR multi-label (Punto A). `tau[k][stop]` = miglior arrivo a `stop`
    // usando AL PIÙ k corse (carry-forward: tau[k] parte da tau[k-1]). Tenere
    // le etichette separate per round impedisce a una soluzione diretta di
    // sopprimere un'alternativa valida con un cambio in più (e viceversa).
    // `best` è il minimo globale, usato SOLO per il local-pruning di Pareto:
    // scarta etichette dominate (arrivo non migliore con più o uguali corse).
    final tau = List.generate(maxRounds + 1, (_) => <String, int>{});
    final best = <String, int>{};
    final journeys = <String, List<_RaptorJourney?>>{}; // stopId -> per-round
    var marked = <String>{};

    void _initJourney(String sid) {
      journeys.putIfAbsent(sid, () => List.filled(maxRounds + 1, null));
    }

    // Round 0: walk from origin to nearby stops.
    for (final cand in stopsA) {
      for (final sid in cand.stopIds) {
        final walkSec = _accessWalkSec(from, sid);
        if (walkSec == null) continue;
        final arrSec = depSecFromMidnight + walkSec;
        if (arrSec < (tau[0][sid] ?? 0x7FFFFFFF)) {
          tau[0][sid] = arrSec;
          best[sid] = arrSec;
          marked.add(sid);
          _initJourney(sid);
          journeys[sid]![0] = _RaptorJourney.access(sid, arrSec);
        }
      }
    }

    _seedPreferViaHubRides(
      from: from,
      stopsA: stopsA,
      day: day,
      preferViaStops: preferViaStops,
      depSecFromMidnight: depSecFromMidnight,
      tau: tau,
      best: best,
      journeys: journeys,
      marked: marked,
      maxRounds: maxRounds,
      initJourney: _initJourney,
    );

    // Rounds 1..maxRounds: ride + transfer-walk.
    for (var round = 1; round <= maxRounds; round++) {
      if (marked.isEmpty || _overBudget(budget)) break;

      // Carry-forward: il round eredita le etichette del precedente. Le corse
      // di questo round leggono SEMPRE `tau[round-1]` (frozen) come orario di
      // disponibilità alla fermata: così il conteggio dei cambi resta corretto
      // e una fermata migliorata in questo stesso round non falsa il boarding.
      tau[round].addAll(tau[round - 1]);

      final newlyImproved = <String>{};
      final roundMarked = marked.toList();
      if (roundMarked.length > maxMarked) {
        roundMarked.sort(
            (a, b) => (tau[round - 1][a] ?? 0).compareTo(tau[round - 1][b] ?? 0));
        roundMarked.removeRange(maxMarked, roundMarked.length);
      }

      final seenTrips = <String>{};

      for (final sid in roundMarked) {
        if (_overBudget(budget)) break;
        final depSec = tau[round - 1][sid];
        if (depSec == null) continue;

        var tripsChecked = 0;

        for (final tid in _sortedTripIdsAtStop(
          sid,
          day,
          minDepSec: depSec,
          preferViaStops: preferViaStops,
        )) {
          if (tripsChecked >= maxTrips) break;
          if (seenTrips.contains(tid)) continue;
          final trip = planner.trips[tid];
          if (trip == null || !_tripRunsOn(trip, day)) continue;
          // Boarding occorrenza-aware (Punto C): su una linea ad anello la
          // fermata `sid` compare più volte; scegli il primo passaggio
          // effettivamente salibile (depSec >= disponibilità), non il primo
          // in lista. Altrimenti il boardSec sarebbe troppo presto e le
          // fermate del ramo verrebbero rilassate con un orario impossibile.
          TripStopPoint? boardStop;
          for (final occ in trip.stopOccurrences(sid)) {
            if (occ.depSec < depSec) continue;
            if (boardStop == null || occ.depSec < boardStop.depSec) {
              boardStop = occ;
            }
          }
          if (boardStop == null) continue;
          seenTrips.add(tid);
          tripsChecked++;

          for (final s in trip.stops) {
            if (s.sequence <= boardStop.sequence) continue;
            if (!gtfsTripTimesAreOrdered(boardStop.depSec, s.depSec)) continue;
            final arrSec = s.depSec;
            // Local pruning di Pareto: registra solo se batte il minimo globale.
            // Un'etichetta con arrivo >= best è dominata (stesso o peggior
            // arrivo con >= corse) → niente alternativa inutile.
            if (transitGraph.improvesStopAreaArrival(best, s.stopId, arrSec) &&
                arrSec < (best[s.stopId] ?? 0x7FFFFFFF)) {
              tau[round][s.stopId] = arrSec;
              best[s.stopId] = arrSec;
              _initJourney(s.stopId);
              journeys[s.stopId]![round] = _RaptorJourney.ride(
                boardStopId: sid,
                alightStopId: s.stopId,
                tripId: tid,
                routeKey: trip.routeKey,
                boardSec: boardStop.depSec,
                alightSec: arrSec,
                boardSeq: boardStop.sequence,
                alightSeq: s.sequence,
              );
              newlyImproved.add(s.stopId);
            }
          }
        }
      }

      // Transfer walk: archi precomputati in [transitGraph] (cammino × min
      // transfer GTFS × boarding penalty). Resta nello stesso round RAPTOR.
      final transferTargets = <String, int>{};
      for (final sid in newlyImproved) {
        if (_overBudget(budget)) break;
        final arr = tau[round][sid]!;
        final base = stopById[sid];
        if (base == null) continue;
        final maxWalkM = _hubTransferWalkMeters(base);
        for (final edge in transitGraph.footTransfersFrom(sid)) {
          final toId = edge.toStopId;
          if (toId == sid) continue;
          final walkM = edge.walkSeconds * PercorsoConstants.walkSpeedMps;
          if (walkM > maxWalkM) continue;

          final nArr =
              arr +
              transitGraph.footTransferDeltaSeconds(
                edge,
                followsTransitRide: true,
              );
          if (edge.sameStopArea &&
              nArr > transitGraph.stopAreaBestArrival(best, toId)) {
            continue;
          }
          // Fermata di destinazione richiesta: se è già servita da una corsa in
          // questo round, NON lasciare che un transfer a piedi la sovrascriva né
          // ne abbassi l'arrivo. Essendo terminale non viene usata come boarding
          // a valle, quindi non crea inconsistenze con `tau`.
          if (destTargetIds.contains(toId)) {
            final existing = journeys[toId]?[round];
            if (existing != null && existing.kind == _RJKind.ride) continue;
          }
          if (!transitGraph.improvesStopAreaArrival(best, toId, nArr)) continue;
          if (nArr < (best[toId] ?? 0x7FFFFFFF)) {
            tau[round][toId] = nArr;
            best[toId] = nArr;
            _initJourney(toId);
            journeys[toId]![round] = _RaptorJourney.transfer(
              fromStopId: sid,
              toStopId: toId,
              arrSec: nArr,
            );
            transferTargets[toId] = nArr;
          }
        }
      }

      marked = {...newlyImproved, ...transferTargets.keys};
    }

    // Extract itineraries reaching destination.
    _extractRaptorResults(
      candidates: candidates,
      from: from,
      to: to,
      departAt: departAt,
      day: day,
      profile: profile,
      reached: best,
      journeys: journeys,
      maxRounds: maxRounds,
    );
  }

  int? _accessWalkSec(PercorsoEndpoint ep, String stopId) {
    final pin = stopById[stopId];
    if (pin == null) return null;
    final w = percorsoWalkEstimate(ep.point, pin.point);
    if (!ep.isStop &&
        !_endpointCoversStop(ep, stopId) &&
        w.meters > PercorsoConstants.maxAccessWalkMeters) {
      return null;
    }
    return w.duration.inSeconds;
  }

  void _extractRaptorResults({
    required List<_ScoredItinerary> candidates,
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required PercorsoProfile profile,
    required Map<String, int> reached,
    required Map<String, List<_RaptorJourney?>> journeys,
    required int maxRounds,
  }) {
    final maxEgress = to.isStop
        ? PercorsoConstants.maxEgressWalkMeters
        : PercorsoConstants.maxAccessWalkMeters;

    final destStops = <String, double>{};
    for (final entry in reached.entries) {
      final pin = stopById[entry.key];
      if (pin == null) continue;
      final egress = percorsoWalkEstimate(pin.point, to.point).meters;
      if (egress <= maxEgress) {
        destStops[entry.key] = egress;
      }
    }

    // Destinazione = fermata richiesta: garantisci che la fermata target (o una
    // palina gemella), se raggiunta da una CORSA che vi termina, sia sempre tra
    // gli arrivi candidati (egress 0), anche se per ipotesi fuori dal raggio.
    final targetIds = _destinationTargetStopIds(to);
    for (final id in targetIds) {
      if (destStops.containsKey(id)) continue;
      if (!reached.containsKey(id)) continue;
      final jList = journeys[id];
      if (jList == null) continue;
      if (!jList.any((j) => j != null && j.kind == _RJKind.ride)) continue;
      final pin = stopById[id];
      if (pin == null) continue;
      destStops[id] = percorsoWalkEstimate(pin.point, to.point).meters;
    }
    // Extract one itinerary per round per destination stop to get alternatives
    // with different transfer counts (round 1 = direct, round 2 = 1-transfer, etc.).
    for (final ds in destStops.entries) {
      final jList = journeys[ds.key];
      if (jList == null) continue;
      for (var round = 1; round <= maxRounds; round++) {
        if (jList[round] == null) continue;
        final chain = _traceJourneyChain(ds.key, journeys, round);
        if (chain.isEmpty) continue;
        if (!chain.any((j) => j.kind == _RJKind.ride)) continue;

        final it = _buildRaptorItinerary(
          from: from,
          to: to,
          departAt: departAt,
          day: day,
          chain: chain,
          egressMeters: ds.value,
        );
        if (it == null) continue;

        final sc = _score(
          walkMeters: it.walkMeters,
          total: it.totalDuration,
          transfers: it.transfers,
          hasPrenotazione: it.hasPrenotazione,
          profile: profile,
        ) +
            _longWaitScorePenalty(it) +
            _corridorRouteScoreAdj(it) +
            _interRideTransferWalkPenalty(it);
        _addCandidate(candidates, _ScoredItinerary(it, sc));
      }
    }
  }

  List<_RaptorJourney> _traceJourneyChain(
    String destStopId,
    Map<String, List<_RaptorJourney?>> journeys,
    int targetRound,
  ) {
    final chain = <_RaptorJourney>[];
    String? curStop = destStopId;
    var r = targetRound;
    while (r >= 0 && curStop != null) {
      final j = journeys[curStop]?[r];
      if (j == null) break;
      chain.add(j);
      curStop = j.prevStopId;
      // Transfers live in the same round as the ride that preceded them;
      // only decrement the round counter for rides and access entries.
      if (j.kind != _RJKind.transfer) r--;
    }
    return chain.reversed.toList();
  }

  PercorsoItinerary? _buildRaptorItinerary({
    required PercorsoEndpoint from,
    required PercorsoEndpoint to,
    required DateTime departAt,
    required DateTime day,
    required List<_RaptorJourney> chain,
    required double egressMeters,
  }) {
    if (chain.isEmpty) return null;
    final legs = <PercorsoLeg>[];
    var walkMeters = 0.0;
    var transfers = 0;
    var hasPren = false;
    var cursor = departAt;
    final base = DateTime(day.year, day.month, day.day);

    for (var i = 0; i < chain.length; i++) {
      final j = chain[i];

      if (j.kind == _RJKind.access) {
        final pin = stopById[j.alightStopId];
        if (pin == null) continue;
        final w = percorsoWalkEstimate(from.point, pin.point);
        walkMeters += w.meters;
        final accessEnd = departAt.add(w.duration);
        legs.add(PercorsoLeg(
          kind: PercorsoLegKind.walk,
          title: 'A piedi',
          subtitle:
              'Fermata ${transitStopNameForDisplay(pin.stopName)} · '
              '${percorsoFormatWalkDistance(w.meters)}',
          start: departAt,
          end: accessEnd,
          from: from.point,
          to: pin.point,
        ));
        cursor = accessEnd;
        continue;
      }

      if (j.kind == _RJKind.transfer) {
        final fromPin = stopById[j.boardStopId ?? j.prevStopId ?? ''];
        final toPin = stopById[j.alightStopId];
        if (fromPin != null && toPin != null) {
          final tw = percorsoWalkEstimate(fromPin.point, toPin.point);
          walkMeters += tw.meters;
          if (tw.meters > 1) {
            legs.add(PercorsoLeg(
              kind: PercorsoLegKind.walk,
              title: 'Cambio · a piedi',
              subtitle: percorsoFormatWalkDistance(tw.meters),
              start: cursor,
              end: cursor.add(tw.duration),
              from: fromPin.point,
              to: toPin.point,
            ));
            cursor = cursor.add(tw.duration);
          }
          final waitEnd = base.add(Duration(seconds: j.alightSec));
          if (waitEnd.isAfter(cursor)) {
            legs.add(PercorsoLeg(
              kind: PercorsoLegKind.wait,
              title: 'Attesa',
              subtitle:
                  'Minimo ${PercorsoConstants.minTransferWaitMinutes} min',
              start: cursor,
              end: waitEnd,
            ));
            cursor = waitEnd;
          }
        }
        continue;
      }

      // Ride leg.
      if (j.kind == _RJKind.ride) {
        if (i > 0 && chain[i - 1].kind == _RJKind.ride) {
          transfers++;
        }

        final boardPin = stopById[j.boardStopId ?? ''];
        final alightPin = stopById[j.alightStopId];
        if (boardPin == null || alightPin == null) continue;

        final boardAt = base.add(Duration(seconds: j.boardSec));
        final alightAt = base.add(Duration(seconds: j.alightSec));

        if (boardAt.isAfter(cursor)) {
          final waitDur = boardAt.difference(cursor);
          if (waitDur.inMinutes >= 2) {
            legs.add(PercorsoLeg(
              kind: PercorsoLegKind.wait,
              title: 'Attesa',
              subtitle: '${waitDur.inMinutes} min',
              start: cursor,
              end: boardAt,
            ));
          }
        }

        final line = _lineLabel(j.routeKey ?? '');
        final pren = _isPrenotazione(
            j.boardStopId ?? '', j.routeKey ?? '', j.tripId ?? '', day);
        if (pren) hasPren = true;

        legs.add(PercorsoLeg(
          kind: PercorsoLegKind.ride,
          title: line,
          subtitle:
              '${transitStopNameForDisplay(boardPin.stopName)} → '
              '${transitStopNameForDisplay(alightPin.stopName)}',
          start: boardAt,
          end: alightAt,
          from: boardPin.point,
          to: alightPin.point,
          routeKey: j.routeKey,
          tripId: j.tripId,
          boardStopId: j.boardStopId,
          alightStopId: j.alightStopId,
          boardSeq: j.boardSeq,
          alightSeq: j.alightSeq,
          lineLabel: line,
          isPrenotazione: pren,
        ));
        cursor = alightAt;
      }
    }

    // Egress walk only after the last bus leg (not after an intermediate ride).
    final lastRide = chain.lastWhere((j) => j.kind == _RJKind.ride);
    final lastRideIdx = chain.indexOf(lastRide);
    final moreTransitAfterLastRide = chain
        .sublist(lastRideIdx + 1)
        .any((j) => j.kind == _RJKind.transfer || j.kind == _RJKind.ride);
    if (!moreTransitAfterLastRide) {
      final lastAlightPin = stopById[lastRide.alightStopId];
      if (lastAlightPin != null) {
        final ew = percorsoWalkEstimate(lastAlightPin.point, to.point);
        walkMeters += ew.meters;
        legs.add(PercorsoLeg(
          kind: PercorsoLegKind.walk,
          title: 'A piedi',
          subtitle:
              'Verso destinazione · ${percorsoFormatWalkDistance(ew.meters)}',
          start: cursor,
          end: cursor.add(ew.duration),
          from: lastAlightPin.point,
          to: to.point,
        ));
        cursor = cursor.add(ew.duration);
      }
    }

    final totalDur = cursor.difference(departAt);
    if (totalDur.isNegative) return null;

    _optimizeTransferAlightsOnLegs(legs, day);
    _optimizeFinalEgressAlightOnLegs(legs, to, day);
    _collapseRedundantTransferWalks(legs);
    _mergeConsecutiveSameRouteRides(legs);

    for (final l in legs) {
      if (l.kind == PercorsoLegKind.ride && !_rideLegIsValidOnTrip(l)) {
        return null;
      }
    }

    walkMeters = 0;
    for (final l in legs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }

    final rides = legs.where((l) => l.kind == PercorsoLegKind.ride).length;
    transfers = (rides - 1).clamp(0, 99);

    final endAt = legs.last.end ?? cursor;
    final adjustedDur = endAt.difference(departAt);
    if (adjustedDur.isNegative) return null;

    return PercorsoItinerary(
      legs: legs,
      totalDuration: adjustedDur,
      walkMeters: walkMeters,
      transfers: transfers,
      profile: PercorsoProfile.fastest,
      hasPrenotazione: hasPren,
    );
  }

  void _addCandidate(List<_ScoredItinerary> list, _ScoredItinerary item) {
    if (list.length >= PercorsoConstants.maxPlannerCandidates) return;
    list.add(item);
  }

  /// Due tratte sulla stessa corsa GTFS (stesso [tripId]) → un’unica corsa.
  /// Non si fondono viaggi diversi sulla stessa linea: genererebbe segmenti
  /// impossibili (es. 1-2CO Leone → P.le Trento mescolando due varianti).
  void _mergeConsecutiveSameRouteRides(List<PercorsoLeg> legs) {
    for (var i = legs.length - 1; i >= 0; i--) {
      if (legs[i].kind != PercorsoLegKind.ride) continue;
      var j = i + 1;
      while (j < legs.length &&
          (legs[j].kind == PercorsoLegKind.wait ||
              legs[j].kind == PercorsoLegKind.walk)) {
        j++;
      }
      if (j >= legs.length || legs[j].kind != PercorsoLegKind.ride) continue;
      final a = legs[i];
      final b = legs[j];
      final rk = a.routeKey;
      if (rk == null || rk.isEmpty || rk != b.routeKey) continue;
      final tripA = a.tripId;
      final tripB = b.tripId;
      if (tripA == null || tripB == null || tripA != tripB) continue;

      final trip = planner.trips[tripA];
      if (trip == null) continue;

      final alightA = a.alightStopId;
      final boardB = b.boardStopId;
      if (alightA == null || boardB == null) continue;
      if (alightA != boardB) {
        final pinA = stopById[alightA];
        final pinB = stopById[boardB];
        if (pinA == null || pinB == null) continue;
        final w = percorsoWalkEstimate(pinA.point, pinB.point);
        if (w.meters > 120) continue;
      }

      final boardId = a.boardStopId ?? boardB;
      final alightId = b.alightStopId ?? alightA;
      if (!tripServesRideSegment(
        trip,
        boardStopId: boardId,
        alightStopId: alightId,
        boardSeq: a.boardSeq,
        alightSeq: b.alightSeq,
      )) {
        continue;
      }

      final boardPin = stopById[boardId];
      final alightPin = stopById[alightId];
      if (boardPin == null || alightPin == null) continue;
      legs[i] = PercorsoLeg(
        kind: PercorsoLegKind.ride,
        title: a.title,
        subtitle:
            '${transitStopNameForDisplay(boardPin.stopName)} → '
            '${transitStopNameForDisplay(alightPin.stopName)}',
        start: a.start,
        end: b.end,
        from: a.from,
        to: alightPin.point,
        routeKey: rk,
        tripId: tripA,
        boardStopId: boardId,
        alightStopId: alightId,
        boardSeq: a.boardSeq,
        alightSeq: b.alightSeq,
        lineLabel: a.lineLabel,
        isPrenotazione: a.isPrenotazione || b.isPrenotazione,
      );
      for (var k = j; k > i; k--) {
        legs.removeAt(k);
      }
    }
  }

  bool _rideLegIsValidOnTrip(PercorsoLeg leg) {
    if (leg.kind != PercorsoLegKind.ride) return true;
    final tid = leg.tripId;
    final board = leg.boardStopId;
    final alight = leg.alightStopId;
    if (tid == null || board == null || alight == null) return false;
    final trip = planner.trips[tid];
    if (trip == null) return false;
    return tripServesRideSegment(
      trip,
      boardStopId: board,
      alightStopId: alight,
      boardSeq: leg.boardSeq,
      alightSeq: leg.alightSeq,
    );
  }

  /// Ultima corsa: discesa che riduce il tragitto a piedi verso la destinazione.
  ///
  /// - Indirizzo generico: scende alla fermata della corsa più vicina al punto.
  /// - Fermata richiesta (`to.isStop`): se la corsa finale transita per la
  ///   fermata target (o una sua palina gemella), forza la discesa lì ed elimina
  ///   del tutto il tratto a piedi di egress.
  void _optimizeFinalEgressAlightOnLegs(
    List<PercorsoLeg> legs,
    PercorsoEndpoint to,
    DateTime day,
  ) {
    final lastRideIdx = legs.lastIndexWhere((l) => l.kind == PercorsoLegKind.ride);
    if (lastRideIdx < 0) return;

    for (var i = lastRideIdx + 1; i < legs.length; i++) {
      if (legs[i].kind == PercorsoLegKind.ride) return;
    }

    final ride = legs[lastRideIdx];
    final tripId = ride.tripId;
    final boardId = ride.boardStopId;
    final alightId = ride.alightStopId;
    if (tripId == null || boardId == null || alightId == null) return;

    final trip = planner.trips[tripId];
    if (trip == null) return;

    // Punto C: aggancia il passaggio reale via sequenza GTFS (linee ad anello),
    // con fallback al vecchio lookup per id se la sequenza non è disponibile.
    final boardOnTrip = (ride.boardSeq != null
            ? trip.stopBySequence(ride.boardSeq!)
            : null) ??
        trip.stopById(boardId);
    final currentAlight = (ride.alightSeq != null
            ? trip.stopBySequence(ride.alightSeq!)
            : null) ??
        trip.stopById(alightId);
    if (boardOnTrip == null || currentAlight == null) return;

    final destPoint = to.point;
    final currentPin = stopById[alightId]!;
    final initialWalk = percorsoWalkEstimate(currentPin.point, destPoint);
    var bestWalk = initialWalk;
    String? bestAlightId = alightId;
    int? bestAlightSec = currentAlight.depSec;
    int? bestAlightSeq = currentAlight.sequence;
    final base = DateTime(day.year, day.month, day.day);

    // Fermata richiesta dall'utente: priorità assoluta alla discesa esatta sul
    // target se la corsa lo serve a valle del punto di salita.
    final targetIds = _destinationTargetStopIds(to);
    if (targetIds.isNotEmpty) {
      if (targetIds.contains(alightId)) return;
      for (final s in trip.stops) {
        // Solo fermate a valle del passaggio di salita reale: su un anello
        // evita di "scendere" a una fermata toccata prima del boarding.
        if (s.sequence <= boardOnTrip.sequence) continue;
        if (!gtfsTripTimesAreOrdered(boardOnTrip.depSec, s.depSec)) continue;
        if (!targetIds.contains(s.stopId)) continue;
        final candPin = stopById[s.stopId];
        if (candPin == null) continue;
        bestWalk = percorsoWalkEstimate(candPin.point, destPoint);
        bestAlightId = s.stopId;
        bestAlightSec = s.depSec;
        bestAlightSeq = s.sequence;
        break;
      }
      if (bestAlightId == alightId || bestAlightSec == null) return;
    } else {
      for (final s in trip.stops) {
        if (s.sequence <= boardOnTrip.sequence) continue;
        if (!gtfsTripTimesAreOrdered(boardOnTrip.depSec, s.depSec)) continue;
        final candPin = stopById[s.stopId];
        if (candPin == null) continue;
        final w = percorsoWalkEstimate(candPin.point, destPoint);
        if (w.meters + 60 >= bestWalk.meters) continue;
        bestWalk = w;
        bestAlightId = s.stopId;
        bestAlightSec = s.depSec;
        bestAlightSeq = s.sequence;
      }

      if (bestAlightId == null ||
          bestAlightId == alightId ||
          bestAlightSec == null) {
        return;
      }
      if (initialWalk.meters - bestWalk.meters < 60) return;
    }

    final newAlightPin = stopById[bestAlightId]!;
    final boardPin = stopById[boardId]!;
    final bestAlightAt = base.add(Duration(seconds: bestAlightSec));

    legs[lastRideIdx] = PercorsoLeg(
      kind: PercorsoLegKind.ride,
      title: ride.title,
      subtitle:
          '${transitStopNameForDisplay(boardPin.stopName)} → '
          '${transitStopNameForDisplay(newAlightPin.stopName)}',
      start: ride.start,
      end: bestAlightAt,
      from: boardPin.point,
      to: newAlightPin.point,
      routeKey: ride.routeKey,
      tripId: ride.tripId,
      boardStopId: ride.boardStopId,
      alightStopId: bestAlightId,
      boardSeq: ride.boardSeq,
      alightSeq: bestAlightSeq,
      lineLabel: ride.lineLabel,
      isPrenotazione: ride.isPrenotazione,
    );

    while (legs.length > lastRideIdx + 1) {
      legs.removeLast();
    }

    // Discesa sulla fermata richiesta: nessun tratto a piedi residuo.
    if (bestWalk.meters < 25) return;

    final walkEnd = bestAlightAt.add(bestWalk.duration);
    legs.add(PercorsoLeg(
      kind: PercorsoLegKind.walk,
      title: 'A piedi',
      subtitle:
          'Verso destinazione · ${percorsoFormatWalkDistance(bestWalk.meters)}',
      start: bestAlightAt,
      end: walkEnd,
      from: newAlightPin.point,
      to: destPoint,
    ));
  }

  /// Tra due corse, tiene un solo tratto «Cambio · a piedi» (il più lungo).
  void _collapseRedundantTransferWalks(List<PercorsoLeg> legs) {
    for (var i = 0; i < legs.length; i++) {
      if (legs[i].kind != PercorsoLegKind.ride) continue;
      var nextRide = i + 1;
      while (nextRide < legs.length && legs[nextRide].kind != PercorsoLegKind.ride) {
        nextRide++;
      }
      if (nextRide >= legs.length) continue;

      final cambioIdx = <int>[];
      for (var j = i + 1; j < nextRide; j++) {
        final l = legs[j];
        if (l.kind == PercorsoLegKind.walk && l.title.contains('Cambio')) {
          cambioIdx.add(j);
        }
      }
      if (cambioIdx.length <= 1) continue;

      var keep = cambioIdx.first;
      var keepM = 0.0;
      for (final j in cambioIdx) {
        final l = legs[j];
        final m = (l.from != null && l.to != null)
            ? percorsoWalkEstimate(l.from!, l.to!).meters
            : 0.0;
        if (m >= keepM) {
          keepM = m;
          keep = j;
        }
      }
      for (var k = cambioIdx.length - 1; k >= 0; k--) {
        if (cambioIdx[k] != keep) legs.removeAt(cambioIdx[k]);
      }
    }
  }

  /// Sulla stessa corsa, scegli la discesa che minimizza il tragitto a piedi verso il cambio.
  void _optimizeTransferAlightsOnLegs(List<PercorsoLeg> legs, DateTime day) {
    final base = DateTime(day.year, day.month, day.day);

    for (var i = 0; i < legs.length; i++) {
      if (legs[i].kind != PercorsoLegKind.ride) continue;
      final ride = legs[i];
      final tripId = ride.tripId;
      final boardId = ride.boardStopId;
      final alightId = ride.alightStopId;
      if (tripId == null || boardId == null || alightId == null) continue;

      final trip = planner.trips[tripId];
      if (trip == null) continue;

      var nextRideIdx = i + 1;
      while (nextRideIdx < legs.length &&
          legs[nextRideIdx].kind != PercorsoLegKind.ride) {
        nextRideIdx++;
      }
      if (nextRideIdx >= legs.length) continue;

      var walkIdx = -1;
      for (var j = i + 1; j < nextRideIdx; j++) {
        if (legs[j].kind == PercorsoLegKind.wait) continue;
        if (legs[j].kind == PercorsoLegKind.walk &&
            legs[j].title.contains('Cambio')) {
          walkIdx = j;
        }
      }
      if (walkIdx < 0) continue;

      final nextRide = legs[nextRideIdx];
      final walkLeg = legs[walkIdx];
      final targetStopId = nextRide.boardStopId;
      final targetPin = targetStopId != null ? stopById[targetStopId] : null;
      final targetPoint =
          walkLeg.to ?? targetPin?.point ?? walkLeg.from;
      if (targetPoint == null) continue;

      // Punto C: passaggio reale via sequenza GTFS, fallback per id.
      final boardOnTrip = (ride.boardSeq != null
              ? trip.stopBySequence(ride.boardSeq!)
              : null) ??
          trip.stopById(boardId);
      final currentAlight = (ride.alightSeq != null
              ? trip.stopBySequence(ride.alightSeq!)
              : null) ??
          trip.stopById(alightId);
      if (boardOnTrip == null || currentAlight == null) continue;

      final currentPin = stopById[alightId]!;
      var bestWalk = percorsoWalkEstimate(currentPin.point, targetPoint);
      String? bestAlightId = alightId;
      int? bestAlightSec = currentAlight.depSec;
      int? bestAlightSeq = currentAlight.sequence;
      DateTime? bestAlightAt = ride.end;

      for (final s in trip.stops) {
        if (s.sequence <= boardOnTrip.sequence) continue;
        // Monotonia oraria reale dal passaggio di salita: niente discese su un
        // giro precedente dell'anello.
        if (!gtfsTripTimesAreOrdered(boardOnTrip.depSec, s.depSec)) continue;
        final candPin = stopById[s.stopId];
        if (candPin == null) continue;
        final w = percorsoWalkEstimate(candPin.point, targetPoint);
        if (w.meters + 25 >= bestWalk.meters) continue;

        final alightAt = base.add(Duration(seconds: s.depSec));
        final arriveTransfer = alightAt.add(w.duration).add(
          Duration(minutes: PercorsoConstants.minTransferWaitMinutes),
        );
        final isEarlierAlight = s.sequence < currentAlight.sequence;
        if (!isEarlierAlight &&
            nextRide.start != null &&
            arriveTransfer.isAfter(nextRide.start!)) {
          continue;
        }

        bestWalk = w;
        bestAlightId = s.stopId;
        bestAlightSec = s.depSec;
        bestAlightSeq = s.sequence;
        bestAlightAt = alightAt;
      }

      if (bestAlightId == null ||
          bestAlightId == alightId ||
          bestAlightSec == null ||
          bestAlightAt == null) {
        continue;
      }

      final newAlightPin = stopById[bestAlightId]!;
      final boardPin = stopById[boardId]!;
      legs[i] = PercorsoLeg(
        kind: PercorsoLegKind.ride,
        title: ride.title,
        subtitle:
            '${transitStopNameForDisplay(boardPin.stopName)} → '
            '${transitStopNameForDisplay(newAlightPin.stopName)}',
        start: ride.start,
        end: bestAlightAt,
        from: ride.from,
        to: newAlightPin.point,
        routeKey: ride.routeKey,
        tripId: ride.tripId,
        boardStopId: ride.boardStopId,
        alightStopId: bestAlightId,
        boardSeq: ride.boardSeq,
        alightSeq: bestAlightSeq,
        lineLabel: ride.lineLabel,
        isPrenotazione: ride.isPrenotazione,
      );

      final walkEnd = bestAlightAt.add(bestWalk.duration);
      legs[walkIdx] = PercorsoLeg(
        kind: PercorsoLegKind.walk,
        title: legs[walkIdx].title,
        subtitle: percorsoFormatWalkDistance(bestWalk.meters),
        start: bestAlightAt,
        end: walkEnd,
        from: newAlightPin.point,
        to: targetPoint,
      );

      if (nextRide.start != null && walkEnd.isAfter(nextRide.start!)) {
        var waitStart = walkEnd;
        var waitIdx = walkIdx + 1;
        if (waitIdx < nextRideIdx &&
            legs[waitIdx].kind == PercorsoLegKind.wait) {
          legs[waitIdx] = PercorsoLeg(
            kind: PercorsoLegKind.wait,
            title: legs[waitIdx].title,
            subtitle: legs[waitIdx].subtitle,
            start: waitStart,
            end: nextRide.start,
          );
        }
      }
    }
  }

  double _interRideTransferWalkPenalty(PercorsoItinerary it) {
    var pen = 0.0;
    final rides = it.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    for (var i = 0; i < rides.length - 1; i++) {
      final idx = it.legs.indexOf(rides[i]);
      final nextIdx = it.legs.indexOf(rides[i + 1]);
      if (idx < 0 || nextIdx < 0) continue;
      for (var j = idx + 1; j < nextIdx; j++) {
        final l = it.legs[j];
        if (l.kind != PercorsoLegKind.walk) continue;
        if (l.subtitle?.contains('Verso destinazione') == true) continue;
        if (l.from == null || l.to == null) continue;
        final m = percorsoWalkEstimate(l.from!, l.to!).meters;
        if (m > PercorsoConstants.maxHubTransferWalkMeters) {
          pen += (m - PercorsoConstants.maxHubTransferWalkMeters) * 0.35;
        } else if (m > PercorsoConstants.maxTransferWalkMeters) {
          pen += (m - PercorsoConstants.maxTransferWalkMeters) * 0.2;
        }
      }
    }
    return pen;
  }

  double _longWaitScorePenalty(PercorsoItinerary it) {
    var pen = 0.0;
    DateTime? lastRideEnd;
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (lastRideEnd != null && l.start != null) {
          final gap = l.start!.difference(lastRideEnd);
          if (gap.inMinutes > 50) {
            pen += (gap.inMinutes - 50) * 1.8;
          }
        }
        lastRideEnd = l.end;
      }
    }
    return pen;
  }

  void _seedPreferViaHubRides({
    required PercorsoEndpoint from,
    required List<_StopCandidate> stopsA,
    required DateTime day,
    required Set<String> preferViaStops,
    required int depSecFromMidnight,
    required List<Map<String, int>> tau,
    required Map<String, int> best,
    required Map<String, List<_RaptorJourney?>> journeys,
    required Set<String> marked,
    required int maxRounds,
    required void Function(String sid) initJourney,
  }) {
    if (preferViaStops.isEmpty) return;

    final boardStops = <String>{};
    for (final cand in stopsA) {
      boardStops.addAll(cand.stopIds);
    }
    for (final pin in transitStopsWithinMeters(
      from.point,
      _allPins,
      PercorsoConstants.maxAccessWalkMeters,
      maxResults: 40,
    )) {
      if (planner.routeKeysAtStop(pin.stopId).contains('FC|F126')) {
        boardStops.add(pin.stopId);
      }
    }

    for (final via in preferViaStops) {
      // Non impostare l'etichetta su hub di destinazione (es. 1660): creerebbe salti impossibili.
      if (via == '1660' || via == '17881') continue;
      for (final sid in boardStops) {
        var accessArr = tau[0][sid];
        if (accessArr == null) {
          final pin = stopById[sid];
          if (pin == null) continue;
          final w = percorsoWalkEstimate(from.point, pin.point);
          if (w.meters > PercorsoConstants.maxAccessWalkMeters) continue;
          accessArr = depSecFromMidnight + w.duration.inSeconds;
        }
        for (final tid in _sortedTripIdsAtStop(
            sid,
            day,
            minDepSec: accessArr,
            preferViaStops: preferViaStops,
          )) {
            final trip = planner.trips[tid];
            if (trip == null || !_tripRunsOn(trip, day)) continue;
            if (!preferViaStops.any((v) => _tripCoversStop(tid, v))) {
              continue;
            }
            // Occorrenza-aware anche nel seed: usa il passaggio salibile di `sid`
            // e la prima occorrenza di `via` a valle di quel passaggio.
            TripStopPoint? board;
            for (final occ in trip.stopOccurrences(sid)) {
              if (occ.depSec < accessArr) continue;
              if (board == null || occ.depSec < board.depSec) board = occ;
            }
            if (board == null) continue;
            final viaStop = trip.stopByIdAfter(via, afterSequence: board.sequence);
            if (viaStop == null || viaStop.depSec < accessArr) continue;
            final arrSec = viaStop.depSec;
            // Il seed semina solo la disponibilità a round 0 (boarding base per
            // i round successivi), coerente col comportamento precedente.
            if (arrSec < (tau[0][via] ?? 0x7FFFFFFF)) {
              tau[0][via] = arrSec;
              best[via] = arrSec;
              marked.add(via);
            }
          }
      }
    }
  }

  /// Fermate intermedie da privilegiare (es. Forlì Punto Bus verso Dovadola).
  Set<String> _preferViaStopIds(PercorsoEndpoint to) {
    final near = transitStopsWithinMeters(
      to.point,
      _allPins,
      4000,
      maxResults: 6,
    );
    for (final p in near) {
      final c = (p.comune ?? '').toLowerCase();
      if (c.contains('dovadola') || c.contains('forl')) {
        return {'1660', '17881'};
      }
      if (c.contains('rimini')) {
        return {'W00001'};
      }
      if (c.contains('santa sofia') ||
          c.contains('galeata') ||
          c.contains('tredozio') ||
          c.contains('premilcuore') ||
          c.contains('meldola')) {
        return {'1660', '999A2', '999B2'};
      }
    }
    return const {};
  }

  bool _tripCoversStop(String tripId, String stopId) =>
      planner.trips[tripId]?.stopById(stopId) != null;

  List<String> _sortedTripIdsAtStop(
    String stopId,
    DateTime day, {
    int? minDepSec,
    Set<String> preferViaStops = const {},
  }) {
    final scored = <MapEntry<String, int>>[];
    for (final tid in planner.tripIdsAtStop(stopId)) {
      final trip = planner.trips[tid];
      if (trip == null || !_tripRunsOn(trip, day)) continue;
      final stop = trip.stopById(stopId);
      if (stop == null) continue;
      if (minDepSec != null && stop.depSec < minDepSec) continue;
      scored.add(MapEntry(tid, stop.depSec));
    }
    scored.sort((a, b) {
      final byTime = a.value.compareTo(b.value);
      final ta = planner.trips[a.key];
      final tb = planner.trips[b.key];
      final ra = ta?.routeKey ?? '';
      final rb = tb?.routeKey ?? '';
      if (preferViaStops.isNotEmpty && ra == rb && ra.isNotEmpty) {
        final aVia = preferViaStops.any((s) => _tripCoversStop(a.key, s))
            ? 0
            : 1;
        final bVia = preferViaStops.any((s) => _tripCoversStop(b.key, s))
            ? 0
            : 1;
        if (aVia != bVia) return aVia.compareTo(bVia);
      }
      if (byTime != 0) return byTime;
      if (ra == rb && ra.isNotEmpty && ta != null && tb != null) {
        final byLen = tb.stops.length.compareTo(ta.stops.length);
        if (byLen != 0) return byLen;
      }
      return _routeBoardSortOrder(ra).compareTo(_routeBoardSortOrder(rb));
    });
    return scored.map((e) => e.key).toList(growable: false);
  }

  /// Ordine di preferenza in parità di orario (S092 prima di S093 sul corridoio Cesena–Forlì).
  static int _routeBoardSortOrder(String routeKey) {
    switch (routeKey) {
      case 'FC|S092':
        return 0;
      case 'FC|S093':
        return 4;
      case 'FC|F133':
        return 5;
      case 'FC|F127':
        return 0;
      case 'FC|F126':
        return 1;
      case 'FC|2CO':
      case 'FC|1CO':
        return 1;
      case 'RN|4':
        return 1;
      default:
        return 2;
    }
  }

  static double _hubTransferWalkMeters(TransitStopPin pin) {
    final c = (pin.comune ?? '').toLowerCase();
    if (c.contains('forl')) {
      return PercorsoConstants.maxForliHubTransferWalkMeters;
    }
    if (c.contains('cesenatico') || c.contains('san mauro')) {
      return PercorsoConstants.maxCesenaticoHubTransferWalkMeters;
    }
    if (c.contains('cesena') ||
        c.contains('rimini') ||
        c.contains('ravenna') ||
        c.contains('faenza') ||
        c.contains('imola') ||
        c.contains('savignano')) {
      return PercorsoConstants.maxHubTransferWalkMeters;
    }
    return PercorsoConstants.maxTransferWalkMeters;
  }

  bool _stopIsDownstreamOnRoute({
    required String fromStopId,
    required String toStopId,
    required String routeKey,
    String? preferTripId,
  }) {
    if (preferTripId != null) {
      final trip = planner.trips[preferTripId];
      if (trip == null || trip.routeKey != routeKey) return false;
      final from = trip.stopById(fromStopId);
      if (from == null) return false;
      final to = trip.stopByIdAfter(toStopId, afterSequence: from.sequence) ??
          trip.stopById(toStopId);
      return to != null &&
          to.sequence > from.sequence &&
          gtfsTripTimesAreOrdered(from.depSec, to.depSec);
    }
    for (final tid in planner.tripIdsAtStop(fromStopId)) {
      final trip = planner.trips[tid];
      if (trip == null || trip.routeKey != routeKey) continue;
      final from = trip.stopById(fromStopId);
      final to = trip.stopById(toStopId);
      if (from != null &&
          to != null &&
          to.sequence > from.sequence &&
          gtfsTripTimesAreOrdered(from.depSec, to.depSec)) {
        return true;
      }
    }
    return false;
  }

  bool _isRedundantRidePrefix(PercorsoLeg first, PercorsoLeg second) {
    final board1 = first.boardStopId;
    final board2 = second.boardStopId;
    final route2 = second.routeKey;
    if (board1 == null || board2 == null || route2 == null || route2.isEmpty) {
      return false;
    }
    if (!planner.routeKeysAtStop(board1).contains(route2)) return false;
    return _stopIsDownstreamOnRoute(
      fromStopId: board1,
      toStopId: board2,
      routeKey: route2,
      preferTripId: second.tripId,
    );
  }

  /// Cambio bus di pochi minuti verso una linea che serve già la fermata precedente.
  bool _isWastefulBridgeRide(
    PercorsoLeg previous,
    PercorsoLeg middle,
    PercorsoLeg next,
  ) {
    final prevAlight = previous.alightStopId;
    final nextBoard = next.boardStopId;
    final nextRoute = next.routeKey;
    if (prevAlight == null ||
        nextBoard == null ||
        nextRoute == null ||
        nextRoute.isEmpty) {
      return false;
    }

    if (middle.start == null || middle.end == null) return false;
    final midDur = middle.end!.difference(middle.start!);
    if (midDur > const Duration(minutes: 8)) return false;

    if (!planner.routeKeysAtStop(prevAlight).contains(nextRoute)) {
      return false;
    }

    return _stopIsDownstreamOnRoute(
      fromStopId: prevAlight,
      toStopId: nextBoard,
      routeKey: nextRoute,
      preferTripId: next.tripId,
    );
  }

  bool _shouldHaveStayedOnPreviousRide(
    PercorsoLeg previous,
    PercorsoLeg connector,
    PercorsoLeg next,
  ) {
    final prevBoard = previous.boardStopId;
    final prevAlight = previous.alightStopId;
    final nextBoard = next.boardStopId;
    final prevRoute = previous.routeKey;
    if (prevBoard == null ||
        prevAlight == null ||
        nextBoard == null ||
        prevRoute == null ||
        prevRoute.isEmpty) {
      return false;
    }

    if (_stopIsDownstreamOnRoute(
      fromStopId: prevBoard,
      toStopId: nextBoard,
      routeKey: prevRoute,
      preferTripId: previous.tripId,
    )) {
      final prevAlightSeq = _stopSequenceOnRoute(
        prevAlight,
        prevRoute,
        previous.tripId,
      );
      final nextBoardSeq = _stopSequenceOnRoute(
        nextBoard,
        prevRoute,
        previous.tripId,
      );
      if (prevAlightSeq != null &&
          nextBoardSeq != null &&
          nextBoardSeq > prevAlightSeq) {
        return true;
      }
    }

    if (previous.to != null && next.from != null) {
      final walk = percorsoWalkEstimate(previous.to!, next.from!);
      if (walk.meters <= PercorsoConstants.maxTransferWalkMeters &&
          connector.start != null &&
          connector.end != null &&
          connector.end!.difference(connector.start!) <=
              const Duration(minutes: 12)) {
        return true;
      }
    }
    return false;
  }

  bool _isRedundantTransferPair(PercorsoLeg previous, PercorsoLeg next) {
    final prevAlight = previous.alightStopId;
    final nextBoard = next.boardStopId;
    final nextAlight = next.alightStopId;
    final prevRoute = previous.routeKey;
    if (prevAlight == null ||
        nextBoard == null ||
        nextAlight == null ||
        prevRoute == null ||
        prevRoute.isEmpty) {
      return false;
    }

    // Stesso punto di cambio (o praticamente stesso punto).
    var sameTransferNode = prevAlight == nextBoard;
    if (!sameTransferNode && previous.to != null && next.from != null) {
      final walk = percorsoWalkEstimate(previous.to!, next.from!);
      sameTransferNode = walk.meters <= 180;
    }
    if (!sameTransferNode) return false;

    // Se la corsa precedente può già portare alla fermata di arrivo della corsa successiva,
    // il cambio è ridondante.
    if (!_stopIsDownstreamOnRoute(
      fromStopId: prevAlight,
      toStopId: nextAlight,
      routeKey: prevRoute,
      preferTripId: previous.tripId,
    )) {
      return false;
    }

    if (previous.end != null && next.start != null) {
      final gap = next.start!.difference(previous.end!);
      if (gap < const Duration(minutes: -2)) return false;
      if (gap > const Duration(minutes: 14)) return false;
    }
    return true;
  }

  int? _stopSequenceOnRoute(
    String stopId,
    String routeKey,
    String? preferTripId,
  ) {
    if (preferTripId != null) {
      final trip = planner.trips[preferTripId];
      if (trip != null && trip.routeKey == routeKey) {
        return trip.stopById(stopId)?.sequence;
      }
    }
    for (final tid in planner.tripIdsAtStop(stopId)) {
      final trip = planner.trips[tid];
      if (trip == null || trip.routeKey != routeKey) continue;
      final stop = trip.stopById(stopId);
      if (stop != null) return stop.sequence;
    }
    return null;
  }

  List<TransitStopPin> get _allPins =>
      stopById.values.toList(growable: false);

  /// Allinea [stopClusterIds] alla [StopArea] del grafo (fonte unica di verità).
  PercorsoEndpoint _endpointWithResolvedStopArea(PercorsoEndpoint ep) {
    if (!ep.isStop) return ep;
    final ids = <String>{};
    for (final id in ep.effectiveStopIds) {
      final t = id.trim();
      if (t.isEmpty) continue;
      ids.addAll(resolveStopClusterIds(t));
    }
    if (ids.isEmpty) return ep;
    final list = ids.toList()..sort();
    return PercorsoEndpoint(
      label: ep.label,
      point: ep.point,
      stopId: ep.stopId ?? list.first,
      stopName: ep.stopName,
      stopClusterIds: list,
    );
  }

  List<String> _resolvedEndpointStopIds(PercorsoEndpoint ep) {
    if (!ep.isStop) return const [];
    final ids = <String>{};
    for (final id in ep.effectiveStopIds) {
      final t = id.trim();
      if (t.isEmpty) continue;
      ids.addAll(resolveStopClusterIds(t));
    }
    return ids.toList()..sort();
  }

  bool _endpointCoversStop(PercorsoEndpoint ep, String stopId) {
    if (!ep.isStop) return false;
    for (final id in ep.effectiveStopIds) {
      if (transitGraph.stopAreas.sameArea(id, stopId)) return true;
    }
    return false;
  }

  List<TransitStopPin> _pinsInStopArea(String seedStopId) {
    final pins = <TransitStopPin>[];
    for (final id in resolveStopClusterIds(seedStopId)) {
      final pin = stopById[id.trim()];
      if (pin != null) pins.add(pin);
    }
    return pins;
  }

  /// Aggiunge un cluster se l'area non è già presente; ritorna `true` se inserito.
  bool _tryAddStopAreaCluster(
    List<List<TransitStopPin>> clusters,
    Set<int> seenAreaIndices,
    String seedStopId,
  ) {
    final seed = seedStopId.trim();
    if (seed.isEmpty) return false;
    final areaIdx = transitGraph.stopAreas.areaIndexForStop(seed);
    if (areaIdx != null && !seenAreaIndices.add(areaIdx)) return false;
    final pins = _pinsInStopArea(seed);
    if (pins.isEmpty) return false;
    clusters.add(pins);
    return true;
  }

  void _markSeenStopArea(Set<String> seenStops, String seedStopId) {
    seenStops.addAll(resolveStopClusterIds(seedStopId));
  }

  /// Un rappresentante per ciascuna [StopArea] entro [radiusMeters], più vicino prima.
  List<TransitStopPin> _nearestStopAreaSeeds(
    LatLng origin,
    Iterable<TransitStopPin> stops, {
    required double radiusMeters,
    required int maxAreas,
  }) {
    final near = transitStopsWithinMeters(
      origin,
      stops,
      radiusMeters,
      maxResults: maxAreas * 6,
    );
    final seenAreas = <int>{};
    final seeds = <TransitStopPin>[];
    for (final pin in near) {
      final idx = transitGraph.stopAreas.areaIndexForStop(pin.stopId);
      if (idx != null) {
        if (!seenAreas.add(idx)) continue;
      }
      seeds.add(pin);
      if (seeds.length >= maxAreas) break;
    }
    return seeds;
  }

  /// Fermata richiesta dall'utente + tutti gli stop_id della stessa [StopArea].
  Set<String> _destinationTargetStopIds(PercorsoEndpoint to) {
    return _resolvedEndpointStopIds(to).toSet();
  }

  ({double meters, Duration duration}) _accessWalk(
    PercorsoEndpoint ep,
    TransitStopPin pin,
  ) {
    final w = percorsoWalkEstimate(ep.point, pin.point);
    if (_endpointCoversStop(ep, pin.stopId)) {
      return (meters: w.meters, duration: w.duration);
    }
    if (w.meters <= PercorsoConstants.maxAccessWalkMeters) return w;
    return (meters: double.infinity, duration: Duration.zero);
  }


  List<_StopCandidate> _stopCandidates(
    PercorsoEndpoint ep, {
    bool expanded = false,
  }) {
    final clusters = <List<TransitStopPin>>[];
    final seenAreas = <int>{};

    for (final id in _resolvedEndpointStopIds(ep)) {
      _tryAddStopAreaCluster(clusters, seenAreas, id);
    }

    if (clusters.isEmpty || !ep.isStop) {
      final maxNear =
          ep.isStop
              ? PercorsoConstants.maxStopCandidatesPerEnd
              : (expanded
                  ? PercorsoConstants.maxStopCandidatesAddressEnd + 3
                  : PercorsoConstants.maxStopCandidatesAddressEnd);
      final radiusM = ep.isStop ? 1200.0 : 3500.0;
      for (final seed in _nearestStopAreaSeeds(
        ep.point,
        _allPins,
        radiusMeters: radiusM,
        maxAreas: maxNear,
      )) {
        _tryAddStopAreaCluster(clusters, seenAreas, seed.stopId);
      }
      if (!ep.isStop) {
        for (final pin in nearestStopPerBasin(ep.point, _allPins)) {
          _tryAddStopAreaCluster(clusters, seenAreas, pin.stopId);
        }
      }
    }

    {
      final routes = <String>{};
      final seenStops = <String>{};
      for (final cluster in clusters) {
        for (final p in cluster) {
          routes.addAll(planner.routeKeysAtStop(p.stopId));
          _markSeenStopArea(seenStops, p.stopId);
        }
      }
      if (!ep.isStop) {
        for (final pin in transitStopsWithinMeters(
          ep.point,
          _allPins,
          PercorsoConstants.routeEnrichRadiusMeters,
          maxResults: 48,
        )) {
          routes.addAll(planner.routeKeysAtStop(pin.stopId));
        }
        _hintCorridorRoutes(ep.point, routes);
      }
      var added = 0;
      for (final rk in routes) {
        if (added >= PercorsoConstants.maxRoutesEnrichedPerEnd) break;
        for (final pin in _stopsServingRouteNearby(
          ep.point,
          rk,
          maxResults: 2,
          excludeStopIds: seenStops,
        )) {
          if (_tryAddStopAreaCluster(clusters, seenAreas, pin.stopId)) {
            _markSeenStopArea(seenStops, pin.stopId);
            added++;
          }
        }
      }
      // Fermate alternative entro raggio accesso (es. Zadina → Tagliata).
      for (final seed in _nearestStopAreaSeeds(
        ep.point,
        _allPins,
        radiusMeters: PercorsoConstants.maxAccessWalkMeters,
        maxAreas: PercorsoConstants.maxStopCandidatesPerEnd + 4,
      )) {
        if (seenStops.contains(seed.stopId)) continue;
        final w = percorsoWalkEstimate(ep.point, seed.point);
        if (w.meters > PercorsoConstants.maxAccessWalkMeters) continue;
        if (_tryAddStopAreaCluster(clusters, seenAreas, seed.stopId)) {
          _markSeenStopArea(seenStops, seed.stopId);
        }
      }

      // Hub di interscambio raggiungibili a piedi (es. Cesena/Forlì Punto Bus).
      if (!ep.isStop) {
        for (final pin in _reachableInterchangeHubs(ep.point, seenStops)) {
          if (_tryAddStopAreaCluster(clusters, seenAreas, pin.stopId)) {
            _markSeenStopArea(seenStops, pin.stopId);
          }
        }
      }
    }

    final out = <_StopCandidate>[];
    final seenKeys = <String>{};
    for (final cluster in clusters) {
      final cand = _candidateFromCluster(ep, cluster);
      if (cand == null) continue;
      final key = cand.stopIds.join('|');
      if (!seenKeys.add(key)) continue;
      out.add(cand);
    }
    return out;
  }

  /// Hub di interscambio (capolinea urbani / autostazioni) raggiungibili a
  /// piedi dall'origine/destinazione. Sono fermate ad alta connettività dove
  /// molte linee interurbane hanno il capolinea: vanno sempre inclusi come
  /// accesso/egress anche se più lontani delle fermate di quartiere.
  List<TransitStopPin> _reachableInterchangeHubs(
    LatLng origin,
    Set<String> exclude,
  ) {
    const minRoutesForHub = 6;
    final near = transitStopsWithinMeters(
      origin,
      _allPins,
      RouteEvaluator.standard.maxAccessEgressWalkMeters,
      maxResults: 80,
    );
    final out = <TransitStopPin>[];
    for (final p in near) {
      if (exclude.contains(p.stopId)) continue;
      final name = transitStopNameForDisplay(p.stopName);
      final isNamedHub = name.contains('PUNTO BUS') ||
          name.contains('AUTOSTAZIONE') ||
          name.contains('TERMINAL') ||
          name.contains('STAZIONE');
      final routeCount = planner.routeKeysAtStop(p.stopId).length;
      if (isNamedHub || routeCount >= minRoutesForHub) {
        out.add(p);
      }
    }
    return out;
  }

  /// Linee costiere FC↔RN non sempre presenti sulle fermate più vicine all’indirizzo.
  void _hintCorridorRoutes(LatLng point, Set<String> routes) {
    final near = transitStopsWithinMeters(
      point,
      _allPins,
      12000,
      maxResults: 8,
    );
    for (final p in near) {
      final c = (p.comune ?? '').toLowerCase();
      if (c.contains('cesenatico') ||
          c.contains('san mauro') ||
          c.contains('rimini')) {
        routes.add('FC|2CO');
        routes.add('FC|3CO');
        routes.add('RN|4');
      }
      if (c.contains('dovadola') || c.contains('forl')) {
        routes.add('FC|F126');
        routes.add('FC|F127');
      }
      if (c.contains('santa sofia') ||
          c.contains('galeata') ||
          c.contains('meldola') ||
          c.contains('cesenatico')) {
        routes.add('FC|S094');
        routes.add('FC|S092');
        routes.add('FC|F132');
      }
    }
  }

  List<TransitStopPin> _stopsServingRouteNearby(
    LatLng origin,
    String routeKey, {
    int maxResults = 3,
    Set<String> excludeStopIds = const {},
  }) {
    final pool = transitStopsWithinMeters(
      origin,
      _allPins,
      PercorsoConstants.routeEnrichRadiusMeters,
      maxResults: 160,
    );
    final scored = <MapEntry<TransitStopPin, double>>[];
    for (final p in pool) {
      if (excludeStopIds.contains(p.stopId)) continue;
      if (!planner.routeKeysAtStop(p.stopId).contains(routeKey)) continue;
      scored.add(MapEntry(p, percorsoWalkEstimate(origin, p.point).meters));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    if (scored.length > maxResults) {
      scored.removeRange(maxResults, scored.length);
    }
    return scored.map((e) => e.key).toList(growable: false);
  }

  _StopCandidate? _candidateFromCluster(
    PercorsoEndpoint ep,
    List<TransitStopPin> cluster,
  ) {
    if (cluster.isEmpty) return null;
    final allowFarAccess = !ep.isStop;

    final idList = resolveStopClusterIds(cluster.first.stopId).toList()..sort();

    TransitStopPin rep = cluster.first;
    var bestD = double.infinity;
    for (final sid in idList) {
      final pin = stopById[sid];
      if (pin == null) continue;
      final w = percorsoWalkEstimate(ep.point, pin.point);
      if (w.meters < bestD) {
        bestD = w.meters;
        rep = pin;
      }
    }
    var access = _accessWalk(ep, rep);
    if (!access.meters.isFinite) {
      if (!allowFarAccess) return null;
      access = percorsoWalkEstimate(ep.point, rep.point);
    }
    return _StopCandidate(pin: rep, stopIds: idList, accessWalk: access);
  }

  String _lineLabel(String routeKey) {
    final row = lineByRouteKey[routeKey];
    if (row != null) return 'Linea ${row.linea}';
    final parts = routeKey.split('|');
    return parts.length > 1 ? 'Linea ${parts[1]}' : routeKey;
  }

  bool _isPrenotazione(
    String stopId,
    String routeKey,
    String tripId,
    DateTime day,
  ) {
    final routes = schedule.routesAtStop(stopId);
    if (routes == null) return false;
    final entries = routes[routeKey];
    if (entries == null) return false;
    for (final e in entries) {
      if (e.tripId == tripId && e.isPrenotazione) return true;
    }
    return false;
  }

  PercorsoItinerary _buildWalkOnly(
    PercorsoEndpoint from,
    PercorsoEndpoint to,
    DateTime departAt,
    ({double meters, Duration duration}) walk,
  ) {
    final end = departAt.add(walk.duration);
    return PercorsoItinerary(
      legs: [
        PercorsoLeg(
          kind: PercorsoLegKind.walk,
          title: 'A piedi',
          subtitle:
              '${percorsoFormatWalkDistance(walk.meters)} · ${from.label} → ${to.label}',
          start: departAt,
          end: end,
          from: from.point,
          to: to.point,
        ),
      ],
      totalDuration: walk.duration,
      walkMeters: walk.meters,
      transfers: 0,
      profile: PercorsoProfile.fastest,
      recommendedWalkOnly: false,
    );
  }

  double _score({
    required double walkMeters,
    required Duration total,
    required int transfers,
    required bool hasPrenotazione,
    required PercorsoProfile profile,
    bool lateDeparture = false,
    DateTime? boardAt,
    DateTime? arriveAtStop,
  }) {
    final min = total.inMinutes.toDouble();
    final walkMin = walkMeters / 75;
    // Regola 1 (Pareto): penalità fissa per cambio. Centralizzata in
    // RouteEvaluator così la frontiera di Pareto preferisce le linee dirette a
    // quelle frammentate anche se leggermente più lente.
    final transferPen = switch (profile) {
      PercorsoProfile.fastest =>
        RouteEvaluator.standard.transferPenaltyMinutes(transfers),
      PercorsoProfile.minWalk => transfers * 10,
      PercorsoProfile.fewTransfers => transfers *
          PercorsoConstants.scoreTransferPenaltyFewChangesMin,
    };
    final walkWeight = switch (profile) {
      PercorsoProfile.fastest => PercorsoConstants.scoreWalkWeightFast,
      PercorsoProfile.minWalk => PercorsoConstants.scoreWalkWeightMinWalk,
      PercorsoProfile.fewTransfers => PercorsoConstants.scoreWalkWeightFast,
    };
    final pren =
        hasPrenotazione && profile == PercorsoProfile.fastest
            ? PercorsoConstants.prenotazionePenaltyFastMin.toDouble()
            : 0;
    var late = 0.0;
    if (lateDeparture) {
      late += PercorsoConstants.lateDepartureScorePenaltyMin;
    }
    if (boardAt != null && arriveAtStop != null && boardAt.isBefore(arriveAtStop)) {
      late += arriveAtStop.difference(boardAt).inMinutes * 0.4;
    }
    return min + walkMin * walkWeight + transferPen + pren + late;
  }

  /// Orario di arrivo assoluto (epoch secondi) dell'itinerario: fine dell'ultima
  /// gamba. Fallback su `fallbackDepart + totalDuration` se le gambe non hanno
  /// orari. Usato dal tie-break di Pareto (Punto E).
  int _arrivalEpochSec(PercorsoItinerary it, DateTime? fallbackDepart) {
    final end = it.legs.isNotEmpty ? it.legs.last.end : null;
    final dt = end ?? fallbackDepart?.add(it.totalDuration);
    if (dt == null) return it.totalDuration.inSeconds;
    return dt.millisecondsSinceEpoch ~/ 1000;
  }

  /// Metri dell'ultimo cammino di uscita (egress) verso la destinazione: 0 se
  /// l'itinerario termina con una corsa. Usato dalla Regola 3.
  double _finalEgressWalkMeters(PercorsoItinerary it) {
    for (final l in it.legs.reversed) {
      if (l.kind == PercorsoLegKind.ride) return 0;
      if (l.kind == PercorsoLegKind.walk) {
        if (l.from != null && l.to != null) {
          return percorsoWalkEstimate(l.from!, l.to!).meters;
        }
        return 0;
      }
    }
    return 0;
  }

  bool _isWalkOnly(PercorsoItinerary it) =>
      it.legs.every((l) => l.kind == PercorsoLegKind.walk);

  bool _hasTransit(PercorsoItinerary it) =>
      it.legs.any((l) => l.kind == PercorsoLegKind.ride);

  List<PercorsoItinerary> _finalize(
    List<_ScoredItinerary> candidates,
    PercorsoProfile profile,
    ({double meters, Duration duration}) walkDirect, {
    required PercorsoEndpoint to,
    PercorsoPlanQuality quality = PercorsoPlanQuality.strict,
    int dayOffset = 0,
    DateTime? departAt,
    DateTime? day,
  }) {
    if (candidates.isEmpty) return const [];

    final walks =
        candidates.where((c) => _isWalkOnly(c.itinerary)).toList()
          ..sort((a, b) => a.score.compareTo(b.score));
    var transit =
        candidates.where((c) => _hasTransit(c.itinerary)).toList()
          ..sort((a, b) {
            // Punto E: ordina sull'ORARIO DI ARRIVO ASSOLUTO, non sulla durata.
            final arrA = _arrivalEpochSec(a.itinerary, departAt);
            final arrB = _arrivalEpochSec(b.itinerary, departAt);
            final byArr = arrA.compareTo(arrB);
            final tied = RouteEvaluator.standard.arrivalsAreTied(arrA, arrB);
            if (byArr != 0 && !tied) return byArr;

            // §2c: a parità di arrivo (entro tolleranza) il MINOR NUMERO DI
            // CAMBI ha priorità sulla massimizzazione di bordo. Solo dopo, a
            // pari cambi, si applica la Regola 3 (resta sul mezzo / meno egress).
            final tc = a.itinerary.transfers.compareTo(b.itinerary.transfers);
            if (tc != 0) return tc;

            final egA = _finalEgressWalkMeters(a.itinerary);
            final egB = _finalEgressWalkMeters(b.itinerary);
            if ((egA - egB).abs() >
                RouteEvaluator.standard.boardMaximizationWalkMeters) {
              return egA.compareTo(egB);
            }
            if (byArr != 0) return byArr;
            return a.score.compareTo(b.score);
          });

    transit =
        transit
            .where(
              (c) => !_isNonsensicalItinerary(
                c.itinerary,
                day ?? DateTime.now(),
                odDirectMeters: walkDirect.meters,
              ),
            )
            .toList();

    bool walkIsFasterThanBestTransit() {
      if (transit.isEmpty) return false;
      final busLimit = Duration(
        milliseconds:
            (walkDirect.duration.inMilliseconds *
                    PercorsoConstants.busSlowerThanWalkRatio)
                .round(),
      );
      return transit.first.itinerary.totalDuration > busLimit;
    }

    final seen = <String>{};
    final out = <PercorsoItinerary>[];
    const max = PercorsoConstants.maxItinerariesReturned;

    void tryAdd(
      _ScoredItinerary c, {
      bool recommendedWalkOnly = false,
      PercorsoRoutingLabel? routingLabel,
    }) {
      if (out.length >= max) return;
      final it = _withProfile(
        c,
        profile,
        to: to,
        recommendedWalkOnly: recommendedWalkOnly,
        quality: quality,
        dayOffset: dayOffset,
        departAt: departAt,
        day: day,
        routingLabel: routingLabel,
      );
      final key = _dedupeKey(it);
      if (!seen.add(key)) return;
      out.add(it);
    }

    if (transit.isNotEmpty) {
      // Opzione 1 (tassativa): la più rapida per orario di arrivo reale.
      tryAdd(transit.first, routingLabel: PercorsoRoutingLabel.fastest);

      // Opzione 2/3: fino a 2 alternative non dominate, distinte per comfort.
      final picks = _diversifiedAlternatives(
        pool: transit.skip(1).toList(),
        best: transit.first.itinerary,
        day: day ?? DateTime.now(),
        odDirectMeters: walkDirect.meters,
        maxAlternatives: max - out.length,
      );
      for (final p in picks) {
        if (out.length >= max) break;
        tryAdd(p.candidate, routingLabel: p.label);
      }
    }

    if (walks.isNotEmpty && out.length < max) {
      tryAdd(
        walks.first,
        recommendedWalkOnly: walkIsFasterThanBestTransit(),
      );
    }

    if (out.isEmpty && candidates.isNotEmpty) {
      candidates.sort((a, b) => a.score.compareTo(b.score));
      for (final c in candidates) {
        if (!_isNonsensicalItinerary(
          c.itinerary,
          day ?? DateTime.now(),
          odDirectMeters: walkDirect.meters,
        )) {
          tryAdd(c);
          break;
        }
      }
      if (out.isEmpty) {
        tryAdd(candidates.first);
      }
    }

    return out;
  }

  bool _isNonsensicalItinerary(
    PercorsoItinerary it,
    DateTime day, {
    required double odDirectMeters,
  }) {
    final rides =
        it.legs.where((l) => l.kind == PercorsoLegKind.ride).toList();
    for (var i = 1; i < rides.length; i++) {
      final a = rides[i - 1].routeKey;
      final b = rides[i].routeKey;
      if (a != null && a.isNotEmpty && a == b) return true;
    }
    for (var i = 0; i < rides.length - 1; i++) {
      if (_isRedundantRidePrefix(rides[i], rides[i + 1])) return true;
      if (_isRedundantTransferPair(rides[i], rides[i + 1])) return true;
    }
    for (var i = 1; i < rides.length - 1; i++) {
      if (_isWastefulBridgeRide(rides[i - 1], rides[i], rides[i + 1])) {
        return true;
      }
      if (_shouldHaveStayedOnPreviousRide(
        rides[i - 1],
        rides[i],
        rides[i + 1],
      )) {
        return true;
      }
    }
    // Catene di trasferimenti a piedi consecutivi (cammina · attendi · cammina ·
    // …) senza una corsa in mezzo: sempre insensate. Nascono da round RAPTOR in
    // cui una fermata servita da corsa viene sovrascritta da un transfer.
    var consecutiveTransferWalks = 0;
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.ride) {
        consecutiveTransferWalks = 0;
      } else if (l.kind == PercorsoLegKind.walk && l.title.contains('Cambio')) {
        consecutiveTransferWalks++;
        if (consecutiveTransferWalks >= 2) return true;
      }
      // I leg di attesa non interrompono la catena di cammino.
    }

    final walkCap = _maxWalkMetersForOd(odDirectMeters);
    if (it.transfers >= 3 && it.walkMeters > walkCap) return true;
    if (it.transfers >= 2 && it.walkMeters > walkCap * 0.85) return true;
    if (it.transfers >= 1 && it.walkMeters > walkCap * 0.65) return true;
    return false;
  }

  static double _maxWalkMetersForOd(double odDirectMeters) {
    if (odDirectMeters >= 25000) return 9000;
    if (odDirectMeters >= 15000) return 6500;
    if (odDirectMeters >= 8000) return 4500;
    return 3200;
  }

  bool _isDominated(PercorsoItinerary best, PercorsoItinerary other) {
    if (other.transfers > best.transfers &&
        other.totalDuration >=
            best.totalDuration - const Duration(minutes: 4) &&
        other.walkMeters >= best.walkMeters - 120) {
      return true;
    }
    if (other.totalDuration >
            best.totalDuration +
                Duration(
                  minutes: PercorsoConstants.meaningfulAlternativeMaxExtraMin,
                ) &&
        other.transfers >= best.transfers) {
      return true;
    }
    return false;
  }

  /// Minuti totali di attesa (tempi morti) di un itinerario.
  double _totalWaitMinutes(PercorsoItinerary it) {
    var sec = 0;
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.wait && l.start != null && l.end != null) {
        sec += l.end!.difference(l.start!).inSeconds;
      }
    }
    return sec / 60.0;
  }

  /// Vero se [other] è un'alternativa di COMFORT proponibile rispetto a [best]:
  /// non dominata, sensata, distinta, entro una finestra di arrivo ampia e con
  /// un vantaggio netto su almeno un asse (meno piedi / meno cambi / più veloce
  /// / meno attesa). Tolleranze volutamente larghe (Opzione 2/3).
  bool _isMeaningfulAlternative(
    PercorsoItinerary best,
    PercorsoItinerary other,
    DateTime day, {
    required double odDirectMeters,
  }) {
    if (_isDominated(best, other) ||
        _isNonsensicalItinerary(other, day, odDirectMeters: odDirectMeters)) {
      return false;
    }
    if (_dedupeKey(best) == _dedupeKey(other)) return false;
    // Finestra di arrivo ampia: un'alternativa di comfort può arrivare dopo.
    if (other.totalDuration >
        best.totalDuration +
            Duration(
              minutes: PercorsoConstants.comfortAlternativeMaxExtraMin,
            )) {
      return false;
    }
    if (other.transfers > best.transfers + 2) return false;

    final lessWalk = best.walkMeters - other.walkMeters >=
        PercorsoConstants.diversifyMinWalkSavingMeters;
    final fewerTransfers = other.transfers < best.transfers;
    final faster =
        other.totalDuration < best.totalDuration - const Duration(minutes: 3);
    final smoother = _totalWaitMinutes(best) - _totalWaitMinutes(other) >=
        PercorsoConstants.diversifyMinWaitSavingMin;
    return lessWalk || fewerTransfers || faster || smoother;
  }

  /// Estrae fino a [maxAlternatives] alternative di comfort distinte da [best],
  /// ciascuna etichettata con il profilo per cui eccelle (Opzione 2/3).
  List<({_ScoredItinerary candidate, PercorsoRoutingLabel label})>
      _diversifiedAlternatives({
    required List<_ScoredItinerary> pool,
    required PercorsoItinerary best,
    required DateTime day,
    required double odDirectMeters,
    required int maxAlternatives,
  }) {
    final out =
        <({_ScoredItinerary candidate, PercorsoRoutingLabel label})>[];
    if (maxAlternatives <= 0) return out;

    final bestKey = _dedupeKey(best);
    final used = <String>{bestKey};

    // Candidati validi: distinti, sensati, non dominati e proponibili.
    final valid = pool
        .where((c) => _dedupeKey(c.itinerary) != bestKey)
        .where((c) => _isMeaningfulAlternative(
              best,
              c.itinerary,
              day,
              odDirectMeters: odDirectMeters,
            ))
        .toList();
    if (valid.isEmpty) return out;

    final bestWait = _totalWaitMinutes(best);

    // --- Profilo "Meno strada a piedi" ---
    _ScoredItinerary? lessWalk;
    for (final c in valid) {
      final it = c.itinerary;
      if (used.contains(_dedupeKey(it))) continue;
      if (best.walkMeters - it.walkMeters <
          PercorsoConstants.diversifyMinWalkSavingMeters) {
        continue;
      }
      if (lessWalk == null ||
          it.walkMeters < lessWalk.itinerary.walkMeters) {
        lessWalk = c;
      }
    }
    if (lessWalk != null) {
      out.add((candidate: lessWalk, label: PercorsoRoutingLabel.lessWalking));
      used.add(_dedupeKey(lessWalk.itinerary));
    }

    // --- Profilo "Meno cambi" ---
    if (out.length < maxAlternatives) {
      _ScoredItinerary? fewer;
      for (final c in valid) {
        final it = c.itinerary;
        if (used.contains(_dedupeKey(it))) continue;
        if (it.transfers >= best.transfers) continue;
        if (fewer == null ||
            it.transfers < fewer.itinerary.transfers ||
            (it.transfers == fewer.itinerary.transfers &&
                it.totalDuration < fewer.itinerary.totalDuration)) {
          fewer = c;
        }
      }
      if (fewer != null) {
        out.add(
            (candidate: fewer, label: PercorsoRoutingLabel.fewerTransfers));
        used.add(_dedupeKey(fewer.itinerary));
      }
    }

    // --- Profilo "Più fluido" (meno attesa) ---
    if (out.length < maxAlternatives) {
      _ScoredItinerary? smoother;
      var smootherWait = double.infinity;
      for (final c in valid) {
        final it = c.itinerary;
        if (used.contains(_dedupeKey(it))) continue;
        final w = _totalWaitMinutes(it);
        if (bestWait - w < PercorsoConstants.diversifyMinWaitSavingMin) {
          continue;
        }
        if (w < smootherWait) {
          smoother = c;
          smootherWait = w;
        }
      }
      if (smoother != null) {
        out.add((
          candidate: smoother,
          label: PercorsoRoutingLabel.smootherTravel,
        ));
        used.add(_dedupeKey(smoother.itinerary));
      }
    }

    return out.take(maxAlternatives).toList();
  }

  PercorsoItinerary _withProfile(
    _ScoredItinerary c,
    PercorsoProfile profile, {
    required PercorsoEndpoint to,
    bool recommendedWalkOnly = false,
    PercorsoPlanQuality quality = PercorsoPlanQuality.strict,
    int dayOffset = 0,
    DateTime? departAt,
    DateTime? day,
    PercorsoRoutingLabel? routingLabel,
  }) {
    final it = c.itinerary;
    final legs = List<PercorsoLeg>.from(it.legs);
    if (day != null) {
      _optimizeTransferAlightsOnLegs(legs, day);
      _optimizeFinalEgressAlightOnLegs(legs, to, day);
      _collapseRedundantTransferWalks(legs);
    }
    var walkMeters = 0.0;
    for (final l in legs) {
      if (l.kind != PercorsoLegKind.walk) continue;
      if (l.from != null && l.to != null) {
        walkMeters += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    var transfers = 0;
    var sawRide = false;
    for (final l in legs) {
      if (l.kind == PercorsoLegKind.ride) {
        if (sawRide) transfers++;
        sawRide = true;
      }
    }
    var totalDuration = it.totalDuration;
    if (departAt != null && legs.isNotEmpty && legs.last.end != null) {
      totalDuration = legs.last.end!.difference(departAt);
    }
    var late = it.departsLaterThanRequested;
    if (!late &&
        quality == PercorsoPlanQuality.strict &&
        dayOffset == 0 &&
        departAt != null &&
        day != null) {
      for (final leg in legs) {
        if (leg.kind != PercorsoLegKind.ride || leg.start == null) continue;
        if (leg.start!.isAfter(departAt.add(const Duration(minutes: 6)))) {
          late = true;
          break;
        }
      }
    }
    return PercorsoItinerary(
      legs: legs,
      totalDuration: totalDuration,
      walkMeters: walkMeters,
      transfers: transfers,
      profile: profile,
      recommendedWalkOnly: recommendedWalkOnly,
      hasPrenotazione: it.hasPrenotazione,
      departsLaterThanRequested: late || quality == PercorsoPlanQuality.laterToday,
      planQuality: quality,
      suggestedDayOffset: dayOffset,
      score: c.score,
      hasBrokenWalkConnection: it.hasBrokenWalkConnection,
      routingLabel: routingLabel,
    );
  }

  String _dedupeKey(PercorsoItinerary it) {
    final rides =
        it.legs
            .where((l) => l.kind == PercorsoLegKind.ride)
            .map((l) => '${l.routeKey}@${l.tripId}')
            .join('>');
    final kind = _isWalkOnly(it) ? 'w' : 't';
    return '$kind|${it.transfers}|$rides';
  }
}

class _StopCandidate {
  const _StopCandidate({
    required this.pin,
    required this.stopIds,
    required this.accessWalk,
  });

  final TransitStopPin pin;
  final List<String> stopIds;
  final ({double meters, Duration duration}) accessWalk;
}

class _ScoredItinerary {
  const _ScoredItinerary(this.itinerary, this.score);

  final PercorsoItinerary itinerary;
  final double score;
}

enum _RJKind { access, ride, transfer }

class _RaptorJourney {
  _RaptorJourney._({
    required this.kind,
    this.boardStopId,
    required this.alightStopId,
    this.tripId,
    this.routeKey,
    this.prevStopId,
    this.boardSec = 0,
    this.alightSec = 0,
    this.boardSeq,
    this.alightSeq,
  });

  factory _RaptorJourney.access(String stopId, int arrSec) => _RaptorJourney._(
        kind: _RJKind.access,
        alightStopId: stopId,
        alightSec: arrSec,
      );

  factory _RaptorJourney.ride({
    required String boardStopId,
    required String alightStopId,
    required String tripId,
    required String routeKey,
    required int boardSec,
    required int alightSec,
    required int boardSeq,
    required int alightSeq,
  }) =>
      _RaptorJourney._(
        kind: _RJKind.ride,
        boardStopId: boardStopId,
        alightStopId: alightStopId,
        tripId: tripId,
        routeKey: routeKey,
        prevStopId: boardStopId,
        boardSec: boardSec,
        alightSec: alightSec,
        boardSeq: boardSeq,
        alightSeq: alightSeq,
      );

  factory _RaptorJourney.transfer({
    required String fromStopId,
    required String toStopId,
    required int arrSec,
  }) =>
      _RaptorJourney._(
        kind: _RJKind.transfer,
        boardStopId: fromStopId,
        alightStopId: toStopId,
        prevStopId: fromStopId,
        alightSec: arrSec,
      );

  final _RJKind kind;
  final String? boardStopId;
  final String alightStopId;
  final String? tripId;
  final String? routeKey;
  final String? prevStopId;
  final int boardSec;
  final int alightSec;

  /// Sequenza GTFS del passaggio reale (disambigua le linee ad anello).
  final int? boardSeq;
  final int? alightSeq;
}

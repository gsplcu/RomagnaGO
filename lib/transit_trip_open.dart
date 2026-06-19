// Apertura tabellone fermate (corsa GTFS) da calendario o chip « Prossime partenze ».

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'infobus_realtime.dart';
import 'linee_percorsi.dart';
import 'transiti_at_stop.dart';
import 'transit_stops.dart';
import 'transit_trip_timetable_page.dart';
import 'stop_transit_schedule.dart';

/// Risultato dell’abbinamento fermata × orario programmato → viaggio GTFS.
class TripResolveResult {
  const TripResolveResult({required this.routeKey, required this.tripId});

  final String routeKey;
  final String tripId;
}

String _hmFromDateTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

List<String> _routeKeysForTripResolve({
  required StopTransitScheduleIndex schedule,
  required String rawStopId,
  required List<String> routeKeys,
  required String towards,
}) {
  final keys =
      routeKeys
          .map((k) => k.trim())
          .where((k) => k.isNotEmpty)
          .toSet();
  final atStop = schedule.routesAtStop(rawStopId);
  if (atStop != null) {
    keys.addAll(atStop.keys.map((k) => k.trim()).where((k) => k.isNotEmpty));
  }
  // Gatteo Mare in catalogo è spesso su S094; InfoBus la mostra anche come 1/2 CO.
  final destNorm = normalizeTransitDestinationForMatch(towards);
  if (destNorm.contains('GATTEO MARE')) {
    keys.add('FC|S094');
  }
  return keys.toList();
}

TripResolveResult? _pickFromEntries({
  required String routeKey,
  required List<StopTransitScheduleEntry> entries,
  required String scheduledHmForMatch,
  required String towards,
}) {
  final byTime =
      entries
          .where(
            (e) => infobusScheduledMatchesGtfsDep(scheduledHmForMatch, e.depRaw),
          )
          .toList();
  StopTransitScheduleEntry? pick;
  if (byTime.length == 1) {
    pick = byTime.first;
  } else if (byTime.length > 1) {
    final withDest =
        byTime
            .where((e) => infobusDestSoftMatch(towards, e.destination))
            .toList();
    if (withDest.length == 1) {
      pick = withDest.first;
    }
  }
  if (pick != null && pick.tripId.isNotEmpty) {
    return TripResolveResult(routeKey: routeKey, tripId: pick.tripId);
  }
  return null;
}

/// Individua `trip_id` e chiave linea per una partenza alla fermata [rawStopId].
TripResolveResult? resolveTripForStopDeparture({
  required StopTransitScheduleIndex schedule,
  required String rawStopId,
  required List<String> routeKeys,
  required DateTime onLocalDay,
  required String scheduledHmForMatch,
  required String towards,
  String? infobusTripIdHint,
}) {
  final sid = rawStopId.trim();
  if (sid.isEmpty || routeKeys.isEmpty) return null;

  final searchKeys = _routeKeysForTripResolve(
    schedule: schedule,
    rawStopId: sid,
    routeKeys: routeKeys,
    towards: towards,
  );

  final tidHint = infobusTripIdHint?.trim() ?? '';
  if (tidHint.isNotEmpty) {
    final global = schedule.findTripIdOnRoutes(tidHint, searchKeys);
    if (global != null) {
      return TripResolveResult(
        routeKey: global.routeKey,
        tripId: global.tripId,
      );
    }

    for (final rk in searchKeys) {
      final entries = schedule.entriesForKeys(
        sid,
        [rk],
        onLocalDay: onLocalDay,
      );
      for (final e in entries) {
        if (e.tripId == tidHint &&
            infobusScheduledMatchesGtfsDep(scheduledHmForMatch, e.depRaw)) {
          return TripResolveResult(routeKey: rk, tripId: e.tripId);
        }
      }
    }

    for (final rk in searchKeys) {
      final entries = schedule.entriesForKeys(
        sid,
        [rk],
        applyServiceCalendarFilter: false,
      );
      for (final e in entries) {
        if (e.tripId == tidHint &&
            infobusScheduledMatchesGtfsDep(scheduledHmForMatch, e.depRaw)) {
          return TripResolveResult(routeKey: rk, tripId: e.tripId);
        }
      }
    }
  }

  for (final rk in searchKeys) {
    final entries = schedule.entriesForKeys(
      sid,
      [rk],
      onLocalDay: onLocalDay,
    );
    final picked = _pickFromEntries(
      routeKey: rk,
      entries: entries,
      scheduledHmForMatch: scheduledHmForMatch,
      towards: towards,
    );
    if (picked != null) return picked;
  }

  for (final rk in searchKeys) {
    final entries = schedule.entriesForKeys(
      sid,
      [rk],
      applyServiceCalendarFilter: false,
    );
    final picked = _pickFromEntries(
      routeKey: rk,
      entries: entries,
      scheduledHmForMatch: scheduledHmForMatch,
      towards: towards,
    );
    if (picked != null) return picked;
  }

  return null;
}

Future<void> _openTripTimetableWithRows({
  required BuildContext context,
  required String lineLabelForTitle,
  required String routeComposite,
  required String rawStopId,
  required String stopNameUi,
  required List<TransitTripStopRow> rows,
  required Map<String, String> stopIdToName,
  required String towardsDestination,
  required String scheduledHmForDisplay,
  InfobusArrivalCard? infobusRtCard,
  String? partitoAlleHm,
}) async {
  if (!context.mounted || rows.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder:
          (_) => TransitTripTimetablePage(
            lineLabel: lineLabelForTitle,
            routeComposite: routeComposite,
            selectedStopId: rawStopId.trim(),
            selectedStopNameUi: stopNameUi,
            rows: rows,
            stopIdToName: stopIdToName,
            towardsDestination: towardsDestination,
            scheduledHmDisplay: scheduledHmForDisplay,
            infobusRtCard: infobusRtCard,
            partitoAlleHm: partitoAlleHm,
          ),
    ),
  );
}

String _routeCompositeForTripOpen({
  TripResolveResult? resolved,
  required StopTransitLineBubble bubble,
  required String lineLabelForTitle,
}) {
  final fromResolve = resolved?.routeKey.trim() ?? '';
  if (fromResolve.isNotEmpty) return fromResolve;
  for (final k in bubble.scheduleRouteKeys) {
    if (k.trim().isNotEmpty) return k.trim();
  }
  return lineLabelForTitle.trim();
}

/// Apre [TransitTripTimetablePage] se la corsa è risolvibile; altrimenti [onFallback] (es. foglio linea).
Future<void> openTransitTripTimetable({
  required BuildContext context,
  required StopTransitScheduleIndex schedule,
  required String rawStopId,
  required String stopNameUi,
  required StopTransitLineBubble bubble,
  required DateTime onLocalDay,
  required String scheduledHmForMatch,
  required String scheduledHmForDisplay,
  required String towardsDestination,
  required String lineLabelForTitle,
  InfobusArrivalCard? infobusRtCard,
  String? partitoAlleHm,
  VoidCallback? onFallback,
}) async {
  final resolved = resolveTripForStopDeparture(
    schedule: schedule,
    rawStopId: rawStopId,
    routeKeys: bubble.scheduleRouteKeys,
    onLocalDay: onLocalDay,
    scheduledHmForMatch: scheduledHmForMatch,
    towards: towardsDestination,
    infobusTripIdHint: infobusRtCard?.tripId,
  );

  var rows =
      resolved != null
          ? schedule.tripStopsForTrip(resolved.routeKey, resolved.tripId)
          : const <TransitTripStopRow>[];
  var routeComposite = _routeCompositeForTripOpen(
    resolved: resolved,
    bubble: bubble,
    lineLabelForTitle: lineLabelForTitle,
  );

  if (rows.isEmpty) {
    final tripHint = infobusRtCard?.tripId?.trim() ?? '';
    final palina = rawStopId.trim();
    if (tripHint.isNotEmpty && palina.isNotEmpty) {
      final percorso = await infobusFetchTripPercorso(
        tripId: tripHint,
        palina: palina,
      );
      if (!context.mounted) return;
      if (percorso != null && percorso.isNotEmpty) {
        rows = transitTripRowsFromInfobusPercorso(percorso);
        final catalogNames = await loadTransitStopIdToDisplayNameMap();
        if (!context.mounted) return;
        final names = {
          ...catalogNames,
          ...stopNamesFromInfobusPercorso(percorso),
        };
        await _openTripTimetableWithRows(
          context: context,
          lineLabelForTitle: lineLabelForTitle,
          routeComposite: routeComposite,
          rawStopId: rawStopId,
          stopNameUi: stopNameUi,
          rows: rows,
          stopIdToName: names,
          towardsDestination: towardsDestination,
          scheduledHmForDisplay: scheduledHmForDisplay,
          infobusRtCard: infobusRtCard,
          partitoAlleHm: partitoAlleHm,
        );
        return;
      }
    }
  }

  if (rows.isEmpty) {
    if (context.mounted) {
      if (infobusRtCard == null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              'Dettaglio fermate della corsa non disponibile nei dati locali.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      if (context.mounted) {
        onFallback?.call();
      }
    }
    return;
  }

  final names = await loadTransitStopIdToDisplayNameMap();
  if (!context.mounted) return;

  await _openTripTimetableWithRows(
    context: context,
    lineLabelForTitle: lineLabelForTitle,
    routeComposite: routeComposite,
    rawStopId: rawStopId,
    stopNameUi: stopNameUi,
    rows: rows,
    stopIdToName: names,
    towardsDestination: towardsDestination,
    scheduledHmForDisplay: scheduledHmForDisplay,
    infobusRtCard: infobusRtCard,
    partitoAlleHm: partitoAlleHm,
  );
}

/// Tap chip « Partenze precedenti ».
Future<void> openTripTimetableForRecentPastDeparture(
  BuildContext context, {
  required StopTransitScheduleIndex schedule,
  required Map<String, RomagnaLineaRow> lineeByComposite,
  required String rawStopId,
  required String stopNameUi,
  required RecentPastDepartureUi past,
  required StopTransitLineBubble bubble,
}) async {
  final u = past.departure;
  final onLocalDay = DateTime(
    past.effectiveDeparture.year,
    past.effectiveDeparture.month,
    past.effectiveDeparture.day,
  );
  final scheduledHmForMatch = _hmFromDateTime(u.when);
  final scheduledHmForDisplay = u.clockLabel;

  void openLineAtStop() {
    if (!context.mounted) return;
    final sid = rawStopId.trim();
    RomagnaLineaRow? lineInfoRow;
    for (final composite in bubble.scheduleRouteKeys) {
      final row = lineeByComposite[composite];
      if (row != null) {
        lineInfoRow = row;
        break;
      }
    }
    showTransitLineDeparturesSheet(
      context,
      stopNameUi: stopNameUi,
      stopIdUi: sid,
      bubble: bubble,
      lineInfoRow: lineInfoRow,
      entriesToday: schedule.entriesForKeys(
        sid,
        bubble.scheduleRouteKeys,
        onLocalDay: DateTime.now(),
      ),
      entriesAllProfiles: schedule.entriesForKeys(
        sid,
        bubble.scheduleRouteKeys,
        applyServiceCalendarFilter: false,
      ),
      calendar: schedule.serviceCalendarOrNull,
    );
  }

  await openTransitTripTimetable(
    context: context,
    schedule: schedule,
    rawStopId: rawStopId,
    stopNameUi: stopNameUi,
    bubble: bubble,
    onLocalDay: onLocalDay,
    scheduledHmForMatch: scheduledHmForMatch,
    scheduledHmForDisplay: scheduledHmForDisplay,
    towardsDestination: u.towards,
    lineLabelForTitle: u.lineLabel,
    infobusRtCard: past.infobusCard,
    partitoAlleHm: past.effectiveClockLabel,
    onFallback: openLineAtStop,
  );
}

/// Tap chip « Prossime partenze » (InfoBus): tabellone corsa con RT in testa; fallback foglio linea.
Future<void> openTripTimetableForUpcomingDeparture(
  BuildContext context, {
  required StopTransitScheduleIndex schedule,
  required Map<String, RomagnaLineaRow> lineeByComposite,
  required String rawStopId,
  required String stopNameUi,
  required UpcomingTransitDepartureUi u,
  required InfobusArrivalCard? matchedSiteCard,
  required StopTransitLineBubble bubble,
}) async {
  final onLocalDay = DateTime(u.when.year, u.when.month, u.when.day);
  final scheduledHmForMatch = _hmFromDateTime(u.when);
  final scheduledHmForDisplay =
      u.dayPrefix.isEmpty ? u.clockLabel : '${u.dayPrefix}${u.clockLabel}';

  void openLineAtStop() {
    if (!context.mounted) return;
    final sid = rawStopId.trim();
    RomagnaLineaRow? lineInfoRow;
    for (final composite in bubble.scheduleRouteKeys) {
      final row = lineeByComposite[composite];
      if (row != null) {
        lineInfoRow = row;
        break;
      }
    }
    showTransitLineDeparturesSheet(
      context,
      stopNameUi: stopNameUi,
      stopIdUi: sid,
      bubble: bubble,
      lineInfoRow: lineInfoRow,
      entriesToday: schedule.entriesForKeys(
        sid,
        bubble.scheduleRouteKeys,
        onLocalDay: DateTime.now(),
      ),
      entriesAllProfiles: schedule.entriesForKeys(
        sid,
        bubble.scheduleRouteKeys,
        applyServiceCalendarFilter: false,
      ),
      calendar: schedule.serviceCalendarOrNull,
    );
  }

  await openTransitTripTimetable(
    context: context,
    schedule: schedule,
    rawStopId: rawStopId,
    stopNameUi: stopNameUi,
    bubble: bubble,
    onLocalDay: onLocalDay,
    scheduledHmForMatch: scheduledHmForMatch,
    scheduledHmForDisplay: scheduledHmForDisplay,
    towardsDestination: u.towards,
    lineLabelForTitle: u.lineLabel,
    infobusRtCard: matchedSiteCard,
    onFallback: openLineAtStop,
  );
}

// Orari di transito per stop_id da assets/data/transit_times_by_stop.json (+ UI foglio fermata).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'line_display.dart';
import 'linee_percorsi.dart';
import 'romagna_brand.dart';
import 'service_calendar.dart';
import 'transiti_at_stop.dart';

/// Pagina ufficiale Start Romagna per prenotare le corse contrassegnate con «P».
const _kStartRomagnaCorsePrenotazioneUrl =
    'https://www.startromagna.it/servizi/corse-su-prenotazione/';

Future<void> _openStartRomagnaCorsePrenotazione(BuildContext context) async {
  final uri = Uri.parse(_kStartRomagnaCorsePrenotazioneUrl);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'Impossibile aprire il browser per la prenotazione.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Impossibile aprire il browser per la prenotazione.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

void _showCorsaSuPrenotazioneInfoDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final bodyStyle = GoogleFonts.inter(
        fontSize: 14,
        height: 1.45,
        color: kRomagnaDarkGray.withValues(alpha: 0.88),
      );
      final linkStyle = GoogleFonts.inter(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w700,
        color: kRomagnaPrimary,
        decoration: TextDecoration.underline,
        decorationColor: kRomagnaPrimary,
      );

      return AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        title: Text(
          'Corsa su prenotazione',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: kRomagnaDarkGray,
          ),
        ),
        content: Text.rich(
          TextSpan(
            style: bodyStyle,
            children: [
              const TextSpan(
                text:
                    'Questa corsa viene effettuata soltanto su prenotazione. ',
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.of(dialogContext).pop();
                      if (!context.mounted) return;
                      await _openStartRomagnaCorsePrenotazione(context);
                    },
                    child: Text('Prenota qui', style: linkStyle),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class StopTransitScheduleEntry {
  const StopTransitScheduleEntry({
    required this.depRaw,
    required this.destination,
    this.serviceId = '',
    this.isPrenotazione = false,
    this.tripId = '',
    this.stopSequence = 0,
    this.isTripEndArrival = false,
  });

  final String depRaw;
  final String destination;

  /// GTFS `service_id` (variante feriale/festiva/domenicale nell’aggregato Start Romagna).
  final String serviceId;

  /// Da `transit_times_by_stop.json`: `"P":"1"` = corsa su prenotazione (libretto FC).
  final bool isPrenotazione;

  /// GTFS `trip_id` (da `transit_times_by_stop.json` v3+); vuoto negli asset legacy.
  final String tripId;

  /// Progressiva fermata sul viaggio (v3+); 0 se assente.
  final int stopSequence;

  /// Da v4: ultimo stop del viaggio (`"end":1`), orario = arrivo al capolinea; escluso dalle partenze.
  final bool isTripEndArrival;
}

/// Legacy: non si fondono più 1CO e 2CO in un’unica bubble.
bool isMergedFcOneTwoCoBubble(StopTransitLineBubble bubble) => false;

/// Risolve duplicati da fusione 1/2 CO: stesso slot minuti (precisione HH:MM nello GTFS giorno‑servizio)
/// − stesso `dest` ⇒ un solo record.
/// − se nello slot compaiono sia capolinee **Atlantica** sia **Zadina**, tieni solo le corse verso **Zadina**
///   (le verso Atlantica sono tratte inclusa nella zona Atlantica; non può essere la stessa partenza fisica due capolinee).
///
/// Altri binari rimangono tutti separati così risultano da dati.
List<StopTransitScheduleEntry> prepareEntriesForBubble(
  StopTransitLineBubble bubble,
  List<StopTransitScheduleEntry> raw,
) {
  if (!isMergedFcOneTwoCoBubble(bubble)) return [...raw];

  final byMinute = <int, List<StopTransitScheduleEntry>>{};
  for (final e in raw) {
    final min = gtfsWallMinutesSinceServiceMidnight(e.depRaw);
    if (min == null) continue;
    byMinute.putIfAbsent(min, () => []).add(e);
  }

  final out = <StopTransitScheduleEntry>[];
  for (final bucket in byMinute.keys.toList()..sort()) {
    var xs = List<StopTransitScheduleEntry>.from(byMinute[bucket]!);

    final hasZad = xs.any((e) => _destIsLikelyZadina(e.destination));
    final hasAtl = xs.any((e) => _destIsLikelyAtlanticaTerminal(e.destination));
    if (hasZad && hasAtl) {
      xs =
          xs
              .where((e) => !_destIsLikelyAtlanticaTerminal(e.destination))
              .toList();
    }

    // Stessa destinazione + stesso `service_id` (es. transito identico su 1CO e 2CO) → una sola corsa.
    // Destinazione uguale ma `service_id` diverso → tieni entrambe (feriale/festivo differenziato).
    final dedup = <String, StopTransitScheduleEntry>{};
    for (final e in xs) {
      final dk = '${e.destination.trim()}|${e.serviceId.trim()}';
      final prev = dedup[dk];
      if (prev == null) {
        dedup[dk] = e;
      } else if (!prev.isPrenotazione && e.isPrenotazione) {
        dedup[dk] = StopTransitScheduleEntry(
          depRaw: prev.depRaw,
          destination: prev.destination,
          serviceId: prev.serviceId,
          isPrenotazione: true,
          tripId: prev.tripId.isNotEmpty ? prev.tripId : e.tripId,
          stopSequence: prev.stopSequence != 0 ? prev.stopSequence : e.stopSequence,
          isTripEndArrival: prev.isTripEndArrival || e.isTripEndArrival,
        );
      }
    }
    out.addAll(dedup.values);
  }

  out.sort(
    (a, b) => (gtfsWallSeconds(a.depRaw) ?? 0).compareTo(
      gtfsWallSeconds(b.depRaw) ?? 0,
    ),
  );
  return out;
}

int? gtfsWallMinutesSinceServiceMidnight(String depRaw) {
  final s = gtfsWallSeconds(depRaw);
  if (s == null) return null;
  return s ~/ 60;
}

bool _destIsLikelyAtlanticaTerminal(String destination) {
  final d = destination.trim().toLowerCase();
  return d == 'atlantica' || d.endsWith(' > atlantica');
}

bool _destIsLikelyZadina(String destination) {
  final d = destination.trim().toLowerCase();
  return d == 'zadina' || d.endsWith(' > zadina');
}

/// Normalizza il testo destinazione per confronti (maiuscole, senza suffissi tra parentesi).
String normalizeTransitDestinationForMatch(String raw) {
  var t = raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

/// Confronto tollerante (es. «Gatteo Mare» = «Gatteo Mare (Via Euclide)»).
bool transitDestinationsMatch(String a, String b) {
  final na = normalizeTransitDestinationForMatch(a);
  final nb = normalizeTransitDestinationForMatch(b);
  if (na.isEmpty || nb.isEmpty) return false;
  if (na == nb) return true;
  if (na.contains(nb) || nb.contains(na)) return true;
  final minLen = na.length < nb.length ? na.length : nb.length;
  if (minLen >= 8 && na.substring(0, minLen) == nb.substring(0, minLen)) {
    return true;
  }
  return false;
}

/// Riferimento viaggio GTFS su una linea del grafo orari.
class ScheduleTripRef {
  const ScheduleTripRef({required this.routeKey, required this.tripId});

  final String routeKey;
  final String tripId;
}

DateTime _localDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Indice: `stop_id` → chiave linea [`BACINO`|`route_id`] → partenze dalla fermata.
class StopTransitScheduleIndex {
  StopTransitScheduleIndex._(this._byStopId, this.loadFailed, this._calendar);

  final Map<String, Map<String, List<StopTransitScheduleEntry>>> _byStopId;
  final bool loadFailed;
  final ServiceCalendarIndex? _calendar;

  factory StopTransitScheduleIndex.empty({
    bool failed = false,
    ServiceCalendarIndex? calendar,
  }) => StopTransitScheduleIndex._({}, failed, calendar);

  static StopTransitScheduleIndex? _cached;
  static Future<StopTransitScheduleIndex>? _loading;

  static Future<StopTransitScheduleIndex> load({
    ServiceCalendarIndex? calendar,
  }) {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _loadInternal(calendar: calendar).then((idx) {
      _cached = idx;
      return idx;
    });
  }

  static Future<StopTransitScheduleIndex> _loadInternal({
    ServiceCalendarIndex? calendar,
  }) async {
    try {
      final raw = await rootBundle.loadString(
        'assets/data/transit_times_by_stop.json',
      );
      final d = json.decode(raw) as Map<String, dynamic>;
      final stops = d['stops'];
      if (stops is! Map<String, dynamic>) {
        return StopTransitScheduleIndex.empty(failed: true, calendar: calendar);
      }

      final byStop = <String, Map<String, List<StopTransitScheduleEntry>>>{};
      for (final e in stops.entries) {
        final sid = e.key.trim();
        final routes = e.value;
        if (sid.isEmpty || routes is! Map<String, dynamic>) continue;
        final inner = <String, List<StopTransitScheduleEntry>>{};
        for (final r in routes.entries) {
          final rk = r.key.trim();
          final listDyn = r.value;
          if (rk.isEmpty || listDyn is! List) continue;
          final parsed = <StopTransitScheduleEntry>[];
          for (final item in listDyn) {
            if (item is! Map<String, dynamic>) continue;
            final dep = item['dep']?.toString().trim() ?? '';
            final dest = item['dest']?.toString().trim() ?? '';
            final svc = item['svc']?.toString().trim() ?? '';
            final pRaw = item['P']?.toString().trim() ?? '';
            final isP = pRaw == '1' || pRaw.toLowerCase() == 'true';
            final endRaw = item['end']?.toString().trim() ?? '';
            final isTripEnd =
                endRaw == '1' || endRaw.toLowerCase() == 'true';
            final trip = item['trip']?.toString().trim() ?? '';
            final seqRaw = item['seq'];
            final seq =
                seqRaw is int
                    ? seqRaw
                    : seqRaw is num
                    ? seqRaw.toInt()
                    : int.tryParse(seqRaw?.toString().trim() ?? '') ??
                        0;
            if (dep.isEmpty || dest.isEmpty) continue;
            parsed.add(
              StopTransitScheduleEntry(
                depRaw: dep,
                destination: dest,
                serviceId: svc,
                isPrenotazione: isP,
                tripId: trip,
                stopSequence: seq,
                isTripEndArrival: isTripEnd,
              ),
            );
          }
          if (parsed.isNotEmpty) inner[rk] = parsed;
        }
        if (inner.isNotEmpty) byStop[sid] = inner;
      }
      return StopTransitScheduleIndex._(byStop, false, calendar);
    } catch (e, st) {
      debugPrint('StopTransitScheduleIndex.load: $e\n$st');
      return StopTransitScheduleIndex.empty(failed: true, calendar: calendar);
    }
  }

  bool get isEmpty => _byStopId.isEmpty;

  Map<String, List<StopTransitScheduleEntry>>? routesAtStop(String rawStopId) {
    final k = rawStopId.trim();
    if (k.isEmpty) return null;
    return _byStopId[k];
  }

  /// Calendario servizi (filtro feriale/festivo), se caricato dall’asset.
  ServiceCalendarIndex? get serviceCalendarOrNull => _calendar;

  List<StopTransitScheduleEntry> entriesForKeys(
    String rawStopId,
    List<String> routeKeys, {
    DateTime? onLocalDay,
    bool applyServiceCalendarFilter = true,
  }) {
    final m = routesAtStop(rawStopId);
    if (m == null) return [];
    final cal = _calendar;
    final day = _localDateOnly(onLocalDay ?? DateTime.now());
    final useCal =
        applyServiceCalendarFilter &&
        cal != null &&
        cal.isUsable &&
        cal.calendarCoversLocalDay(day);

    final out = <StopTransitScheduleEntry>[];
    for (final rk in routeKeys) {
      final list = m[rk.trim()];
      if (list == null) continue;
      final pipe = rk.indexOf('|');
      final basinUpper =
          pipe > 0 ? rk.substring(0, pipe).trim().toUpperCase() : '';

      for (final e in list) {
        if (e.isTripEndArrival) continue;
        if (!useCal) {
          out.add(e);
          continue;
        }
        final sid = e.serviceId.trim();
        if (sid.isEmpty || basinUpper.isEmpty) {
          out.add(e);
          continue;
        }
        if (cal.serviceRunsOn(basinUpper, sid, day)) out.add(e);
      }
    }
    out.sort((a, b) {
      final sa = gtfsWallSeconds(a.depRaw) ?? 0;
      final sb = gtfsWallSeconds(b.depRaw) ?? 0;
      return sa.compareTo(sb);
    });
    return out;
  }

  bool stopHasExtraurbanLine({
    required String rawStopId,
    required Map<String, RomagnaLineaRow> lineeByComposite,
  }) {
    final routes = routesAtStop(rawStopId);
    if (routes == null) return false;

    for (final k in routes.keys) {
      if (lineeByComposite[k]?.area == kRomagnaExtraurbanAreaLabel) {
        return true;
      }
    }
    return false;
  }

  /// Cerca [tripId] su una qualsiasi fermata, limitato alle linee [routeKeys].
  ScheduleTripRef? findTripIdOnRoutes(String tripId, List<String> routeKeys) {
    final tid = tripId.trim();
    if (tid.isEmpty) return null;
    final wanted = routeKeys.map((k) => k.trim()).where((k) => k.isNotEmpty).toSet();
    if (wanted.isEmpty) return null;

    for (final routes in _byStopId.values) {
      for (final rk in wanted) {
        final list = routes[rk];
        if (list == null) continue;
        if (list.any((e) => e.tripId == tid)) {
          return ScheduleTripRef(routeKey: rk, tripId: tid);
        }
      }
    }
    return null;
  }

  /// Tutte le fermate del viaggio [tripId] sulla linea [routeComposite], ordinate per [TransitTripStopRow.seq].
  List<TransitTripStopRow> tripStopsForTrip(String routeComposite, String tripId) {
    final rk = routeComposite.trim();
    final tid = tripId.trim();
    if (rk.isEmpty || tid.isEmpty) return const [];

    final raw = <TransitTripStopRow>[];
    for (final sid in _byStopId.keys) {
      final routes = _byStopId[sid];
      if (routes == null) continue;
      final list = routes[rk];
      if (list == null) continue;
      for (final e in list) {
        if (e.tripId == tid) {
          raw.add(
            TransitTripStopRow(
              stopId: sid,
              depRaw: e.depRaw,
              seq: e.stopSequence,
              legDestination: e.destination,
            ),
          );
          break;
        }
      }
    }
    raw.sort((a, b) {
      if (a.seq != 0 || b.seq != 0) {
        return a.seq.compareTo(b.seq);
      }
      return (gtfsWallSeconds(a.depRaw) ?? 0).compareTo(
        gtfsWallSeconds(b.depRaw) ?? 0,
      );
    });
    return raw;
  }
}

/// Una riga del tabellone fermate lungo un singolo viaggio GTFS.
class TransitTripStopRow {
  const TransitTripStopRow({
    required this.stopId,
    required this.depRaw,
    required this.seq,
    this.legDestination = '',
  });

  final String stopId;
  final String depRaw;
  final int seq;

  /// Destinazione indicata alla fermata per questa partenza (verso capolinea).
  final String legDestination;
}

/// Bubbles fermata da grafo viaggi (`stop_id`); una bubble per route GTFS (`FC|1CO`, `FC|1-2CO`, …).
///
/// [requireServiceOnCalendarDay] — se `true` (default), una linea compare solo se ha almeno una corsa
/// nel giorno [calendarDay] secondo il calendario GTFS (comportamento della pagina «Partenze» per data).
/// Se `false`, include tutte le linee con orari in archivio per la fermata: serve al foglio mappa per
/// «prossime partenze» quando oggi non c’è servizio (es. linee solo feriali) ma le corse successive sono pianificate.
List<StopTransitLineBubble> buildStopTransitLineBubbles({
  required String rawStopId,
  required StopTransitScheduleIndex schedule,
  required Map<String, RomagnaLineaRow> lineeByComposite,
  DateTime? calendarDay,
  bool requireServiceOnCalendarDay = true,
}) {
  final sid = rawStopId.trim();
  if (sid.isEmpty || schedule.routesAtStop(sid) == null) return [];

  final day = _localDateOnly(calendarDay ?? DateTime.now());

  final at = schedule.routesAtStop(sid)!;
  final routeKeys = at.keys.toList();

  bool routeContributesBubble(String rk) {
    if (requireServiceOnCalendarDay) {
      return schedule.entriesForKeys(sid, [rk], onLocalDay: day).isNotEmpty;
    }
    final list = at[rk];
    return list != null && list.any((e) => !e.isTripEndArrival);
  }

  StopTransitLineBubble? bubbleForComposite(String composite) {
    final row = lineeByComposite[composite];
    if (row == null) return null;
    return bubbleFromLineRow(row, scheduleRouteKeys: [composite]);
  }

  final out = <StopTransitLineBubble>[];
  final seen = <String>{};

  for (final rk in routeKeys) {
    if (!routeContributesBubble(rk)) continue;
    final b = bubbleForComposite(rk);
    if (b != null && seen.add(bubbleDisplaySignature(b))) out.add(b);
  }

  out.sort(compareTransitLineBubbles);
  return out;
}

int compareTransitLineBubbles(
  StopTransitLineBubble a,
  StopTransitLineBubble b,
) {
  return compareTransitLineLabelsNumeric(a.lineaLabel, b.lineaLabel);
}

/// Ordine numerico sull’inizio dell’etichetta (1, 2, 6, 94…), poi lessicografico.
int compareTransitLineLabelsNumeric(String a, String b) {
  final ia = _leadingIntForSort(a);
  final ib = _leadingIntForSort(b);
  if (ia != ib) return ia.compareTo(ib);
  return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
}

int _leadingIntForSort(String linea) {
  final m = RegExp(r'^(\d+)').firstMatch(linea.trim());
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

/// Secondi dall’inizio della giornata servizio GTFS (ore possono essere ≥24).
int? gtfsWallSeconds(String depRaw) {
  final p = depRaw.trim().split(':');
  if (p.length != 3) return null;
  final h = int.tryParse(p[0].trim());
  final m = int.tryParse(p[1].trim());
  final s = int.tryParse(p[2].trim());
  if (h == null || m == null || s == null) return null;
  if (m < 0 || m > 59 || s < 0 || s > 59 || h < 0) return null;
  return h * 3600 + m * 60 + s;
}

String _compactTime(String depRaw) {
  final p = depRaw.trim().split(':');
  if (p.length < 2) return depRaw.trim();
  final hh = int.tryParse(p[0].trim());
  final mm = int.tryParse(p[1].trim()) ?? 0;
  if (hh == null) return depRaw.trim();
  final h24 = hh % 24;
  final m = mm.clamp(0, 59);
  return '${h24.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// HH:MM da un orario GTFS tipo `18:20:00` (modulo 24h).
String compactTransitDepClock(String depRaw) => _compactTime(depRaw);

/// Istante di partenza sulla «giornata servizio» locale [serviceMidnight] (ora 00:00 di quel giorno civile).
DateTime wallClockInstantOnCalendarDay({
  required String depRaw,
  required DateTime serviceMidnightLocal,
}) {
  final secTot = gtfsWallSeconds(depRaw);

  if (secTot == null) {
    final parts = depRaw.trim().split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return DateTime(
      serviceMidnightLocal.year,
      serviceMidnightLocal.month,
      serviceMidnightLocal.day,
      h % 24,
      m.clamp(0, 59),
    );
  }

  final extraDays = secTot ~/ 86400;
  final secInDay = secTot % 86400;
  final h = secInDay ~/ 3600;
  final m = (secInDay % 3600) ~/ 60;
  final s = secInDay % 60;

  return serviceMidnightLocal.add(
    Duration(days: extraDays, hours: h, minutes: m, seconds: s),
  );
}

/// Prossimo transito dopo [now] ignorando feriale/festivo (solo ripetizione giornaliera del profilo GTFS).
DateTime nextOccurrenceForGtfsWallClock({
  required String depRaw,
  required DateTime now,
}) {
  var anchor = DateTime(now.year, now.month, now.day);
  for (var i = 0; i < 400; i++) {
    final c = wallClockInstantOnCalendarDay(
      depRaw: depRaw,
      serviceMidnightLocal: anchor,
    );
    if (c.isAfter(now)) return c;
    anchor = anchor.add(const Duration(days: 1));
  }
  return anchor;
}

/// Prossima **corsa reale** rispetto al calendario GTFS giorno per giorno.
/// `null` se [service_id] non ha date note nel calendario o nessuna occorrenza entro l’orizzonte
/// (mai ripiegare su un orario «tutti i giorni»: genererebbe partenze fantasma, v. servizi con calendario non esteso).
DateTime? occurrenceAfterNowRespectingCalendar({
  required String depRaw,
  required StopTransitScheduleEntry entry,
  required StopTransitLineBubble bubble,
  required DateTime now,
  required ServiceCalendarIndex cal,
}) {
  final svc = entry.serviceId.trim();
  final basinGuess = basinUpperFromBubble(bubble);

  final today = _localDateOnly(now);

  final useCalendar = cal.isUsable && svc.isNotEmpty && basinGuess.isNotEmpty;

  if (!useCalendar) {
    return null;
  }

  DateTime? bestAfter;

  DateTime midnightForOffset(int offsetDays) {
    return DateTime(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: offsetDays));
  }

  /// Copre ~6 mesi: alcuni blocchi nei dati hanno discontinuità e servizi fermi alcune stagioni.
  const maxOffset = 190;

  for (var offset = 0; offset < maxOffset; offset++) {
    final dMid = midnightForOffset(offset);

    if (!cal.serviceRunsOn(basinGuess, svc, dMid)) continue;

    final instant = wallClockInstantOnCalendarDay(
      depRaw: depRaw,
      serviceMidnightLocal: dMid,
    );

    if (instant.isAfter(now)) {
      final prev = bestAfter;
      if (prev == null || instant.isBefore(prev)) bestAfter = instant;
    }
  }

  return bestAfter;
}

String basinUpperFromBubble(StopTransitLineBubble bubble) {
  final k =
      bubble.scheduleRouteKeys.isEmpty ? '' : bubble.scheduleRouteKeys.first;
  final pipe = k.indexOf('|');
  return pipe <= 0 ? '' : k.substring(0, pipe).trim().toUpperCase();
}

/// Differenza in giorni di calendario locali `[a.midnight … b.midnight]`.
int calendarDaysBetweenNormalized(DateTime a, DateTime b) {
  final da = DateTime(a.year, a.month, a.day);
  final db = DateTime(b.year, b.month, b.day);
  return db.difference(da).inDays;
}

String italianDayCue(DateTime reference, DateTime when) {
  final d = calendarDaysBetweenNormalized(reference, when);
  if (d <= 0) return '';
  if (d == 1) return 'Domani ';
  return 'Tra $d giorni ';
}

String italianWeekdayDateCaption(DateTime localDay) {
  const wd = [
    'lunedì',
    'martedì',
    'mercoledì',
    'giovedì',
    'venerdì',
    'sabato',
    'domenica',
  ];
  const mo = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];
  final d = DateTime(localDay.year, localDay.month, localDay.day);
  return '${wd[d.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
}

Map<String, List<StopTransitScheduleEntry>> groupEntriesByDestination(
  Iterable<StopTransitScheduleEntry> entries,
) {
  final byDest = <String, List<StopTransitScheduleEntry>>{};
  for (final e in entries) {
    byDest.putIfAbsent(e.destination, () => []).add(e);
  }
  for (final list in byDest.values) {
    list.sort(
      (a, b) => (gtfsWallSeconds(a.depRaw) ?? 0).compareTo(
        gtfsWallSeconds(b.depRaw) ?? 0,
      ),
    );
  }
  return byDest;
}

class UpcomingTransitDepartureUi {
  const UpcomingTransitDepartureUi({
    required this.lineLabel,
    required this.secondaryLabel,
    required this.towards,
    required this.clockLabel,
    required this.when,
    required this.dayPrefix,
    this.isPrenotazione = false,
  });

  final String lineLabel;
  final String secondaryLabel;
  final String towards;
  final String clockLabel;
  final DateTime when;
  final String dayPrefix;

  final bool isPrenotazione;
}

String _upcomingDedupeKey(StopTransitLineBubble b, DateTime when, String dest) {
  final slot = DateTime(
    when.year,
    when.month,
    when.day,
    when.hour,
    when.minute,
  );
  final sec = b.secondaryGrey ?? b.bacinoUpper;
  return '${b.lineaLabel}|$sec|${slot.millisecondsSinceEpoch}|${dest.trim()}';
}

List<UpcomingTransitDepartureUi> computeUpcomingDeparturesUi({
  required String rawStopId,
  required List<StopTransitLineBubble> bubbles,
  required StopTransitScheduleIndex schedule,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final cal = schedule.serviceCalendarOrNull;

  final scored =
      <
        ({
          DateTime when,
          StopTransitLineBubble bubble,
          String dest,
          StopTransitScheduleEntry entry,
        })
      >[];

  for (final b in bubbles) {
    final keys = b.scheduleRouteKeys;
    if (keys.isEmpty) continue;
    final basinGuess = basinUpperFromBubble(b);
    final entries = prepareEntriesForBubble(
      b,
      schedule.entriesForKeys(
        rawStopId,
        keys,
        applyServiceCalendarFilter: false,
      ),
    );
    for (final e in entries) {
      final sid = e.serviceId.trim();

      DateTime whenCal;

      final useCal =
          cal != null &&
          cal.isUsable &&
          basinGuess.isNotEmpty &&
          sid.isNotEmpty;

      if (useCal) {
        final occ = occurrenceAfterNowRespectingCalendar(
          depRaw: e.depRaw,
          entry: e,
          bubble: b,
          now: t,
          cal: cal,
        );

        // Servizio non pianificato nel calendario (date mancanti oltre l’orizzonte) → non inventare partenze.
        if (occ == null) {
          continue;
        }
        whenCal = occ;
      } else {
        whenCal = nextOccurrenceForGtfsWallClock(depRaw: e.depRaw, now: t);
      }

      scored.add((when: whenCal, bubble: b, dest: e.destination, entry: e));
    }
  }

  scored.sort((a, b) => a.when.compareTo(b.when));

  final seenRows = <String>{};
  final deduped =
      <
        ({
          DateTime when,
          StopTransitLineBubble bubble,
          String dest,
          StopTransitScheduleEntry entry,
        })
      >[];
  for (final s in scored) {
    final k = _upcomingDedupeKey(s.bubble, s.when, s.dest);
    if (seenRows.add(k)) {
      deduped.add((
        when: s.when,
        bubble: s.bubble,
        dest: s.dest,
        entry: s.entry,
      ));
    }
  }

  // Una prossima partenza per ogni linea (bubble), non solo le 3 corse più vicine
  // in assoluto: altrimenti linee come 1/2 CO spariscono se altre partono prima.
  final seenLine = <String>{};
  final out = <UpcomingTransitDepartureUi>[];
  for (final s in deduped) {
    final lineKey =
        '${s.bubble.lineaLabel}|${s.bubble.secondaryGrey ?? s.bubble.bacinoUpper}';
    if (!seenLine.add(lineKey)) continue;
    out.add(
      UpcomingTransitDepartureUi(
        lineLabel: s.bubble.lineaLabel,
        secondaryLabel: s.bubble.secondaryGrey ?? s.bubble.bacinoUpper,
        towards: s.dest,
        clockLabel:
            '${s.when.hour.toString().padLeft(2, '0')}:${s.when.minute.toString().padLeft(2, '0')}',
        when: s.when,
        dayPrefix: italianDayCue(t, s.when),
        isPrenotazione: s.entry.isPrenotazione,
      ),
    );
  }

  return out;
}

/// True se il filtro feriale/festivo del calendario è effettivamente applicabile
/// per [localDay] (calendario caricato e data coperta dai dati).
bool serviceCalendarFiltersLocalDay(
  StopTransitScheduleIndex schedule,
  DateTime localDay,
) {
  final cal = schedule.serviceCalendarOrNull;
  final d = DateTime(localDay.year, localDay.month, localDay.day);
  return cal != null && cal.isUsable && cal.calendarCoversLocalDay(d);
}

/// Tutte le partenze programmate alla fermata nel giorno civile [onLocalDay],
/// ordinate per orario, con deduplica come in [computeUpcomingDeparturesUi].
/// Usa [entriesForKeys] con calendario servizi quando coperto.
List<UpcomingTransitDepartureUi> computeDeparturesForStopOnLocalDay({
  required String rawStopId,
  required List<StopTransitLineBubble> bubbles,
  required StopTransitScheduleIndex schedule,
  required DateTime onLocalDay,
}) {
  final sid = rawStopId.trim();
  if (sid.isEmpty) return [];

  final day = DateTime(onLocalDay.year, onLocalDay.month, onLocalDay.day);
  final serviceMidnight = day;

  final scored =
      <
        ({
          DateTime when,
          StopTransitLineBubble bubble,
          String dest,
          StopTransitScheduleEntry entry,
        })
      >[];

  for (final b in bubbles) {
    final keys = b.scheduleRouteKeys;
    if (keys.isEmpty) continue;
    final entries = prepareEntriesForBubble(
      b,
      schedule.entriesForKeys(
        sid,
        keys,
        onLocalDay: day,
        applyServiceCalendarFilter: true,
      ),
    );
    for (final e in entries) {
      final when = wallClockInstantOnCalendarDay(
        depRaw: e.depRaw,
        serviceMidnightLocal: serviceMidnight,
      );
      scored.add((when: when, bubble: b, dest: e.destination, entry: e));
    }
  }

  scored.sort((a, b) => a.when.compareTo(b.when));

  final seenRows = <String>{};
  final out = <UpcomingTransitDepartureUi>[];
  for (final s in scored) {
    final k = _upcomingDedupeKey(s.bubble, s.when, s.dest);
    if (!seenRows.add(k)) continue;
    out.add(
      UpcomingTransitDepartureUi(
        lineLabel: s.bubble.lineaLabel,
        secondaryLabel: s.bubble.secondaryGrey ?? s.bubble.bacinoUpper,
        towards: s.dest,
        clockLabel:
            '${s.when.hour.toString().padLeft(2, '0')}:${s.when.minute.toString().padLeft(2, '0')}',
        when: s.when,
        dayPrefix: '',
        isPrenotazione: s.entry.isPrenotazione,
      ),
    );
  }
  return out;
}

void showTransitLineDeparturesSheet(
  BuildContext context, {
  required String stopNameUi,
  String? stopIdUi,
  required StopTransitLineBubble bubble,
  RomagnaLineaRow? lineInfoRow,
  required List<StopTransitScheduleEntry> entriesToday,
  required List<StopTransitScheduleEntry> entriesAllProfiles,
  ServiceCalendarIndex? calendar,
}) {
  if (!context.mounted) return;

  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      builder:
          (_) => TransitLineAtStopPage(
            stopNameUi: stopNameUi,
            stopIdUi: stopIdUi,
            bubble: bubble,
            lineInfoRow: lineInfoRow,
            entriesToday: entriesToday,
            entriesAllProfiles: entriesAllProfiles,
            calendar: calendar,
          ),
    ),
  );
}

/// Accento per fascia oraria in «Pianificazione» (euristica sui giorni coperti da [service_id]).
MaterialColor _profileAccent(TransitServiceProfile p) => switch (p) {
  TransitServiceProfile.mostlyWeekday => Colors.indigo,
  TransitServiceProfile.mostlyWeekend => Colors.deepOrange,
  TransitServiceProfile.dailyOrMixed => Colors.blueGrey,
};

/// Colore testo orario sulle chip (contrasto sul fondo chiaro della bubble).
Color transitChipTimeTextColor(Color base) =>
    Color.lerp(base, kRomagnaDarkGray, 0.35) ?? base;

/// Bubble orario con eventuale «P» integrata (stesso bordo/sfondo).
class TransitScheduleTimeChip extends StatelessWidget {
  const TransitScheduleTimeChip({
    super.key,
    required this.timeLabel,
    required this.tint,
    required this.timeTextColor,
    this.isPrenotazione = false,
    this.realtimeSuffix,
    this.realtimeSuffixBackground,
    this.realtimeSuffixForeground,
    this.timeFontSize = 13,
    this.horizontalPadding = 10,
    this.verticalPadding = 5,
    this.onTripTimetableTap,
  });

  final String timeLabel;
  final Color tint;
  final Color timeTextColor;
  final bool isPrenotazione;

  /// Es. `+4`, `-6` (ritardo / anticipo in minuti) oppure `>` (in arrivo), mostrato in pill nella bubble.
  final String? realtimeSuffix;

  /// Sfondo pill RT; se null con [realtimeSuffix] non vuoto usa grigio neutro.
  final Color? realtimeSuffixBackground;

  /// Colore testo sulla pill RT (es. bianco su rosso, scuro su giallo/tema).
  final Color? realtimeSuffixForeground;
  final double timeFontSize;
  final double horizontalPadding;
  final double verticalPadding;

  /// Tap sulla chip: apre tabellone corsa (es. da calendario partenze). Con «P»: tap = tabellone, long press = info prenotazione.
  final VoidCallback? onTripTimetableTap;

  static const Color _pGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final pSize = (timeFontSize * 1.35).clamp(17.0, 20.0);
    final pFont = (timeFontSize * 0.82).clamp(10.0, 12.0);
    final rt = realtimeSuffix?.trim() ?? '';
    final rtBg =
        realtimeSuffixBackground ??
        (rt.isNotEmpty ? kRomagnaDarkGray.withValues(alpha: 0.45) : null);

    final chipRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeLabel,
          style: GoogleFonts.inter(
            fontSize: timeFontSize,
            fontWeight: FontWeight.w700,
            height: 1.25,
            color: timeTextColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (rt.isNotEmpty && rtBg != null) ...[
          SizedBox(width: (timeFontSize * 0.45).clamp(5.0, 7.0)),
          DecoratedBox(
            decoration: BoxDecoration(
              color: rtBg,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (timeFontSize * 0.38).clamp(5.0, 7.0),
                vertical: 1.5,
              ),
              child: Text(
                rt,
                style: GoogleFonts.inter(
                  fontSize: (timeFontSize * 0.72).clamp(9.5, 11.5),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: realtimeSuffixForeground ?? Colors.white,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
        if (isPrenotazione) ...[
          SizedBox(width: (timeFontSize * 0.55).clamp(6.0, 8.0)),
          Container(
            width: pSize,
            height: pSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _pGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'P',
              style: GoogleFonts.inter(
                fontSize: pFont,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: chipRow,
    );

    if (!isPrenotazione) {
      final box = DecoratedBox(
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tint.withValues(alpha: 0.28)),
        ),
        child: padded,
      );
      if (onTripTimetableTap != null) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTripTimetableTap,
            child: box,
          ),
        );
      }
      return box;
    }

    if (onTripTimetableTap != null) {
      return Semantics(
        button: true,
        label: 'Corsa su prenotazione, orario $timeLabel. Tieni premuto per informazioni.',
        child: Material(
          color: tint.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTripTimetableTap,
            onLongPress: () => _showCorsaSuPrenotazioneInfoDialog(context),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tint.withValues(alpha: 0.28)),
              ),
              child: padded,
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Corsa su prenotazione, orario $timeLabel',
      child: Material(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _showCorsaSuPrenotazioneInfoDialog(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tint.withValues(alpha: 0.28)),
            ),
            child: padded,
          ),
        ),
      ),
    );
  }
}

String _profilePlanningTitle(TransitServiceProfile p) => switch (p) {
  TransitServiceProfile.mostlyWeekday => 'Giorni feriali',
  TransitServiceProfile.mostlyWeekend => 'Giorni festivi',
  TransitServiceProfile.dailyOrMixed => 'Tutti i giorni (feriali e festivi)',
};

Widget _destinationTimeWrap({
  required String dest,
  required List<StopTransitScheduleEntry> times,
  required Color tint,
  required Color timeTextColor,
  bool tightTopAfterSectionHeader = false,
}) {
  final destPad =
      tightTopAfterSectionHeader
          ? const EdgeInsets.fromLTRB(12, 5, 12, 5)
          : const EdgeInsets.fromLTRB(12, 10, 12, 6);
  final chipsPad = const EdgeInsets.fromLTRB(12, 0, 12, 10);
  final destTrim = dest.trim();
  final destStyle = GoogleFonts.inter(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: kRomagnaDarkGray.withValues(alpha: 0.5),
    letterSpacing: 0.15,
  );
  final arrowColor = kRomagnaDarkGray.withValues(alpha: 0.5);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: destPad,
        child:
            destTrim.isEmpty
                ? Text(dest, style: destStyle)
                : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 15,
                        color: arrowColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(destTrim, style: destStyle),
                    ),
                  ],
                ),
      ),
      Padding(
        padding: chipsPad,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in times)
              TransitScheduleTimeChip(
                timeLabel: _compactTime(e.depRaw),
                tint: tint,
                timeTextColor: timeTextColor,
                isPrenotazione: e.isPrenotazione,
              ),
          ],
        ),
      ),
    ],
  );
}

/// Pagina dedicata: orari della linea dalla fermata corrente (oggi / pianificazione).
class TransitLineAtStopPage extends StatefulWidget {
  const TransitLineAtStopPage({
    super.key,
    required this.stopNameUi,
    this.stopIdUi,
    required this.bubble,
    required this.lineInfoRow,
    required this.entriesToday,
    required this.entriesAllProfiles,
    this.calendar,
  });

  final String stopNameUi;

  /// Codice TPL (es. `10722`), mostrato in azzurro accanto al nome fermata.
  final String? stopIdUi;
  final StopTransitLineBubble bubble;
  final RomagnaLineaRow? lineInfoRow;
  final List<StopTransitScheduleEntry> entriesToday;
  final List<StopTransitScheduleEntry> entriesAllProfiles;
  final ServiceCalendarIndex? calendar;

  @override
  State<TransitLineAtStopPage> createState() => _TransitLineAtStopPageState();
}

class _TransitLineAtStopPageState extends State<TransitLineAtStopPage> {
  var _segment = <int>{0};
  bool _infoBusHasAvvisi = false;
  bool _infoBusChecked = false;
  Future<void>? _infoBusResolveFuture;

  @override
  void initState() {
    super.initState();
    unawaited(_ensureInfoBusPostIdResolved());
  }

  Future<void> _ensureInfoBusPostIdResolved() async {
    if (_infoBusChecked) return;

    final row = widget.lineInfoRow;
    if (row == null) {
      if (!mounted) return;
      setState(() => _infoBusChecked = true);
      return;
    }

    _infoBusResolveFuture ??= () async {
      final has = await infoBusHasAvvisiForLine(
        routeId: row.routeId,
        lineLabel: row.linea,
        basin: row.bacino,
      );
      if (!mounted) return;
      setState(() {
        _infoBusHasAvvisi = has;
        _infoBusChecked = true;
      });
    }();

    await _infoBusResolveFuture;
  }

  Future<void> _openInfoBusPost() async {
    final row = widget.lineInfoRow;
    if (row == null) return;

    if (!_infoBusChecked) return;

    if (!_infoBusHasAvvisi) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => InfoBusLineaPage(
              lineLabel: row.linea,
              areaLabel: row.area,
              basin: row.bacino,
              routeId: row.routeId,
            ),
      ),
    );
  }

  Future<void> _openLineRoute() async {
    final row = widget.lineInfoRow;
    if (row == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => DirezioniLineaPage(riga: row)),
    );
  }

  Iterable<Widget> _buildGroupedDestinations({
    required List<StopTransitScheduleEntry> canon,
    required Color tint,
    required Color timeTextColor,
    bool compactSectionGaps = false,
  }) sync* {
    if (canon.isEmpty) {
      yield Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Orari non disponibili.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: kRomagnaDarkGray.withValues(alpha: 0.42),
          ),
        ),
      );
      return;
    }
    final byDest = groupEntriesByDestination(canon);
    final destinations = byDest.keys.toList()..sort();
    for (var i = 0; i < destinations.length; i++) {
      final dest = destinations[i];
      yield _destinationTimeWrap(
        dest: dest,
        times: byDest[dest]!,
        tint: tint,
        timeTextColor: timeTextColor,
        tightTopAfterSectionHeader: compactSectionGaps && i == 0,
      );
    }
  }

  Iterable<Widget> _buildPlanningGrouped() sync* {
    final cal = widget.calendar;
    final basin = basinUpperFromBubble(widget.bubble);
    final refDay = DateTime.now();
    final rawCanon = prepareEntriesForBubble(
      widget.bubble,
      widget.entriesAllProfiles,
    );
    final mergedByK = <String, StopTransitScheduleEntry>{};
    for (final e in rawCanon) {
      final k =
          '${e.depRaw.trim()}|${e.destination.trim()}|${e.serviceId.trim()}';
      final prev = mergedByK[k];
      if (prev == null) {
        mergedByK[k] = e;
      } else if (!prev.isPrenotazione && e.isPrenotazione) {
        mergedByK[k] = StopTransitScheduleEntry(
          depRaw: prev.depRaw,
          destination: prev.destination,
          serviceId: prev.serviceId,
          isPrenotazione: true,
          tripId: prev.tripId.isNotEmpty ? prev.tripId : e.tripId,
          stopSequence: prev.stopSequence != 0 ? prev.stopSequence : e.stopSequence,
          isTripEndArrival: prev.isTripEndArrival || e.isTripEndArrival,
        );
      }
    }
    final allCanon =
        mergedByK.values.toList()..sort(
          (a, b) => (gtfsWallSeconds(a.depRaw) ?? 0).compareTo(
            gtfsWallSeconds(b.depRaw) ?? 0,
          ),
        );
    final byProf = <TransitServiceProfile, List<StopTransitScheduleEntry>>{};
    const order = TransitServiceProfile.values;
    for (final e in allCanon) {
      final guess =
          (cal != null && cal.isUsable)
              ? cal.guessServiceProfile(basin, e.serviceId, refDay)
              : TransitServiceProfile.dailyOrMixed;
      byProf.putIfAbsent(guess, () => []).add(e);
    }

    if (allCanon.isEmpty) {
      yield Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Orari non disponibili.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: kRomagnaDarkGray.withValues(alpha: 0.42),
          ),
        ),
      );
      return;
    }

    final hasPrenotazione = allCanon.any((e) => e.isPrenotazione);
    if (hasPrenotazione) {
      yield Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Le corse con «P» sono su prenotazione.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: kRomagnaDarkGray.withValues(alpha: 0.42),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _openStartRomagnaCorsePrenotazione(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Prenota qui',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: kRomagnaPrimary,
                        decoration: TextDecoration.underline,
                        decorationColor: kRomagnaPrimary,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: kRomagnaPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    for (final prof in order) {
      final list = byProf[prof];
      if (list == null || list.isEmpty) continue;
      final accent = _profileAccent(prof);
      yield Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent.shade400, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Text(
                    _profilePlanningTitle(prof),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: accent.shade800,
                    ),
                  ),
                ),
                ..._buildGroupedDestinations(
                  canon: list,
                  tint: accent.shade400,
                  timeTextColor: accent.shade800,
                  compactSectionGaps: true,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lineSecondary =
        widget.bubble.secondaryGrey ?? widget.bubble.bacinoUpper;
    final todayCanon = prepareEntriesForBubble(
      widget.bubble,
      widget.entriesToday,
    );
    final todayCap = italianWeekdayDateCaption(DateTime.now());
    final modeOggi = _segment.contains(0);

    final rowForInfoBus = widget.lineInfoRow;
    final infoBusLoading = rowForInfoBus != null && !_infoBusChecked;
    final infoBusHasAvvisi = _infoBusHasAvvisi;
    final infoBusOpen =
        rowForInfoBus != null && _infoBusChecked && infoBusHasAvvisi;
    final infoBusLabel =
        _infoBusChecked && !infoBusHasAvvisi
            ? 'Nessun avviso per questa linea'
            : 'Avvisi per questa linea';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Linea ${widget.bubble.lineaLabel}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaDarkGray.withValues(alpha: 0.45),
                    ),
                    children: [
                      TextSpan(text: widget.stopNameUi),
                      if ((widget.stopIdUi ?? '').trim().isNotEmpty)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: Text(
                            '   ${widget.stopIdUi!.trim()}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: kRomagnaPrimary,
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Linea ${widget.bubble.lineaLabel} $lineSecondary — transiti da questa fermata',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: kRomagnaDarkGray,
                  ),
                ),
              ),
              if (widget.lineInfoRow != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: infoBusOpen ? _openInfoBusPost : null,
                        icon: Icon(
                          infoBusHasAvvisi || infoBusLoading
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          infoBusLabel,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          foregroundColor: infoBusHasAvvisi
                              ? Colors.orange.shade900
                              : kRomagnaDarkGray.withValues(
                                  alpha: infoBusLoading ? 0.4 : 0.55,
                                ),
                          backgroundColor: infoBusHasAvvisi
                              ? Colors.orange.shade100
                              : Color.lerp(
                                      Colors.grey.shade100,
                                      Colors.white,
                                      infoBusLoading ? 0.35 : 0.15,
                                    ) ??
                                  Colors.grey.shade100,
                          disabledForegroundColor: infoBusHasAvvisi
                              ? Colors.orange.shade900.withValues(alpha: 0.45)
                              : kRomagnaDarkGray.withValues(
                                  alpha: infoBusLoading ? 0.4 : 0.45,
                                ),
                          disabledBackgroundColor: infoBusHasAvvisi
                              ? Colors.orange.shade100.withValues(alpha: 0.35)
                              : Color.lerp(
                                      Colors.grey.shade100,
                                      Colors.white,
                                      infoBusLoading ? 0.35 : 0.15,
                                    ) ??
                                  Colors.grey.shade100,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _openLineRoute,
                        icon: const Icon(Icons.route_rounded, size: 18),
                        label: Text(
                          'Vedi percorso',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        style: FilledButton.styleFrom(
                          foregroundColor: kRomagnaPrimary,
                          backgroundColor: kRomagnaPrimary.withValues(
                            alpha: 0.14,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(value: 0, label: Text('Oggi')),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Tutti gli orari'),
                    ),
                  ],
                  selected: _segment,
                  onSelectionChanged: (s) => setState(() => _segment = s),
                ),
              ),
              if (modeOggi)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    'Orari per servizio in vigore oggi ($todayCap)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: kRomagnaPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              if (modeOggi)
                ..._buildGroupedDestinations(
                  canon: todayCanon,
                  tint: kRomagnaPrimary,
                  timeTextColor: transitChipTimeTextColor(kRomagnaPrimary),
                )
              else
                ..._buildPlanningGrouped(),
            ],
          ),
        ),
      ),
    );
  }
}

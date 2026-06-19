// Elenco completo partenze da una fermata (oggi / domani / tra 2 giorni), con calendario feriale–festivo.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'linee_percorsi.dart';
import 'romagna_brand.dart';
import 'infobus_realtime.dart';
import 'transiti_at_stop.dart';
import 'transit_trip_open.dart';
import 'stop_transit_schedule.dart';

/// Schermata a tutta pagina: partenze dalla fermata per un giorno a scelta (max +2 giorni).
class StopAllDeparturesPage extends StatefulWidget {
  const StopAllDeparturesPage({
    super.key,
    required this.rawStopId,
    required this.stopNameUi,
    this.basinLower,
    required this.lineeByComposite,
    required this.schedule,
  });

  final String rawStopId;
  final String stopNameUi;

  /// Bacino Start (`fc`/`ra`/`rn`) per InfoBus; se assente si prova a dedurlo dalle linee.
  final String? basinLower;
  final Map<String, RomagnaLineaRow> lineeByComposite;
  final StopTransitScheduleIndex schedule;

  @override
  State<StopAllDeparturesPage> createState() => _StopAllDeparturesPageState();
}

class _StopAllDeparturesPageState extends State<StopAllDeparturesPage> {
  int _dayOffset = 0;
  bool _groupByLine = false;
  Timer? _infobusTimer;
  List<InfobusArrivalCard> _infobusSite = const [];
  bool _infobusLoading = false;
  String? _infobusPollKey;

  @override
  void dispose() {
    _infobusTimer?.cancel();
    super.dispose();
  }

  DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _selectedLocalDay() =>
      _todayMidnight().add(Duration(days: _dayOffset));

  String? _resolvedBasinLower(List<StopTransitLineBubble> bubbles) {
    final fromProp = widget.basinLower?.trim().toLowerCase() ?? '';
    if (fromProp == 'fc' || fromProp == 'ra' || fromProp == 'rn') {
      return fromProp;
    }
    if (bubbles.isEmpty) return null;
    final k = bubbles.first.scheduleRouteKeys;
    if (k.isEmpty) return null;
    final pipe = k.first.indexOf('|');
    if (pipe <= 0) return null;
    return k.first.substring(0, pipe).trim().toLowerCase();
  }

  Future<void> _refreshInfobusFetch(String basin) async {
    if (!mounted) return;
    setState(() => _infobusLoading = true);
    final list = await infobusFetchArrivalsForStop(
      basinLower: basin,
      palina: widget.rawStopId.trim(),
    );
    if (!mounted) return;
    setState(() {
      _infobusLoading = false;
      if (list != null) _infobusSite = list;
    });
  }

  void _setupInfobusIfNeeded(String? basin) {
    if (basin == null || _dayOffset != 0) {
      _infobusTimer?.cancel();
      _infobusTimer = null;
      _infobusPollKey = null;
      return;
    }
    final key = '$basin|${widget.rawStopId}';
    if (_infobusPollKey == key && _infobusTimer != null) return;
    _infobusPollKey = key;
    _infobusTimer?.cancel();
    unawaited(_refreshInfobusFetch(basin));
    _infobusTimer = Timer.periodic(kInfobusPollInterval, (_) {
      if (!mounted || _dayOffset != 0) return;
      unawaited(_refreshInfobusFetch(basin));
    });
  }

  Widget _infobusSiteTimeChip(InfobusArrivalCard c, {VoidCallback? onTap}) {
    final rt = infobusChipRtForCard(c);
    final tint = infobusProssimePartenzeBubbleTint(c);
    return TransitScheduleTimeChip(
      timeLabel: c.scheduledHm,
      tint: tint,
      timeTextColor: transitChipTimeTextColor(tint),
      realtimeSuffix: rt?.suffix,
      realtimeSuffixBackground: rt?.background,
      realtimeSuffixForeground: rt?.foreground,
      timeFontSize: 13.5,
      verticalPadding: 6,
      onTripTimetableTap: onTap,
    );
  }

  StopTransitLineBubble? _bubbleForInfobusCard(
    InfobusArrivalCard card,
    List<StopTransitLineBubble> bubbles,
  ) {
    for (final b in bubbles) {
      if (b.scheduleRouteKeys.isEmpty) continue;
      if (infobusSiteLineMatchesBubbleLine(card.lineLabel, b.lineaLabel)) {
        return b;
      }
    }
    return null;
  }

  StopTransitLineBubble? _bubbleForCalendarRow(
    UpcomingTransitDepartureUi u,
    List<StopTransitLineBubble> bubbles,
  ) {
    for (final b in bubbles) {
      if (b.scheduleRouteKeys.isEmpty) continue;
      if (infobusSiteLineMatchesBubbleLine(u.lineLabel, b.lineaLabel)) {
        return b;
      }
    }
    return null;
  }

  void _openTransitLinePageForBubble(
    BuildContext context,
    StopTransitLineBubble matched,
  ) {
    final sid = widget.rawStopId.trim();
    RomagnaLineaRow? lineInfoRow;
    for (final composite in matched.scheduleRouteKeys) {
      final row = widget.lineeByComposite[composite];
      if (row != null) {
        lineInfoRow = row;
        break;
      }
    }
    final entriesToday = widget.schedule.entriesForKeys(
      sid,
      matched.scheduleRouteKeys,
      onLocalDay: DateTime.now(),
    );
    final entriesAll = widget.schedule.entriesForKeys(
      sid,
      matched.scheduleRouteKeys,
      applyServiceCalendarFilter: false,
    );
    showTransitLineDeparturesSheet(
      context,
      stopNameUi: widget.stopNameUi,
      stopIdUi: sid,
      bubble: matched,
      lineInfoRow: lineInfoRow,
      entriesToday: entriesToday,
      entriesAllProfiles: entriesAll,
      calendar: widget.schedule.serviceCalendarOrNull,
    );
  }

  Future<void> _openTripTimetableFromInfobusChip(
    BuildContext context,
    InfobusArrivalCard card,
    List<StopTransitLineBubble> bubbles,
  ) async {
    final matched = _bubbleForInfobusCard(card, bubbles);
    if (matched == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'La linea mostrata dal sito non corrisponde a nessuna linea con orari '
            'in app per questa fermata (etichette diverse: es. CE01 vs 1, S094 vs 94).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final serviceDay = _todayMidnight();
    await openTransitTripTimetable(
      context: context,
      schedule: widget.schedule,
      rawStopId: widget.rawStopId.trim(),
      stopNameUi: widget.stopNameUi,
      bubble: matched,
      onLocalDay: serviceDay,
      scheduledHmForMatch: card.scheduledHm,
      scheduledHmForDisplay: card.scheduledHm,
      towardsDestination: card.destination,
      lineLabelForTitle: infobusSiteLineLabelForUi(card.lineLabel, bubbles),
      infobusRtCard: card,
      onFallback:
          () => _openTransitLinePageForBubble(context, matched),
    );
  }

  Future<void> _openTripTimetableFromCalendarRow(
    BuildContext context,
    UpcomingTransitDepartureUi u,
    InfobusArrivalCard? rtMatch,
    List<StopTransitLineBubble> bubbles,
    DateTime onLocalDay,
  ) async {
    final matched = _bubbleForCalendarRow(u, bubbles);
    if (matched == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            'La linea mostrata dal sito non corrisponde a nessuna linea con orari '
            'in app per questa fermata (etichette diverse: es. CE01 vs 1, S094 vs 94).',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final hm =
        '${u.when.hour.toString().padLeft(2, '0')}:${u.when.minute.toString().padLeft(2, '0')}';
    final display =
        u.dayPrefix.isEmpty ? u.clockLabel : '${u.dayPrefix}${u.clockLabel}';

    await openTransitTripTimetable(
      context: context,
      schedule: widget.schedule,
      rawStopId: widget.rawStopId.trim(),
      stopNameUi: widget.stopNameUi,
      bubble: matched,
      onLocalDay: onLocalDay,
      scheduledHmForMatch: hm,
      scheduledHmForDisplay: display,
      towardsDestination: u.towards,
      lineLabelForTitle: u.lineLabel,
      infobusRtCard: rtMatch,
      onFallback:
          () => _openTransitLinePageForBubble(context, matched),
    );
  }

  Widget _calendarRowTimeChip(
    UpcomingTransitDepartureUi u,
    InfobusArrivalCard? m, {
    VoidCallback? onTripTimetableTap,
  }) {
    final rt = m != null ? infobusChipRtForCard(m) : null;
    final tint =
        m == null ? kRomagnaPrimary : infobusProssimePartenzeBubbleTint(m);
    return TransitScheduleTimeChip(
      timeLabel:
          u.dayPrefix.isEmpty ? u.clockLabel : '${u.dayPrefix}${u.clockLabel}',
      tint: tint,
      timeTextColor: transitChipTimeTextColor(tint),
      isPrenotazione: u.isPrenotazione,
      realtimeSuffix: rt?.suffix,
      realtimeSuffixBackground: rt?.background,
      realtimeSuffixForeground: rt?.foreground,
      timeFontSize: 13.5,
      verticalPadding: 6,
      onTripTimetableTap: onTripTimetableTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedLocalDay();
    final bubbles = buildStopTransitLineBubbles(
      rawStopId: widget.rawStopId,
      schedule: widget.schedule,
      lineeByComposite: widget.lineeByComposite,
      calendarDay: selectedDay,
    );
    final rows = computeDeparturesForStopOnLocalDay(
      rawStopId: widget.rawStopId,
      bubbles: bubbles,
      schedule: widget.schedule,
      onLocalDay: selectedDay,
    );
    final calendarOn = serviceCalendarFiltersLocalDay(
      widget.schedule,
      selectedDay,
    );

    final displayRows =
        _groupByLine
            ? (List<UpcomingTransitDepartureUi>.from(rows)..sort((a, b) {
              final lineCmp = compareTransitLineLabelsNumeric(
                a.lineLabel,
                b.lineLabel,
              );
              if (lineCmp != 0) return lineCmp;
              final secCmp = a.secondaryLabel.toLowerCase().compareTo(
                b.secondaryLabel.toLowerCase(),
              );
              if (secCmp != 0) return secCmp;
              return a.when.compareTo(b.when);
            }))
            : rows;

    final infobusBasin = _resolvedBasinLower(bubbles);
    _setupInfobusIfNeeded(infobusBasin);

    final departuresRtMatch =
        _dayOffset == 0
            ? matchInfobusToDepartures(rows: displayRows, site: _infobusSite)
            : <int, InfobusArrivalCard>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Partenze',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            widget.stopNameUi,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: kRomagnaDarkGray,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fermata ${widget.rawStopId}',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: kRomagnaDarkGray.withValues(alpha: 0.45),
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Giorno',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: kRomagnaDarkGray.withValues(alpha: 0.48),
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _DayChoicePill(
                    selected: _dayOffset == i,
                    label: switch (i) {
                      0 => 'Oggi',
                      1 => 'Domani',
                      _ => 'Tra 2 giorni',
                    },
                    onTap: () => setState(() => _dayOffset = i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            italianWeekdayDateCaption(selectedDay),
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: kRomagnaPrimary.withValues(alpha: 0.92),
            ),
          ),
          if (!calendarOn) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: kRomagnaPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kRomagnaPrimary.withValues(alpha: 0.22),
                ),
              ),
              child: Text(
                'Per questa data il calendario feriale/festivo non è coperto dai dati in app: '
                'l’elenco può mostrare più varianti di servizio insieme. Controlla gli avvisi ufficiali.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: kRomagnaDarkGray.withValues(alpha: 0.72),
                ),
              ),
            ),
          ],
          if (_dayOffset == 0 && infobusBasin != null) ...[
            if (_infobusLoading && _infobusSite.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  borderRadius: BorderRadius.circular(2),
                  color: kRomagnaPrimary.withValues(alpha: 0.65),
                  backgroundColor: kRomagnaPrimary.withValues(alpha: 0.1),
                ),
              ),
            if (_infobusSite.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Prossime linee in partenza',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray.withValues(alpha: 0.48),
                  letterSpacing: 0.25,
                ),
              ),
              const SizedBox(height: 12),
              for (final c in _infobusSite)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          infobusSiteLineLabelForUi(c.lineLabel, bubbles),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.4,
                            color: kRomagnaDarkGray,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Text(
                          c.destination,
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: kRomagnaDarkGray.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _infobusSiteTimeChip(
                        c,
                        onTap:
                            () => unawaited(
                              _openTripTimetableFromInfobusChip(
                                context,
                                c,
                                bubbles,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: kRomagnaDarkGray.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 14),
              Text(
                'Orari programmati (da calendario)',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray.withValues(alpha: 0.48),
                  letterSpacing: 0.25,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
          SizedBox(
            height:
                _dayOffset == 0 &&
                    infobusBasin != null &&
                    _infobusSite.isNotEmpty
                ? 10
                : 22,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Orari',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: kRomagnaDarkGray.withValues(alpha: 0.48),
                  letterSpacing: 0.25,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => _groupByLine = !_groupByLine),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _groupByLine
                              ? kRomagnaPrimary.withValues(alpha: 0.14)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            _groupByLine
                                ? kRomagnaPrimary.withValues(alpha: 0.42)
                                : kRomagnaDarkGray.withValues(alpha: 0.14),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Raggruppa per linea',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color:
                            _groupByLine
                                ? kRomagnaDarkGray
                                : kRomagnaDarkGray.withValues(alpha: 0.52),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (displayRows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                'Nessuna corsa prevista oggi.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.45,
                  color: kRomagnaDarkGray.withValues(alpha: 0.42),
                ),
              ),
            )
          else ...[
            for (var i = 0; i < displayRows.length; i++) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 2,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.4,
                            color: kRomagnaDarkGray,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(text: displayRows[i].lineLabel),
                            TextSpan(
                              text: ' ${displayRows[i].secondaryLabel}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: kRomagnaDarkGray.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text(
                        displayRows[i].towards,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: kRomagnaDarkGray.withValues(alpha: 0.82),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _calendarRowTimeChip(
                      displayRows[i],
                      departuresRtMatch[i],
                      onTripTimetableTap:
                          () => unawaited(
                            _openTripTimetableFromCalendarRow(
                              context,
                              displayRows[i],
                              departuresRtMatch[i],
                              bubbles,
                              selectedDay,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DayChoicePill extends StatelessWidget {
  const _DayChoicePill({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? kRomagnaPrimary.withValues(alpha: 0.16)
                    : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? kRomagnaPrimary.withValues(alpha: 0.45)
                      : kRomagnaDarkGray.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color:
                    selected
                        ? kRomagnaDarkGray
                        : kRomagnaDarkGray.withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

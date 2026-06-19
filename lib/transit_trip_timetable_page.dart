// Pagina dedicata: tabellone fermate lungo una singola corsa GTFS (orari programmati).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'infobus_realtime.dart';
import 'romagna_brand.dart';
import 'stop_transit_schedule.dart';

/// Dettaglio corsa: fermate con orario programmato (solo fermate ancora in catalogo `fermate_*.json`); RT in testata se [infobusRtCard].
class TransitTripTimetablePage extends StatelessWidget {
  const TransitTripTimetablePage({
    super.key,
    required this.lineLabel,
    required this.routeComposite,
    required this.selectedStopId,
    required this.selectedStopNameUi,
    required this.rows,
    required this.stopIdToName,
    required this.towardsDestination,
    required this.scheduledHmDisplay,
    this.infobusRtCard,
    this.partitoAlleHm,
  });

  final String lineLabel;
  final String routeComposite;
  final String selectedStopId;
  final String selectedStopNameUi;
  final List<TransitTripStopRow> rows;
  final Map<String, String> stopIdToName;

  /// Destinazione capolinea / verso mostrata in intestazione.
  final String towardsDestination;

  /// Orario programmato alla fermata selezionata (testo come in elenco partenze).
  final String scheduledHmDisplay;

  /// Se presente, mostra pill RT in testata (solo questa fermata).
  final InfobusArrivalCard? infobusRtCard;

  /// Orario effettivo di partenza (tabellone da « Partenze precedenti »).
  final String? partitoAlleHm;

  @override
  Widget build(BuildContext context) {
    final card = infobusRtCard;
    final partito = partitoAlleHm?.trim() ?? '';
    final head =
        partito.isNotEmpty
            ? () {
              final base =
                  card != null ? infobusTripTimetableHeadUi(card) : null;
              return InfobusTripTimetableHeadUi(
                arrivalClock: partito,
                bubbleTint: base?.bubbleTint ?? kRomagnaPrimary,
                footerLabel: base?.footerLabel ?? '',
                isSuppressed: base?.isSuppressed ?? false,
              );
            }()
            : (card != null ? infobusTripTimetableHeadUi(card) : null);
    final sel = selectedStopId.trim();

    // Fermate assenti da fermate_fc|ra|rn (es. rimosse dal dataset): nel GTFS restano ma non hanno nome → non mostrarle.
    final displayRows =
        stopIdToName.isEmpty
            ? rows
            : [
              for (final r in rows)
                if (stopIdToName[r.stopId.trim()]?.trim().isNotEmpty == true) r,
            ];

    Widget rtArrivalBubble(InfobusTripTimetableHeadUi h, {bool partitoAlle = false}) {
      final timeColor =
          h.bubbleTint == kRomagnaPrimary
              ? transitChipTimeTextColor(kRomagnaPrimary)
              : kRomagnaDarkGray.withValues(alpha: 0.92);
      final box = DecoratedBox(
        decoration: BoxDecoration(
          color: h.bubbleTint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: h.bubbleTint.withValues(alpha: 0.38)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (partitoAlle) ...[
                Text(
                  'Partito alle',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.15,
                    color: kRomagnaDarkGray.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                h.arrivalClock,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: timeColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      );
      if (!h.isSuppressed) return box;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          box,
          const SizedBox(width: 8),
          Text(
            'SOPPRESSA',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              color: const Color(0xFFC62828),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          'Linea $lineLabel',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              'Direzione $towardsDestination',
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
              ),
            ),
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kRomagnaDarkGray.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alla tua fermata',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: kRomagnaDarkGray.withValues(alpha: 0.45),
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedStopNameUi,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: kRomagnaDarkGray,
                            ),
                          ),
                          if (partito.isEmpty ||
                              partito != scheduledHmDisplay.trim()) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Programmato $scheduledHmDisplay',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: kRomagnaDarkGray.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                          if (card == null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Nessun dato in tempo reale per questa corsa',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: kRomagnaDarkGray.withValues(alpha: 0.42),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (head != null) ...[
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          rtArrivalBubble(
                            head,
                            partitoAlle: partito.isNotEmpty,
                          ),
                          if (head.footerLabel.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              head.footerLabel,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.65,
                                color: head.bubbleTint.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Fermate e orari (programmati)',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: kRomagnaDarkGray.withValues(alpha: 0.48),
                letterSpacing: 0.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              routeComposite,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: kRomagnaDarkGray.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 10),
            ...displayRows.map((r) {
              final sid = r.stopId.trim();
              final isSel = sid == sel;
              final name =
                  stopIdToName[sid]?.trim().isNotEmpty == true
                      ? stopIdToName[sid]!.trim()
                      : sid;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        compactTransitDepClock(r.depRaw),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                          color:
                              isSel
                                  ? kRomagnaPrimary
                                  : kRomagnaDarkGray.withValues(alpha: 0.88),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          color:
                              isSel
                                  ? kRomagnaDarkGray
                                  : kRomagnaDarkGray.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

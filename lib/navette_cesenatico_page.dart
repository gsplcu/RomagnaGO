import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'servizio_clienti_page.dart';
import 'linee_percorsi.dart';
import 'navette_cesenatico_data.dart';
import 'romagna_brand.dart';

enum _ScheduleView { byRun, byStop, map }

enum _ScheduleTabPosition { first, middle, last }

class NavettaCesenaticoPage extends StatefulWidget {
  const NavettaCesenaticoPage({super.key});

  @override
  State<NavettaCesenaticoPage> createState() => _NavettaCesenaticoPageState();
}

class _NavettaCesenaticoPageState extends State<NavettaCesenaticoPage> {
  _ScheduleView _scheduleView = _ScheduleView.byRun;
  String _selectedStop = kNavettaCesenaticoStopFilters.first;
  final _runs = buildNavettaCesenaticoRuns();

  TextStyle _titleStyle({double size = 22}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: NavettaCesenaticoColors.greenDark,
    height: 1.25,
  );

  TextStyle _bodyStyle({Color? color, double size = 14}) => GoogleFonts.inter(
    fontSize: size,
    height: 1.45,
    color: color ?? NavettaCesenaticoColors.text.withValues(alpha: 0.88),
  );

  void _showZoomableMap(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (_) => Dialog(
            insetPadding: const EdgeInsets.all(8),
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.asset(
                      kNavettaCesenaticoMapAsset,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _openContattiPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ServizioClientiPage()),
    );
  }

  void _onHelpLinkTap(NavettaCesenaticoHelpLink link) {
    if (link.opensContattiPage) {
      _openContattiPage();
      return;
    }
    final uri = link.uri;
    if (uri != null) _openUri(uri);
  }

  Future<void> _openUri(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${uri.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavettaCesenaticoColors.greenSoft,
      appBar: AppBar(
        title: Text(
          'Navetta Cesenatico',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _heroSection(),
          const SizedBox(height: 20),
          _featuresSection(),
          const SizedBox(height: 28),
          _routeSection(),
          const SizedBox(height: 28),
          _scheduleSection(),
          const SizedBox(height: 28),
          _helpSection(),
        ],
      ),
    );
  }

  Widget _heroSection() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NavettaCesenaticoColors.greenLine),
        boxShadow: [
          BoxShadow(
            color: NavettaCesenaticoColors.greenDark.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _heroBadge('Estate 2026'),
                _heroBadge('Gratis'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Nuovo parcheggio scambiatore di via Mazzini',
              style: _titleStyle(size: 21),
            ),
            const SizedBox(height: 12),
            Text(
              'Da sabato 30 maggio apre il nuovo parcheggio scambiatore di via Mazzini a Cesenatico: oltre 400 posti auto gratuiti a servizio della zona Ponente e del lungomare.',
              style: _bodyStyle(),
            ),
            const SizedBox(height: 10),
            Text(
              'Per tutta l\'estate sarà attivo anche un servizio navetta gratuito con collegamenti ogni 20 minuti tra il parcheggio e il lungomare di Ponente.',
              style: _bodyStyle(),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NavettaCesenaticoColors.greenLine),
              ),
              child: Row(
                children: [
                  Container(
                    width: 5,
                    height: 56,
                    decoration: BoxDecoration(
                      color: NavettaCesenaticoColors.green,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                      child: Text(
                        'Navetta gratuita attiva sabato e festivi dalle 08:30 alle 18:40',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: NavettaCesenaticoColors.greenDark,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NavettaCesenaticoColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NavettaCesenaticoColors.greenLine),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: NavettaCesenaticoColors.greenDark,
        ),
      ),
    );
  }

  Widget _featuresSection() {
    return Column(
      children: [
        for (var i = 0; i < kNavettaCesenaticoFeatures.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _featureCard(kNavettaCesenaticoFeatures[i]),
        ],
      ],
    );
  }

  Widget _featureCard(NavettaCesenaticoFeature feature) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: NavettaCesenaticoColors.greenLine,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: NavettaCesenaticoColors.greenDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 6,
            decoration: const BoxDecoration(
              color: NavettaCesenaticoColors.green,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: NavettaCesenaticoColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    feature.icon,
                    color: NavettaCesenaticoColors.green,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.title, style: _titleStyle(size: 17)),
                      const SizedBox(height: 6),
                      Text(feature.body, style: _bodyStyle(size: 13.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Orari navetta', style: _titleStyle(size: 24)),
        const SizedBox(height: 8),
        Text(
          'Consulta le corse complete o i passaggi per fermata, senza scorrere la tabella orizzontale del sito.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: 14),
        _scheduleModeSelector(),
        const SizedBox(height: 16),
        switch (_scheduleView) {
          _ScheduleView.byRun => _runsList(),
          _ScheduleView.byStop => _stopSchedule(),
          _ScheduleView.map => const _NavettaServiceMapCard(),
        },
      ],
    );
  }

  Widget _scheduleModeSelector() {
    const outerRadius = 12.0;
    const borderWidth = 1.0;
    const innerRadius = outerRadius - borderWidth;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(outerRadius),
        side: const BorderSide(
          color: NavettaCesenaticoColors.greenLine,
          width: borderWidth,
        ),
      ),
      child: Row(
        children: [
          _scheduleModeTab(
            mode: _ScheduleView.byRun,
            label: 'Per corsa',
            icon: Icons.route_rounded,
            position: _ScheduleTabPosition.first,
            innerRadius: innerRadius,
          ),
          _scheduleModeTab(
            mode: _ScheduleView.byStop,
            label: 'Per fermata',
            icon: Icons.place_outlined,
            position: _ScheduleTabPosition.middle,
            innerRadius: innerRadius,
          ),
          _scheduleModeTab(
            mode: _ScheduleView.map,
            label: 'Mappa',
            icon: Icons.map_outlined,
            position: _ScheduleTabPosition.last,
            innerRadius: innerRadius,
          ),
        ],
      ),
    );
  }

  Widget _scheduleModeTab({
    required _ScheduleView mode,
    required String label,
    required IconData icon,
    required _ScheduleTabPosition position,
    required double innerRadius,
  }) {
    final selected = _scheduleView == mode;
    BorderRadius? fillRadius;
    if (selected) {
      fillRadius = switch (position) {
        _ScheduleTabPosition.first => BorderRadius.horizontal(
          left: Radius.circular(innerRadius),
        ),
        _ScheduleTabPosition.last => BorderRadius.horizontal(
          right: Radius.circular(innerRadius),
        ),
        _ScheduleTabPosition.middle => null,
      };
    }

    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? NavettaCesenaticoColors.green : Colors.white,
          borderRadius: fillRadius,
          border:
              position == _ScheduleTabPosition.last
                  ? null
                  : const Border(
                    right: BorderSide(
                      color: NavettaCesenaticoColors.greenLine,
                      width: 1,
                    ),
                  ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _scheduleView = mode),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color:
                        selected
                            ? Colors.white
                            : NavettaCesenaticoColors.greenDark,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected
                                ? Colors.white
                                : NavettaCesenaticoColors.greenDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _runsList() {
    return Column(
      children: [
        for (var i = 0; i < _runs.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: _runCard(_runs[i], i),
          ),
      ],
    );
  }

  Widget _runCard(NavettaShuttleRun run, int index) {
    final last = run.passages.last.time;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          visualDensity: VisualDensity.compact,
          minTileHeight: 48,
          tilePadding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NavettaCesenaticoColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: NavettaCesenaticoColors.greenDark,
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Partenza ${run.departureTime}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.15,
                  color: NavettaCesenaticoColors.greenDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Ritorno al parcheggio alle $last',
                style: _bodyStyle(
                  size: 11.5,
                  color: NavettaCesenaticoColors.text.withValues(alpha: 0.62),
                ),
              ),
            ],
          ),
          children: [
            for (var j = 0; j < run.passages.length; j++)
              _runTimelineRow(
                run.passages[j],
                isFirst: j == 0,
                isLast: j == run.passages.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _runTimelineRow(
    NavettaStopPassage passage, {
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isFirst
                            ? Colors.transparent
                            : NavettaCesenaticoColors.greenLine,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color:
                        isFirst || isLast
                            ? NavettaCesenaticoColors.green
                            : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NavettaCesenaticoColors.green,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color:
                        isLast
                            ? Colors.transparent
                            : NavettaCesenaticoColors.greenLine,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      passage.time,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: NavettaCesenaticoColors.greenDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passage.stopName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: NavettaCesenaticoColors.text,
                          ),
                        ),
                        Text(
                          passage.directionLabel,
                          style: _bodyStyle(
                            size: 11.5,
                            color: NavettaCesenaticoColors.text.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopSchedule() {
    final passages = navettaPassagesForStop(_selectedStop);
    final morning =
        passages.where((p) => navettaTimeIsMorning(p.time)).toList();
    final afternoon =
        passages.where((p) => !navettaTimeIsMorning(p.time)).toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavettaCesenaticoColors.greenLine),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scegli la fermata',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: NavettaCesenaticoColors.greenDark,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final stop in kNavettaCesenaticoStopFilters)
                  _stopFilterChip(stop),
              ],
            ),
            const SizedBox(height: 18),
            if (morning.isNotEmpty) ...[
              _timeGroupTitle('Mattina'),
              const SizedBox(height: 8),
              _timeChipGrid(morning),
              const SizedBox(height: 16),
            ],
            if (afternoon.isNotEmpty) ...[
              _timeGroupTitle('Pomeriggio'),
              const SizedBox(height: 8),
              _timeChipGrid(afternoon),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stopFilterChip(String stop) {
    final selected = _selectedStop == stop;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedStop = stop),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? NavettaCesenaticoColors.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? NavettaCesenaticoColors.green
                      : NavettaCesenaticoColors.greenLine,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: NavettaCesenaticoColors.greenDark,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                stop,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: NavettaCesenaticoColors.greenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeGroupTitle(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: NavettaCesenaticoColors.green,
      ),
    );
  }

  static const int _kTimeChipColumns = 4;
  static const double _kTimeChipGap = 8;

  Widget _timeChipGrid(List<NavettaStopPassage> passages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _kTimeChipGap * (_kTimeChipColumns - 1)) /
            _kTimeChipColumns;
        return Wrap(
          spacing: _kTimeChipGap,
          runSpacing: _kTimeChipGap,
          children: [
            for (final passage in passages)
              SizedBox(width: cellWidth, child: _timeChip(passage)),
          ],
        );
      },
    );
  }

  Widget _timeChip(NavettaStopPassage passage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: NavettaCesenaticoColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NavettaCesenaticoColors.greenLine),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            passage.time,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: NavettaCesenaticoColors.greenDark,
            ),
          ),
          if (passage.directionLabel.isNotEmpty)
            Text(
              passage.directionLabel,
              textAlign: TextAlign.center,
              style: _bodyStyle(
                size: 10.5,
                color: NavettaCesenaticoColors.text.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _routeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Percorso navetta', style: _titleStyle(size: 24)),
        const SizedBox(height: 10),
        Text(
          'La navetta collega il parcheggio di via Mazzini con il lungomare di Ponente passando da Atlantica, via De Varthema e via Diaz.',
          style: _bodyStyle(),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => _showZoomableMap(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: romagnaHelpImageFrame(
                      tight: true,
                      child: Image.asset(
                        kNavettaCesenaticoMapAsset,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Text(
                    'Clic per ingrandire\nPuoi visualizzare la mappa interattiva qui sotto',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: NavettaCesenaticoColors.text.withValues(
                        alpha: 0.42,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Serve aiuto?', style: _titleStyle(size: 24)),
        const SizedBox(height: 14),
        for (var i = 0; i < kNavettaCesenaticoHelpLinks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _helpCard(kNavettaCesenaticoHelpLinks[i]),
        ],
      ],
    );
  }

  Widget _helpCard(NavettaCesenaticoHelpLink link) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onHelpLinkTap(link),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  link.icon,
                  size: 20,
                  color: NavettaCesenaticoColors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link.title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.15,
                        color: NavettaCesenaticoColors.greenDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: _bodyStyle(
                        size: 11.5,
                        color: NavettaCesenaticoColors.text.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: NavettaCesenaticoColors.green.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavettaServiceMapCard extends StatefulWidget {
  const _NavettaServiceMapCard();

  @override
  State<_NavettaServiceMapCard> createState() => _NavettaServiceMapCardState();
}

class _NavettaServiceMapCardState extends State<_NavettaServiceMapCard> {
  List<LatLng>? _routePoints;
  LatLngBounds? _serviceBounds;
  LatLngBounds? _navigationBounds;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      final raw = await rootBundle.loadString(kNavettaCesenaticoGpxAsset);
      final pts = latLngsFromGpxString(raw);
      if (pts.length < 2) {
        throw StateError('Tracciato GPX navetta non valido');
      }
      if (!mounted) return;
      final fitBox = boundsFromRoutePoints(pts, paddingDegrees: 0.0015);
      final navBox = boundsFromRoutePoints(pts, paddingDegrees: 0.0045);
      setState(() {
        _routePoints = pts;
        _serviceBounds = LatLngBounds(fitBox.southWest, fitBox.northEast);
        _navigationBounds = LatLngBounds(navBox.southWest, navBox.northEast);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  void _openFullscreenMap() {
    final points = _routePoints;
    final fitBounds = _serviceBounds;
    final navBounds = _navigationBounds;
    if (points == null || fitBounds == null || navBounds == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => _NavettaServiceMapFullscreenPage(
              routePoints: points,
              serviceBounds: fitBounds,
              navigationBounds: navBounds,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
      );
    }
    if (_loadError != null ||
        _routePoints == null ||
        _serviceBounds == null ||
        _navigationBounds == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NavettaCesenaticoColors.greenLine),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Impossibile caricare il tracciato navetta.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: NavettaCesenaticoColors.text.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NavettaCesenaticoColors.greenLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            child: SizedBox(
              height: 280,
              child: _NavettaRouteMapView(
                routePoints: _routePoints!,
                serviceBounds: _serviceBounds!,
                navigationBounds: _navigationBounds!,
                onOpenFullscreen: _openFullscreenMap,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kNavettaCesenaticoMapStops.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: NavettaCesenaticoColors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.airport_shuttle_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kNavettaCesenaticoMapStops[i].displayName,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                height: 1.25,
                                color: NavettaCesenaticoColors.text,
                              ),
                            ),
                            Text(
                              kNavettaCesenaticoMapStops[i].roleLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: NavettaCesenaticoColors.text.withValues(
                                  alpha: 0.55,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavettaServiceMapFullscreenPage extends StatelessWidget {
  const _NavettaServiceMapFullscreenPage({
    required this.routePoints,
    required this.serviceBounds,
    required this.navigationBounds,
  });

  final List<LatLng> routePoints;
  final LatLngBounds serviceBounds;
  final LatLngBounds navigationBounds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavettaCesenaticoColors.greenSoft,
      appBar: AppBar(
        title: Text(
          'Mappa navetta',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: _NavettaRouteMapView(
        routePoints: routePoints,
        serviceBounds: serviceBounds,
        navigationBounds: navigationBounds,
        expanded: true,
      ),
    );
  }
}

class _NavettaRouteMapView extends StatefulWidget {
  const _NavettaRouteMapView({
    required this.routePoints,
    required this.serviceBounds,
    required this.navigationBounds,
    this.onOpenFullscreen,
    this.expanded = false,
  });

  final List<LatLng> routePoints;
  final LatLngBounds serviceBounds;
  final LatLngBounds navigationBounds;
  final VoidCallback? onOpenFullscreen;
  final bool expanded;

  @override
  State<_NavettaRouteMapView> createState() => _NavettaRouteMapViewState();
}

class _NavettaRouteMapViewState extends State<_NavettaRouteMapView> {
  final _mapController = MapController();
  NavettaCesenaticoMapStop? _selectedStop;

  static const double _kMinZoom = 10;
  static const double _kMaxZoom = 18;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _selectStop(NavettaCesenaticoMapStop stop) {
    setState(() => _selectedStop = stop);
  }

  void _clearSelectedStop() {
    if (_selectedStop == null) return;
    setState(() => _selectedStop = null);
  }

  Future<void> _openDirections(NavettaCesenaticoMapStop stop) async {
    final lat = stop.point.latitude;
    final lon = stop.point.longitude;
    final uri =
        defaultTargetPlatform == TargetPlatform.iOS
            ? Uri.parse('http://maps.apple.com/?daddr=$lat,$lon&dirflg=d')
            : Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
            );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire le indicazioni stradali'),
        ),
      );
    }
  }

  void _fitServiceArea() {
    if (!mounted) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: widget.serviceBounds,
          padding: EdgeInsets.all(widget.expanded ? 40 : 28),
        ),
      );
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    try {
      final cam = _mapController.camera;
      final nextZoom = (cam.zoom + delta).clamp(_kMinZoom, _kMaxZoom);
      _mapController.move(cam.center, nextZoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.serviceBounds.center,
              initialZoom: 14,
              minZoom: _kMinZoom,
              maxZoom: _kMaxZoom,
              initialCameraFit: CameraFit.bounds(
                bounds: widget.serviceBounds,
                padding: EdgeInsets.all(widget.expanded ? 40 : 28),
              ),
              cameraConstraint: CameraConstraint.containCenter(
                bounds: widget.navigationBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, __) => _clearSelectedStop(),
              onPositionChanged: (_, __) {
                if (_selectedStop != null) setState(() {});
              },
              onMapReady: _fitServiceArea,
            ),
            children: [
              TileLayer(
                urlTemplate: kNavettaCesenaticoOsmHotTileUrl,
                subdomains: kNavettaCesenaticoOsmHotSubdomains,
                userAgentPackageName: 'RomagnaGO',
                maxNativeZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 3.5,
                    color: NavettaCesenaticoColors.green.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final stop in kNavettaCesenaticoMapStops)
                    Marker(
                      point: stop.point,
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: _NavettaStopPin(
                        label: stop.displayName,
                        selected: identical(_selectedStop, stop),
                        onTap: () => _selectStop(stop),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedStop != null)
          _NavettaStopPopupOverlay(
            mapController: _mapController,
            stop: _selectedStop!,
            onDirections: () => _openDirections(_selectedStop!),
          ),
        romagnaMapAttributionChip(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          text: '© OpenStreetMap · HOT',
          textStyle: GoogleFonts.inter(
            fontSize: 9,
            color: NavettaCesenaticoColors.text.withValues(alpha: 0.55),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 10,
          child: Material(
            color: Colors.white,
            elevation: 2,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.onOpenFullscreen != null)
                  IconButton(
                    tooltip: 'Schermo intero',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onOpenFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  ),
                IconButton(
                  tooltip: 'Zoom in',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _zoomBy(1),
                  icon: const Icon(Icons.add, size: 20),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _zoomBy(-1),
                  icon: const Icon(Icons.remove, size: 20),
                ),
                IconButton(
                  tooltip: 'Adatta area',
                  visualDensity: VisualDensity.compact,
                  onPressed: _fitServiceArea,
                  icon: const Icon(Icons.fit_screen_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavettaStopPopupOverlay extends StatelessWidget {
  const _NavettaStopPopupOverlay({
    required this.mapController,
    required this.stop,
    required this.onDirections,
  });

  final MapController mapController;
  final NavettaCesenaticoMapStop stop;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    Offset offset;
    try {
      offset = mapController.camera.latLngToScreenOffset(stop.point);
    } catch (_) {
      return const SizedBox.shrink();
    }

    const cardW = 208.0;
    const cardPad = 14.0;
    const tailW = 14.0;
    const tailH = 8.0;
    const markerRadius = 17.0;
    const markerLift = 0.0;
    // Altezza stimata compatta (padding + 3 righe), senza minHeight forzato.
    const estimatedCardH = cardPad * 2 + 18 + 4 + 13 + 8 + 18;
    const totalH = estimatedCardH + tailH + markerRadius;
    const borderColor = NavettaCesenaticoColors.green;

    final mq = MediaQuery.sizeOf(context);
    var left = offset.dx - cardW / 2;
    var top = offset.dy - markerLift - estimatedCardH - tailH - markerRadius;
    left = left.clamp(8.0, mq.width - cardW - 8.0);
    top = top.clamp(8.0, mq.height - totalH - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          '${stop.displayName}_${stop.roleLabel}_${stop.point.latitude}',
        ),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final dy = (1 - t) * 12;
          return Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, dy), child: child),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Material(
              elevation: 8,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: Container(
                width: cardW,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor, width: 2),
                ),
                padding: const EdgeInsets.all(cardPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kRomagnaDarkGray,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stop.roleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: kRomagnaDarkGray.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: onDirections,
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_rounded,
                            size: 16,
                            color: NavettaCesenaticoColors.green,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Indicazioni stradali',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NavettaCesenaticoColors.greenDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -tailH,
              child: CustomPaint(
                size: const Size(tailW, tailH),
                painter: _NavettaBubbleTrianglePainter(color: borderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavettaBubbleTrianglePainter extends CustomPainter {
  const _NavettaBubbleTrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final path =
        ui.Path()
          ..moveTo(size.width / 2, size.height)
          ..lineTo(0, 0)
          ..lineTo(size.width, 0)
          ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.15), 3, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _NavettaBubbleTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _NavettaStopPin extends StatelessWidget {
  const _NavettaStopPin({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: NavettaCesenaticoColors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected ? NavettaCesenaticoColors.greenDark : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.airport_shuttle_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

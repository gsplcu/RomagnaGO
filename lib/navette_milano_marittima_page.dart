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
import 'navette_milano_marittima_data.dart';
import 'photon_romagna.dart';
import 'romagna_brand.dart';

const _kPagePadding = 16.0;
const _kCardPadding = 12.0;
const _kBlockGap = 12.0;
const _kTightGap = 6.0;
const _kHeaderCalendarGap = 20.0;
const _kSectionTopGap = 24.0;
const _kCardRadius = 12.0;
const _kCalendarDayCellHeight = 44.0;
const _kCalendarTitleHeight = 22.0;
const _kCalendarWeekdayHeight = 17.0;
const _kCalendarHeightSlack = 8.0;
const _kActiveDayCircle = 30.0;

class NavettaMilanoMarittimaPage extends StatefulWidget {
  const NavettaMilanoMarittimaPage({super.key});

  @override
  State<NavettaMilanoMarittimaPage> createState() =>
      _NavettaMilanoMarittimaPageState();
}

class _NavettaMilanoMarittimaPageState extends State<NavettaMilanoMarittimaPage> {
  late final PageController _calendarController;
  late int _calendarPage;
  late DateTime _selectedDate;
  NavettaMiMaDirection _mapDirection = NavettaMiMaDirection.congressiToCorelli;

  @override
  void initState() {
    super.initState();
    _selectedDate = navettaMiMaInitialSelectedDate();
    _calendarPage = navettaMiMaInitialCalendarPage();
    _calendarController = PageController(initialPage: _calendarPage);
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  void _shiftCalendarMonth(int delta) {
    final next = (_calendarPage + delta).clamp(
      0,
      kNavettaMiMaCalendarMonths.length - 1,
    );
    if (next == _calendarPage) return;
    _calendarController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectDate(DateTime date) {
    setState(
      () => _selectedDate = DateTime(date.year, date.month, date.day),
    );
  }

  TextStyle _titleStyle({double size = 22}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: NavettaMiMaColors.greenDark,
    height: 1.25,
  );

  TextStyle _bodyStyle({Color? color, double size = 14}) => GoogleFonts.inter(
    fontSize: size,
    height: 1.45,
    color: color ?? NavettaMiMaColors.text.withValues(alpha: 0.88),
  );

  TextStyle _sectionTitleStyle() => _titleStyle(size: 24);

  Future<void> _openUri(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire ${uri.toString()}')),
      );
    }
  }

  void _openContattiPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ServizioClientiPage()),
    );
  }

  void _onHelpLinkTap(NavettaMiMaHelpLink link) {
    if (link.opensContattiPage) {
      _openContattiPage();
      return;
    }
    final uri = link.uri;
    if (uri != null) _openUri(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavettaMiMaColors.greenSoft,
      appBar: AppBar(
        title: Text(
          'Navetta gratuita Milano Marittima',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kRomagnaDarkGray,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          _kPagePadding,
          12,
          _kPagePadding,
          28,
        ),
        children: [
          _headerSection(),
          const SizedBox(height: _kHeaderCalendarGap),
          _calendarSection(),
          const SizedBox(height: _kTightGap),
          _dayStatusBanner(),
          const SizedBox(height: _kSectionTopGap),
          _routeSection(),
          _helpSection(),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettaMiMaColors.greenLine),
        boxShadow: [
          BoxShadow(
            color: NavettaMiMaColors.greenDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: child,
      ),
    );
  }

  Widget _headerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Image.asset(
            kNavettaMiMaHeaderAsset,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chipBadge('Servizio gratuito'),
                  _chipBadge('Estate 2026'),
                ],
              ),
              const SizedBox(height: _kTightGap),
              Text(
                'Navetta gratuita Milano Marittima',
                style: _titleStyle(size: 21),
              ),
              const SizedBox(height: _kTightGap),
              Text(
                'Anche per l\'estate 2026 è attivo il servizio navetta gratuito per raggiungere comodamente il centro e la spiaggia di Milano Marittima.',
                style: _bodyStyle(),
              ),
              const SizedBox(height: _kTightGap),
              Text(
                'Il servizio collega il parcheggio del Centro Congressi con la Rotonda Corelli ed è pensato per cittadini, turisti e visitatori che desiderano muoversi in modo semplice, comodo e sostenibile.',
                style: _bodyStyle(size: 13),
              ),
              const SizedBox(height: _kBlockGap),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: NavettaMiMaColors.greenSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NavettaMiMaColors.greenLine),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        size: 18,
                        color: NavettaMiMaColors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Percorso: Centro Congressi – Rotonda Corelli',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: NavettaMiMaColors.greenDark,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NavettaMiMaColors.greenSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NavettaMiMaColors.greenLine),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: NavettaMiMaColors.greenDark,
        ),
      ),
    );
  }

  double _calendarViewportHeightForMonth(
    DateTime month, {
    double textScale = 1,
  }) {
    final rows = navettaMiMaCalendarRowCount(month);
    final header =
        (_kCalendarTitleHeight + _kCalendarWeekdayHeight) * textScale +
        _kBlockGap +
        6;
    return header + rows * _kCalendarDayCellHeight + _kCalendarHeightSlack;
  }

  double _calendarMaxViewportHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    var maxHeight = 0.0;
    for (final month in kNavettaMiMaCalendarMonths) {
      final h = _calendarViewportHeightForMonth(month, textScale: textScale);
      if (h > maxHeight) maxHeight = h;
    }
    return maxHeight;
  }

  Widget _calendarSection() {
    final viewportHeight = _calendarMaxViewportHeight(context);
    final canGoBack = _calendarPage > 0;
    final canGoForward =
        _calendarPage < kNavettaMiMaCalendarMonths.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Calendario del servizio', style: _sectionTitleStyle()),
        const SizedBox(height: _kTightGap),
        Text(
          'Giugno–settembre 2026. Tocca un giorno per vedere se il servizio è attivo e gli orari di riferimento.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _calendarArrow(
                    icon: Icons.chevron_left_rounded,
                    enabled: canGoBack,
                    onTap: () => _shiftCalendarMonth(-1),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: viewportHeight,
                      child: PageView.builder(
                        controller: _calendarController,
                        itemCount: kNavettaMiMaCalendarMonths.length,
                        onPageChanged: (i) => setState(() => _calendarPage = i),
                        itemBuilder: (_, index) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: _MiMaMonthGrid(
                              month: kNavettaMiMaCalendarMonths[index],
                              selectedDate: _selectedDate,
                              onDayTap: _selectDate,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _calendarArrow(
                    icon: Icons.chevron_right_rounded,
                    enabled: canGoForward,
                    onTap: () => _shiftCalendarMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: _kTightGap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: NavettaMiMaColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Giorno di servizio',
                    style: _bodyStyle(
                      size: 12,
                      color: NavettaMiMaColors.text.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Oggi',
                    style: _bodyStyle(
                      size: 12,
                      color: NavettaMiMaColors.text.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _calendarArrow({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 36,
      child: IconButton(
        onPressed: enabled ? onTap : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          icon,
          size: 28,
          color:
              enabled
                  ? NavettaMiMaColors.green
                  : NavettaMiMaColors.text.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _dayStatusBanner() {
    final active = navettaMiMaIsActiveDay(_selectedDate);
    final isToday = navettaMiMaIsToday(_selectedDate);
    final schedule = navettaMiMaScheduleFor(_selectedDate);

    final title =
        active
            ? (isToday ? 'Servizio attivo oggi' : 'Servizio attivo')
            : (isToday
                ? 'Servizio non disponibile oggi'
                : 'Servizio non disponibile');

    final (bg, fg, icon) =
        active
            ? (
              NavettaMiMaColors.green.withValues(alpha: 0.12),
              NavettaMiMaColors.greenDark,
              Icons.check_circle_rounded,
            )
            : (
              const Color(0xFFE53935).withValues(alpha: 0.1),
              const Color(0xFFC62828),
              Icons.cancel_rounded,
            );

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: fg,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      navettaMiMaFormatLongItalianDate(_selectedDate),
                      style: _bodyStyle(size: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (active && schedule != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NavettaMiMaColors.greenLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Orario servizio: ${schedule.serviceHoursLabel}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NavettaMiMaColors.greenDark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.frequencyLabel,
                    style: _bodyStyle(size: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeSection() {
    final route = navettaMiMaRouteChoice(_mapDirection);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Percorso', style: _sectionTitleStyle()),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Partenza',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: NavettaMiMaColors.greenDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'La navetta parte dal parcheggio del Centro Congressi di Milano Marittima.',
                style: _bodyStyle(size: 13),
              ),
              const SizedBox(height: 10),
              Text(
                'Tracciato',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: NavettaMiMaColors.greenDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Il bus percorre viale Jelenia Gora, Traversa I Pineta e viale 2 Giugno fino alla Rotonda Corelli.',
                style: _bodyStyle(size: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: _kBlockGap),
        _directionSelector(),
        const SizedBox(height: _kBlockGap),
        _MiMaServiceMapCard(route: route),
      ],
    );
  }

  Widget _directionSelector() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Direzione',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NavettaMiMaColors.greenDark,
            ),
          ),
          const SizedBox(height: 10),
          for (final direction in NavettaMiMaDirection.values) ...[
            if (direction != NavettaMiMaDirection.values.first)
              const SizedBox(height: 6),
            _directionChip(
              label: navettaMiMaRouteChoice(direction).label,
              selected: _mapDirection == direction,
              onTap: () => setState(() => _mapDirection = direction),
            ),
          ],
        ],
      ),
    );
  }

  Widget _directionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                selected ? NavettaMiMaColors.green : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? NavettaMiMaColors.green
                      : NavettaMiMaColors.greenLine,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : NavettaMiMaColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: _kSectionTopGap),
          child: Text('Serve aiuto?', style: _sectionTitleStyle()),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < kNavettaMiMaHelpLinks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _helpCard(kNavettaMiMaHelpLinks[i]),
        ],
      ],
    );
  }

  Widget _helpCard(NavettaMiMaHelpLink link) {
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
                  color: NavettaMiMaColors.green,
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
                        color: NavettaMiMaColors.greenDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: _bodyStyle(
                        size: 11.5,
                        color: NavettaMiMaColors.text.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: NavettaMiMaColors.green.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiMaMonthGrid extends StatelessWidget {
  const _MiMaMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final title = '${kNavettaMiMaMonthNames[month.month]} ${month.year}';
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingEmpty = firstWeekday - DateTime.monday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rowCount = navettaMiMaCalendarRowCount(month);
    final totalCells = rowCount * 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: NavettaMiMaColors.text,
          ),
        ),
        const SizedBox(height: _kBlockGap),
        Row(
          children: [
            for (final label in kNavettaMiMaWeekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NavettaMiMaColors.text.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < rowCount; row++)
          SizedBox(
            height: _kCalendarDayCellHeight,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(
                      cellIndex: row * 7 + col,
                      leadingEmpty: leadingEmpty,
                      daysInMonth: daysInMonth,
                      totalCells: totalCells,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayCell({
    required int cellIndex,
    required int leadingEmpty,
    required int daysInMonth,
    required int totalCells,
  }) {
    if (cellIndex >= totalCells) return const SizedBox.shrink();
    if (cellIndex < leadingEmpty) return const SizedBox.shrink();

    final day = cellIndex - leadingEmpty + 1;
    if (day > daysInMonth) return const SizedBox.shrink();

    final date = DateTime(month.year, month.month, day);
    final active = navettaMiMaIsActiveDay(date);
    final isToday = navettaMiMaIsToday(date);
    final isSelected =
        selectedDate.year == date.year &&
        selectedDate.month == date.month &&
        selectedDate.day == date.day;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onDayTap(date),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Container(
                width: _kActiveDayCircle,
                height: _kActiveDayCircle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: NavettaMiMaColors.green,
                  shape: BoxShape.circle,
                  border:
                      isSelected
                          ? Border.all(
                            color: NavettaMiMaColors.greenDark,
                            width: 2,
                          )
                          : null,
                ),
                child: Text(
                  '$day',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              )
            else
              Container(
                width: _kActiveDayCircle,
                height: _kActiveDayCircle,
                alignment: Alignment.center,
                decoration:
                    isSelected
                        ? BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: NavettaMiMaColors.greenDark,
                            width: 2,
                          ),
                        )
                        : null,
                child: Text(
                  '$day',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: NavettaMiMaColors.text,
                    height: 1,
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFFE53935) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiMaServiceMapCard extends StatefulWidget {
  const _MiMaServiceMapCard({required this.route});

  final NavettaMiMaRouteChoice route;

  @override
  State<_MiMaServiceMapCard> createState() => _MiMaServiceMapCardState();
}

class _MiMaServiceMapCardState extends State<_MiMaServiceMapCard> {
  List<LatLng>? _routePoints;
  List<NavettaMiMaTerminal>? _terminals;
  LatLngBounds? _serviceBounds;
  LatLngBounds? _navigationBounds;
  bool _loading = true;
  String? _loadError;
  String? _loadedAsset;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(covariant _MiMaServiceMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route.gpxAsset != widget.route.gpxAsset) {
      _loadRoute();
    }
  }

  Future<void> _loadRoute() async {
    final asset = widget.route.gpxAsset;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = await rootBundle.loadString(asset);
      final pts = latLngsFromGpxString(raw);
      if (pts.length < 2) {
        throw StateError('Tracciato GPX non valido');
      }
      if (!mounted || widget.route.gpxAsset != asset) return;
      final fitBox = boundsFromRoutePoints(pts, paddingDegrees: 0.0015);
      final navBox = boundsFromRoutePoints(pts, paddingDegrees: 0.0045);
      setState(() {
        _routePoints = pts;
        _terminals = navettaMiMaTerminalsFromRoutePoints(widget.route, pts);
        _serviceBounds = LatLngBounds(fitBox.southWest, fitBox.northEast);
        _navigationBounds = LatLngBounds(navBox.southWest, navBox.northEast);
        _loading = false;
        _loadedAsset = asset;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _loadedAsset != widget.route.gpxAsset) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
      );
    }
    if (_loadError != null ||
        _routePoints == null ||
        _terminals == null ||
        _serviceBounds == null ||
        _navigationBounds == null) {
      return _surfaceCard(
        child: Text(
          'Impossibile caricare il tracciato.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: NavettaMiMaColors.text.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettaMiMaColors.greenLine),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius - 1),
        child: SizedBox(
          height: 300,
          child: _MiMaRouteMapView(
            key: ValueKey(widget.route.gpxAsset),
            routePoints: _routePoints!,
            serviceBounds: _serviceBounds!,
            navigationBounds: _navigationBounds!,
            terminals: _terminals!,
          ),
        ),
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettaMiMaColors.greenLine),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _MiMaRouteMapView extends StatefulWidget {
  const _MiMaRouteMapView({
    super.key,
    required this.routePoints,
    required this.serviceBounds,
    required this.navigationBounds,
    required this.terminals,
    this.expanded = false,
  });

  final List<LatLng> routePoints;
  final LatLngBounds serviceBounds;
  final LatLngBounds navigationBounds;
  final List<NavettaMiMaTerminal> terminals;
  final bool expanded;

  @override
  State<_MiMaRouteMapView> createState() => _MiMaRouteMapViewState();
}

class _MiMaRouteMapViewState extends State<_MiMaRouteMapView> {
  final _mapController = MapController();
  NavettaMiMaTerminal? _selectedTerminal;

  static const double _kMinZoom = 10;
  static const double _kMaxZoom = 18;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _selectTerminal(NavettaMiMaTerminal terminal) {
    setState(() => _selectedTerminal = terminal);
  }

  void _clearSelectedTerminal() {
    if (_selectedTerminal == null) return;
    setState(() => _selectedTerminal = null);
  }

  Future<void> _openDirections(NavettaMiMaTerminal terminal) async {
    final lat = terminal.point.latitude;
    final lon = terminal.point.longitude;
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

  void _openFullscreenMap() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                title: Text(
                  'Navetta gratuita Milano Marittima',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.white,
                foregroundColor: kRomagnaDarkGray,
                surfaceTintColor: Colors.transparent,
                elevation: 0.5,
              ),
              body: _MiMaRouteMapView(
                routePoints: widget.routePoints,
                serviceBounds: widget.serviceBounds,
                navigationBounds: widget.navigationBounds,
                terminals: widget.terminals,
                expanded: true,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapSize = Size(constraints.maxWidth, constraints.maxHeight);
        return _buildMapStack(mapSize);
      },
    );
  }

  Widget _buildMapStack(Size mapSize) {
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
              onTap: (_, __) => _clearSelectedTerminal(),
              onPositionChanged: (_, __) {
                if (_selectedTerminal != null) setState(() {});
              },
              onMapReady: _fitServiceArea,
            ),
            children: [
              TileLayer(
                urlTemplate: kNavettaMiMaOsmHotTileUrl,
                subdomains: kNavettaMiMaOsmHotSubdomains,
                userAgentPackageName: 'RomagnaGO',
                maxNativeZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 3.5,
                    color: NavettaMiMaColors.green.withValues(alpha: 0.75),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final terminal in widget.terminals)
                    Marker(
                      point: terminal.point,
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      child: _MiMaTerminalPin(
                        label: terminal.displayName,
                        selected: identical(_selectedTerminal, terminal),
                        onTap: () => _selectTerminal(terminal),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (_selectedTerminal != null)
          _MiMaTerminalPopupOverlay(
            mapController: _mapController,
            mapSize: mapSize,
            terminal: _selectedTerminal!,
            onDirections: () => _openDirections(_selectedTerminal!),
          ),
        romagnaMapAttributionChip(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          text: '© OpenStreetMap · HOT',
          textStyle: GoogleFonts.inter(
            fontSize: 9,
            color: NavettaMiMaColors.text.withValues(alpha: 0.55),
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
                if (!widget.expanded)
                  IconButton(
                    tooltip: 'Schermo intero',
                    visualDensity: VisualDensity.compact,
                    onPressed: _openFullscreenMap,
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

/// Allineamento marker [MarkerLayer] (38×38, centro sul punto).
const _kMiMaMapMarkerExtent = 38.0;

class _MiMaTerminalPin extends StatelessWidget {
  const _MiMaTerminalPin({
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
            color: NavettaMiMaColors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? NavettaMiMaColors.greenDark : Colors.white,
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
            Icons.place_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _MiMaTerminalPopupOverlay extends StatefulWidget {
  const _MiMaTerminalPopupOverlay({
    required this.mapController,
    required this.mapSize,
    required this.terminal,
    required this.onDirections,
  });

  final MapController mapController;
  final Size mapSize;
  final NavettaMiMaTerminal terminal;
  final VoidCallback onDirections;

  @override
  State<_MiMaTerminalPopupOverlay> createState() =>
      _MiMaTerminalPopupOverlayState();
}

class _MiMaTerminalPopupOverlayState extends State<_MiMaTerminalPopupOverlay> {
  late Future<String?> _addressFuture;

  @override
  void initState() {
    super.initState();
    _addressFuture = reverseRomagnaStreetLine(widget.terminal.point);
  }

  @override
  void didUpdateWidget(covariant _MiMaTerminalPopupOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal.point != widget.terminal.point) {
      _addressFuture = reverseRomagnaStreetLine(widget.terminal.point);
    }
  }

  @override
  Widget build(BuildContext context) {
    Offset pinCenter;
    try {
      pinCenter = widget.mapController.camera.latLngToScreenOffset(
        widget.terminal.point,
      );
    } catch (_) {
      return const SizedBox.shrink();
    }

    const cardW = 208.0;
    const cardPad = 12.0;
    const tailW = 14.0;
    const tailH = 8.0;
    const borderColor = NavettaMiMaColors.green;
    const markerRadius = _kMiMaMapMarkerExtent / 2;
    const edgePad = 6.0;

    final pinTopY = pinCenter.dy - markerRadius;
    final mapW = widget.mapSize.width;
    final mapH = widget.mapSize.height;

    var cardLeft = pinCenter.dx - cardW / 2;
    cardLeft = cardLeft.clamp(edgePad, mapW - cardW - edgePad);

    final tailLeft = (pinCenter.dx - cardLeft - tailW / 2).clamp(
      0.0,
      cardW - tailW,
    );

    final card = Material(
      elevation: 8,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Container(
        width: cardW,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(cardPad, cardPad, cardPad, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.terminal.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kRomagnaDarkGray,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            FutureBuilder<String?>(
              future: _addressFuture,
              builder: (context, snap) {
                final text = snap.data;
                if (text == null || text.isEmpty) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Text(
                      '…',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        height: 1.2,
                        color: kRomagnaDarkGray.withValues(alpha: 0.45),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }
                return Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.2,
                    color: kRomagnaDarkGray.withValues(alpha: 0.55),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: widget.onDirections,
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_rounded,
                    size: 16,
                    color: NavettaMiMaColors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Indicazioni stradali',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: NavettaMiMaColors.greenDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned(
      left: cardLeft,
      bottom: mapH - pinTopY,
      width: cardW,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          '${widget.terminal.displayName}_${widget.terminal.point.latitude}',
        ),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            SizedBox(
              height: tailH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: tailLeft,
                    top: 0,
                    child: CustomPaint(
                      size: const Size(tailW, tailH),
                      painter: _MiMaBubbleTrianglePainter(color: borderColor),
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
}

class _MiMaBubbleTrianglePainter extends CustomPainter {
  const _MiMaBubbleTrianglePainter({required this.color});

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
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiMaBubbleTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}

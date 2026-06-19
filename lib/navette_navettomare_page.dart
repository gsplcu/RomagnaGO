import 'dart:async';
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
import 'navette_navettomare_data.dart';
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

class NavettoMarePage extends StatefulWidget {
  const NavettoMarePage({super.key});

  @override
  State<NavettoMarePage> createState() => _NavettoMarePageState();
}

class _NavettoMarePageState extends State<NavettoMarePage> {
  late final PageController _calendarController;
  late int _calendarPage;
  late DateTime _scheduleDate;
  NavettoMareLine _scheduleLine = NavettoMareLine.marina;
  NavettoMareLine _mapLine = NavettoMareLine.marina;
  NavettoMareDirection _mapDirection = NavettoMareDirection.forward;
  NavettoMareScheduleData? _schedules;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _scheduleDate = navettomareActiveServiceDay();
    _calendarPage = _initialCalendarPage();
    _calendarController = PageController(initialPage: _calendarPage);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final data = await loadNavettoMareSchedules();
      if (!mounted) return;
      setState(() => _schedules = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _schedules = const {});
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _calendarController.dispose();
    super.dispose();
  }

  int _initialCalendarPage() {
    final focus = navettomareActiveServiceDay();
    for (var i = 0; i < kNavettoMareCalendarMonths.length; i++) {
      final m = kNavettoMareCalendarMonths[i];
      if (m.year == focus.year && m.month == focus.month) return i;
    }
    return 0;
  }

  void _shiftCalendarMonth(int delta) {
    final next = (_calendarPage + delta).clamp(
      0,
      kNavettoMareCalendarMonths.length - 1,
    );
    if (next == _calendarPage) return;
    _calendarController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectScheduleDate(DateTime date) {
    setState(() => _scheduleDate = DateTime(date.year, date.month, date.day));
  }

  TextStyle _titleStyle({double size = 22}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: NavettoMareColors.accentDark,
    height: 1.25,
  );

  TextStyle _bodyStyle({Color? color, double size = 14}) => GoogleFonts.inter(
    fontSize: size,
    height: 1.45,
    color: color ?? NavettoMareColors.text.withValues(alpha: 0.88),
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

  void _onHelpLinkTap(NavettoMareHelpLink link) {
    if (link.opensContattiPage) {
      _openContattiPage();
      return;
    }
    final uri = link.uri;
    if (uri != null) _openUri(uri);
  }

  void _showZoomableMap() {
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
                      kNavettoMareMapAsset,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NavettoMareColors.surface,
      appBar: AppBar(
        title: Text(
          'Navetto Mare',
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
          const SizedBox(height: _kSectionTopGap),
          _scheduleSection(),
          const SizedBox(height: _kSectionTopGap),
          _mapSection(),
          _helpSection(),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavettoMareColors.card,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettoMareColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: NavettoMareColors.accent.withValues(alpha: 0.06),
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

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _kBlockGap),
      child: Text(title, style: _sectionTitleStyle()),
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
            kNavettoMareBannerAsset,
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
              Text(kNavettoMareHeroTitle, style: _titleStyle(size: 21)),
              const SizedBox(height: _kTightGap),
              Text(
                kNavettoMareHeroSubtitle,
                style: _bodyStyle(),
              ),
              const SizedBox(height: _kBlockGap),
              Text(
                kNavettoMareHeroServiceNote,
                style: _bodyStyle(size: 13),
              ),
              const SizedBox(height: _kBlockGap),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final label in kNavettoMareHeroChips)
                    _chipBadge(label),
                ],
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
        color: NavettoMareColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NavettoMareColors.cardBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: NavettoMareColors.accentDark,
        ),
      ),
    );
  }

  double _calendarViewportHeightForMonth(
    DateTime month, {
    double textScale = 1,
  }) {
    final rows = navettomareCalendarRowCount(month);
    final header =
        (_kCalendarTitleHeight + _kCalendarWeekdayHeight) * textScale +
        _kBlockGap +
        6;
    return header + rows * _kCalendarDayCellHeight + _kCalendarHeightSlack;
  }

  double _calendarMaxViewportHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    var maxHeight = 0.0;
    for (final month in kNavettoMareCalendarMonths) {
      final h = _calendarViewportHeightForMonth(month, textScale: textScale);
      if (h > maxHeight) maxHeight = h;
    }
    return maxHeight;
  }

  Widget _calendarSection() {
    final viewportHeight = _calendarMaxViewportHeight(context);
    final canGoBack = _calendarPage > 0;
    final canGoForward = _calendarPage < kNavettoMareCalendarMonths.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Quando è attivo il servizio', style: _sectionTitleStyle()),
        const SizedBox(height: _kTightGap),
        Text(
          'Calendario valido dal 25 aprile al 13 settembre 2026. Clic su un giorno attivo per consultare gli orari.',
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
                        itemCount: kNavettoMareCalendarMonths.length,
                        onPageChanged: (i) => setState(() => _calendarPage = i),
                        itemBuilder: (_, index) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: _NavettoMareMonthGrid(
                              month: kNavettoMareCalendarMonths[index],
                              selectedDate: _scheduleDate,
                              onDayTap: _selectScheduleDate,
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
                      color: NavettoMareColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Giorno di servizio',
                    style: _bodyStyle(
                      size: 12,
                      color: NavettoMareColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: NavettoMareColors.todayRing,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Oggi',
                    style: _bodyStyle(
                      size: 12,
                      color: NavettoMareColors.textMuted,
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
                  ? NavettoMareColors.accent
                  : NavettoMareColors.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _mapSection() {
    final route = navettomareRouteChoice(
      line: _mapLine,
      direction: _mapDirection,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Percorsi e cartina'),
        Text(
          'Linea 65: Park via Trieste – Park via del Marchesato – Marina di Ravenna. '
          'Linea 66: Park via Trieste – Lungomare C. Colombo – Punta Marina Terme.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: _kBlockGap),
        ClipRRect(
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Material(
            color: Colors.white,
            child: InkWell(
              onTap: _showZoomableMap,
              child: romagnaHelpImageFrame(
                tight: true,
                child: Image.asset(
                  kNavettoMareMapAsset,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _kBlockGap),
        _routeSelector(
          line: _mapLine,
          direction: _mapDirection,
          onLineChanged:
              (line) => setState(() {
                _mapLine = line;
                _mapDirection = NavettoMareDirection.forward;
              }),
          onDirectionChanged:
              (direction) => setState(() => _mapDirection = direction),
        ),
        const SizedBox(height: _kBlockGap),
        _NavettoMareServiceMapCard(route: route),
      ],
    );
  }

  Widget _lineOnlySelector({
    required NavettoMareLine line,
    required ValueChanged<NavettoMareLine> onLineChanged,
  }) {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Linea',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NavettoMareColors.accentDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in NavettoMareLine.values)
                _lineChip(
                  label: option.label,
                  selected: line == option,
                  onTap: () => onLineChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeSelector({
    required NavettoMareLine line,
    required NavettoMareDirection direction,
    required ValueChanged<NavettoMareLine> onLineChanged,
    required ValueChanged<NavettoMareDirection> onDirectionChanged,
  }) {
    final forward = navettomareRouteChoice(
      line: line,
      direction: NavettoMareDirection.forward,
    );
    final reverse = navettomareRouteChoice(
      line: line,
      direction: NavettoMareDirection.reverse,
    );

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Linea e direzione',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NavettoMareColors.accentDark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final option in NavettoMareLine.values)
                _lineChip(
                  label: option.label,
                  selected: line == option,
                  onTap: () => onLineChanged(option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _directionChip(
            label: forward.label,
            selected: direction == NavettoMareDirection.forward,
            onTap: () => onDirectionChanged(NavettoMareDirection.forward),
          ),
          const SizedBox(height: 6),
          _directionChip(
            label: reverse.label,
            selected: direction == NavettoMareDirection.reverse,
            onTap: () => onDirectionChanged(NavettoMareDirection.reverse),
          ),
        ],
      ),
    );
  }

  Widget _lineChip({
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
          decoration: BoxDecoration(
            color:
                selected
                    ? NavettoMareColors.accent.withValues(alpha: 0.12)
                    : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? NavettoMareColors.accent
                      : NavettoMareColors.cardBorder,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: NavettoMareColors.accentDark,
            ),
          ),
        ),
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
                selected ? NavettoMareColors.accent : NavettoMareColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  selected
                      ? NavettoMareColors.accent
                      : NavettoMareColors.cardBorder,
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
                    color: selected ? Colors.white : NavettoMareColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scheduleSection() {
    final schedules = _schedules;
    final active = navettomareIsActiveDay(_scheduleDate);
    final times =
        schedules == null
            ? const <String>[]
            : navettomareTimesFor(
              schedules: schedules,
              date: _scheduleDate,
              line: _scheduleLine,
            );
    final partitions = navettomarePartitionDisplayTimes(times);
    final activeServiceDay = navettomareActiveServiceDay();
    final isViewingActiveServiceDay =
        _scheduleDate.year == activeServiceDay.year &&
        _scheduleDate.month == activeServiceDay.month &&
        _scheduleDate.day == activeServiceDay.day;
    final upcoming =
        schedules != null && isViewingActiveServiceDay && active
            ? navettomareUpcomingTimesFor(
              schedules: schedules,
              line: _scheduleLine,
            )
            : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Orari del servizio'),
        Text(
          'Orari pubblicati dal 25 aprile al 13 settembre 2026. Seleziona la linea, le corse sono divise tra diurne e notturne.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: _kBlockGap),
        _lineOnlySelector(
          line: _scheduleLine,
          onLineChanged: (line) => setState(() => _scheduleLine = line),
        ),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                navettomareFormatLongItalianDate(_scheduleDate),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: NavettoMareColors.accentDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _scheduleLine.shortLabel,
                style: _bodyStyle(size: 12, color: NavettoMareColors.textMuted),
              ),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: NavettoMareColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NavettoMareColors.cardBorder),
                  ),
                  child: Text(
                    'Prossima corsa: ${upcoming.first}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: NavettoMareColors.accentDark,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (schedules == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                )
              else if (!active)
                Text(
                  'Servizio non attivo in questa data.',
                  style: _bodyStyle(
                    size: 13,
                    color: NavettoMareColors.textMuted,
                  ),
                )
              else if (times.isEmpty)
                Text(
                  'Nessun orario disponibile per questa combinazione.',
                  style: _bodyStyle(
                    size: 13,
                    color: NavettoMareColors.textMuted,
                  ),
                )
              else ...[
                if (partitions.daytime.isNotEmpty) ...[
                  _timeGroupTitle('Corse diurne'),
                  const SizedBox(height: 8),
                  _timeChipGrid(partitions.daytime),
                ],
                if (partitions.night.isNotEmpty) ...[
                  if (partitions.daytime.isNotEmpty) const SizedBox(height: 14),
                  _timeGroupTitle('Corse notturne'),
                  const SizedBox(height: 8),
                  _timeChipGrid(partitions.night),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _timeGroupTitle(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: NavettoMareColors.accent,
      ),
    );
  }

  static const int _kTimeChipColumns = 4;
  static const double _kTimeChipGap = 8;

  Widget _timeChipGrid(List<String> times) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth =
            (constraints.maxWidth - _kTimeChipGap * (_kTimeChipColumns - 1)) /
            _kTimeChipColumns;
        return Wrap(
          spacing: _kTimeChipGap,
          runSpacing: _kTimeChipGap,
          children: [
            for (final time in times)
              SizedBox(width: cellWidth, child: _timeChip(time)),
          ],
        );
      },
    );
  }

  Widget _timeChip(String time) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: NavettoMareColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NavettoMareColors.cardBorder),
      ),
      child: Text(
        time,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: NavettoMareColors.accentDark,
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
        const SizedBox(height: 14),
        for (var i = 0; i < kNavettoMareHelpLinks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _helpCard(kNavettoMareHelpLinks[i]),
        ],
      ],
    );
  }

  Widget _helpCard(NavettoMareHelpLink link) {
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
                  color: NavettoMareColors.accent,
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
                        color: NavettoMareColors.accentDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: _bodyStyle(
                        size: 11.5,
                        color: NavettoMareColors.text.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: NavettoMareColors.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavettoMareMonthGrid extends StatelessWidget {
  const _NavettoMareMonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final title = '${kNavettoMareMonthNames[month.month]} ${month.year}';
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingEmpty = firstWeekday - DateTime.monday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rowCount = navettomareCalendarRowCount(month);
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
            color: NavettoMareColors.text,
          ),
        ),
        const SizedBox(height: _kBlockGap),
        Row(
          children: [
            for (final label in kNavettoMareWeekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: NavettoMareColors.textMuted,
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
    final active = navettomareIsActiveDay(date);
    final isToday = navettomareIsToday(date);
    final isSelected =
        selectedDate.year == date.year &&
        selectedDate.month == date.month &&
        selectedDate.day == date.day;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? () => onDayTap(date) : null,
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
                  color: NavettoMareColors.accent,
                  shape: BoxShape.circle,
                  border:
                      isSelected
                          ? Border.all(
                            color: NavettoMareColors.accentDark,
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
              SizedBox(
                width: _kActiveDayCircle,
                height: _kActiveDayCircle,
                child: Center(
                  child: Text(
                    '$day',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: NavettoMareColors.text,
                      height: 1,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    isToday ? NavettoMareColors.todayRing : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavettoMareServiceMapCard extends StatefulWidget {
  const _NavettoMareServiceMapCard({required this.route});

  final NavettoMareRouteChoice route;

  @override
  State<_NavettoMareServiceMapCard> createState() =>
      _NavettoMareServiceMapCardState();
}

class _NavettoMareServiceMapCardState
    extends State<_NavettoMareServiceMapCard> {
  List<LatLng>? _routePoints;
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
  void didUpdateWidget(covariant _NavettoMareServiceMapCard oldWidget) {
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
        _serviceBounds == null ||
        _navigationBounds == null) {
      return _surfaceCard(
        child: Text(
          'Impossibile caricare il tracciato.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: NavettoMareColors.text.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final terminals = navettomareTerminalsForRoute(widget.route);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettoMareColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_kCardRadius - 1),
            ),
            child: SizedBox(
              height: 280,
              child: _NavettoMareRouteMapView(
                key: ValueKey(widget.route.gpxAsset),
                routePoints: _routePoints!,
                serviceBounds: _serviceBounds!,
                navigationBounds: _navigationBounds!,
                terminals: terminals,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < terminals.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: NavettoMareColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            terminals[i].code,
                            style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          terminals[i].displayName,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            height: 1.25,
                            color: NavettoMareColors.text,
                          ),
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

  Widget _surfaceCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: NavettoMareColors.cardBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _NavettoMareRouteMapView extends StatefulWidget {
  const _NavettoMareRouteMapView({
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
  final List<NavettoMareTerminal> terminals;
  final bool expanded;

  @override
  State<_NavettoMareRouteMapView> createState() =>
      _NavettoMareRouteMapViewState();
}

class _NavettoMareRouteMapViewState extends State<_NavettoMareRouteMapView> {
  final _mapController = MapController();
  NavettoMareTerminal? _selectedTerminal;

  static const double _kMinZoom = 10;
  static const double _kMaxZoom = 18;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _selectTerminal(NavettoMareTerminal terminal) {
    setState(() => _selectedTerminal = terminal);
  }

  void _clearSelectedTerminal() {
    if (_selectedTerminal == null) return;
    setState(() => _selectedTerminal = null);
  }

  Future<void> _openDirections(NavettoMareTerminal terminal) async {
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
                  'Mappa Navetto Mare',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.white,
                foregroundColor: kRomagnaDarkGray,
                surfaceTintColor: Colors.transparent,
                elevation: 0.5,
              ),
              body: _NavettoMareRouteMapView(
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
                urlTemplate: kNavettoMareOsmHotTileUrl,
                subdomains: kNavettoMareOsmHotSubdomains,
                userAgentPackageName: 'RomagnaGO',
                maxNativeZoom: 19,
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 3.5,
                    color: NavettoMareColors.accent.withValues(alpha: 0.75),
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
                      child: _NavettoMareTerminalPin(
                        code: terminal.code,
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
          _NavettoMareTerminalPopupOverlay(
            mapController: _mapController,
            terminal: _selectedTerminal!,
            onDirections: () => _openDirections(_selectedTerminal!),
          ),
        romagnaMapAttributionChip(
          backgroundColor: Colors.white.withValues(alpha: 0.82),
          text: '© OpenStreetMap · HOT',
          textStyle: GoogleFonts.inter(
            fontSize: 9,
            color: NavettoMareColors.text.withValues(alpha: 0.55),
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

class _NavettoMareTerminalPin extends StatelessWidget {
  const _NavettoMareTerminalPin({
    required this.code,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String code;
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
            color: NavettoMareColors.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? NavettoMareColors.accentDark : Colors.white,
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
          child: Center(
            child: Text(
              code,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavettoMareTerminalPopupOverlay extends StatelessWidget {
  const _NavettoMareTerminalPopupOverlay({
    required this.mapController,
    required this.terminal,
    required this.onDirections,
  });

  final MapController mapController;
  final NavettoMareTerminal terminal;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    Offset offset;
    try {
      offset = mapController.camera.latLngToScreenOffset(terminal.point);
    } catch (_) {
      return const SizedBox.shrink();
    }

    const cardW = 208.0;
    const cardPad = 14.0;
    const tailW = 14.0;
    const tailH = 8.0;
    const markerRadius = 17.0;
    const estimatedCardH = cardPad * 2 + 18 + 4 + 13 + 8 + 18;
    const totalH = estimatedCardH + tailH + markerRadius;
    const borderColor = NavettoMareColors.accent;

    final mq = MediaQuery.sizeOf(context);
    var left = offset.dx - cardW / 2;
    var top = offset.dy - estimatedCardH - tailH - markerRadius;
    left = left.clamp(8.0, mq.width - cardW - 8.0);
    top = top.clamp(8.0, mq.height - totalH - 8.0);

    return Positioned(
      left: left,
      top: top,
      width: cardW,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(
          '${terminal.code}_${terminal.displayName}_${terminal.point.latitude}',
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
                      terminal.displayName,
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
                      terminal.code,
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
                            color: NavettoMareColors.accent,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Indicazioni stradali',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: NavettoMareColors.accentDark,
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
                painter: _NavettoMareBubbleTrianglePainter(color: borderColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavettoMareBubbleTrianglePainter extends CustomPainter {
  const _NavettoMareBubbleTrianglePainter({required this.color});

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
  bool shouldRepaint(covariant _NavettoMareBubbleTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

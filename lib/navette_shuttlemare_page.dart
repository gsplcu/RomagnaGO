import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'servizio_clienti_page.dart';
import 'navette_shuttlemare_data.dart';
import 'romagna_brand.dart';

const _kPagePadding = 16.0;
const _kCardPadding = 12.0;
const _kBlockGap = 12.0;
const _kTightGap = 6.0;
const _kHeaderCalendarGap = 24.0;
const _kSectionTopGap = 28.0;
const _kCardRadius = 12.0;
const _kCalendarDayCellHeight = 44.0;
const _kCalendarTitleHeight = 22.0;
const _kCalendarWeekdayHeight = 17.0;
const _kCalendarHeightSlack = 8.0;
const _kActiveDayCircle = 30.0;
const _kMyStartLogoSize = 64.0;

class NavetteShuttlemarePage extends StatefulWidget {
  const NavetteShuttlemarePage({super.key});

  @override
  State<NavetteShuttlemarePage> createState() => _NavetteShuttlemarePageState();
}

class _NavetteShuttlemarePageState extends State<NavetteShuttlemarePage> {
  late final PageController _calendarController;
  late int _calendarPage;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _calendarPage = _initialCalendarPage();
    _calendarController = PageController(initialPage: _calendarPage);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _calendarController.dispose();
    super.dispose();
  }

  int _initialCalendarPage() {
    final now = DateTime.now();
    for (var i = 0; i < kShuttlemareCalendarMonths.length; i++) {
      final m = kShuttlemareCalendarMonths[i];
      if (m.year == now.year && m.month == now.month) return i;
    }
    return 0;
  }

  void _shiftCalendarMonth(int delta) {
    final next = (_calendarPage + delta).clamp(
      0,
      kShuttlemareCalendarMonths.length - 1,
    );
    if (next == _calendarPage) return;
    _calendarController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  TextStyle _titleStyle({double size = 22}) => GoogleFonts.inter(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: ShuttlemareColors.accentDark,
    height: 1.25,
  );

  TextStyle _bodyStyle({Color? color, double size = 14}) => GoogleFonts.inter(
    fontSize: size,
    height: 1.45,
    color: color ?? ShuttlemareColors.text.withValues(alpha: 0.88),
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

  Future<void> _openParkingDirections(String address) async {
    final geo = Uri.parse('geo:0,0?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    final web = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    await _openUri(web);
  }

  Future<void> _openMyStartAppOrStore({required bool ios}) async {
    if (!ios) {
      if (await canLaunchUrl(kShuttlemareAppUri)) {
        final opened = await launchUrl(
          kShuttlemareAppUri,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      }
      final market = Uri.parse('market://details?id=$kShuttlemarePlayStoreId');
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
      await _openUri(
        Uri.parse(
          'https://play.google.com/store/apps/details?id=$kShuttlemarePlayStoreId',
        ),
      );
      return;
    }

    if (await canLaunchUrl(kShuttlemareAppUri)) {
      final opened = await launchUrl(
        kShuttlemareAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    }
    await _openUri(Uri.parse(kShuttlemareAppStoreUrl));
  }

  void _openContattiPage() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ServizioClientiPage()),
    );
  }

  void _onHelpLinkTap(ShuttlemareHelpLink link) {
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
      backgroundColor: ShuttlemareColors.surface,
      appBar: AppBar(
        title: Text(
          'Shuttlemare',
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
          const SizedBox(height: _kBlockGap),
          _serviceHoursBanner(),
          const SizedBox(height: _kBlockGap),
          _todayStatusBanner(),
          _serviceMapSection(),
          _parkingSection(),
          _onboardRulesSection(),
          _myStartSection(),
          _helpSection(),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShuttlemareColors.card,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: ShuttlemareColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: ShuttlemareColors.accent.withValues(alpha: 0.06),
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
      padding: const EdgeInsets.only(top: _kSectionTopGap),
      child: Text(title, style: _sectionTitleStyle()),
    );
  }

  Widget _framedAssetImage(String asset, {BoxFit fit = BoxFit.contain}) {
    return romagnaHelpImageFrame(
      child: Image.asset(asset, width: double.infinity, fit: fit),
    );
  }

  Widget _headerSection() {
    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.airport_shuttle_rounded,
                color: ShuttlemareColors.accent,
                size: 32,
              ),
              const SizedBox(width: _kBlockGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Shuttlemare', style: _titleStyle(size: 21)),
                    const SizedBox(height: _kBlockGap),
                    Text(
                      'Gratis dalla città al mare: collegamento in bus a chiamata tra centro, parcheggi scambiatori e lungomare di Rimini.',
                      style: _bodyStyle(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: _kBlockGap),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [_chipBadge('Stagione 2026'), _chipBadge('Gratis')],
          ),
        ],
      ),
    );
  }

  Widget _chipBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ShuttlemareColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ShuttlemareColors.cardBorder),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: ShuttlemareColors.accentDark,
        ),
      ),
    );
  }

  double _calendarViewportHeightForMonth(
    DateTime month, {
    double textScale = 1,
  }) {
    final rows = shuttlemareCalendarRowCount(month);
    final header =
        (_kCalendarTitleHeight + _kCalendarWeekdayHeight) * textScale +
        _kBlockGap +
        6;
    return header + rows * _kCalendarDayCellHeight + _kCalendarHeightSlack;
  }

  /// Altezza fissa per tutti i mesi (max righe, es. agosto): spazio bianco sotto i mesi corti.
  double _calendarMaxViewportHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    var maxHeight = 0.0;
    for (final month in kShuttlemareCalendarMonths) {
      final h = _calendarViewportHeightForMonth(month, textScale: textScale);
      if (h > maxHeight) maxHeight = h;
    }
    return maxHeight;
  }

  Widget _calendarSection() {
    final viewportHeight = _calendarMaxViewportHeight(context);
    final canGoBack = _calendarPage > 0;
    final canGoForward = _calendarPage < kShuttlemareCalendarMonths.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Calendario attività', style: _sectionTitleStyle()),
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
                        itemCount: kShuttlemareCalendarMonths.length,
                        onPageChanged: (i) => setState(() => _calendarPage = i),
                        itemBuilder: (_, index) {
                          return Align(
                            alignment: Alignment.topCenter,
                            child: _ShuttlemareMonthGrid(
                              month: kShuttlemareCalendarMonths[index],
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
                      color: ShuttlemareColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Giorno di servizio',
                    style: _bodyStyle(
                      size: 12,
                      color: ShuttlemareColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: ShuttlemareColors.todayRing,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Oggi',
                    style: _bodyStyle(
                      size: 12,
                      color: ShuttlemareColors.textMuted,
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
                  ? ShuttlemareColors.accent
                  : ShuttlemareColors.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _serviceHoursBanner() {
    return _surfaceCard(
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 20,
            color: ShuttlemareColors.accent,
          ),
          const SizedBox(width: _kBlockGap),
          Expanded(
            child: Text(
              'Orario di servizio: 09:00 - 21:00',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ShuttlemareColors.text,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayStatusBanner() {
    final now = DateTime.now();
    final status = shuttlemareTodayStatus(now);
    final dateLabel = shuttlemareFormatLongItalianDate(now);

    final (label, bg, fg) = switch (status) {
      ShuttlemareTodayStatus.activeNow => (
        'Oggi: ora attivo',
        ShuttlemareColors.activeGreen.withValues(alpha: 0.14),
        ShuttlemareColors.activeGreen,
      ),
      ShuttlemareTodayStatus.activeDayOffHours => (
        'Oggi: ora non disponibile',
        ShuttlemareColors.accent.withValues(alpha: 0.12),
        ShuttlemareColors.accentDark,
      ),
      ShuttlemareTodayStatus.inactiveDay => (
        'Oggi: non attivo per tutta la giornata',
        ShuttlemareColors.inactiveGrey.withValues(alpha: 0.2),
        ShuttlemareColors.textMuted,
      ),
    };

    return _surfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.3,
              color: ShuttlemareColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Mappa del servizio'),
        const SizedBox(height: _kBlockGap),
        Text(
          'Scegli un tragitto dalla zona arancione alla zona azzurra, o viceversa. Non sono consentiti spostamenti tra due fermate della stessa zona. Il servizio collega solo le fermate disponibili sull\'app.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: _kBlockGap),
        _framedAssetImage(kShuttlemareServiceMapAsset, fit: BoxFit.fitWidth),
      ],
    );
  }

  Widget _parkingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Parcheggi scambiatori'),
        const SizedBox(height: _kBlockGap),
        Text(
          'Puoi lasciare l\'auto in uno dei parcheggi scambiatori e raggiungere il mare con Shuttlemare.',
          style: _bodyStyle(size: 13),
        ),
        const SizedBox(height: _kBlockGap),
        for (var i = 0; i < kShuttlemareParkingLots.length; i++) ...[
          if (i > 0) const SizedBox(height: _kBlockGap),
          _parkingCard(kShuttlemareParkingLots[i]),
        ],
      ],
    );
  }

  Widget _parkingCard(ShuttlemareParkingLot lot) {
    return Material(
      color: ShuttlemareColors.card,
      borderRadius: BorderRadius.circular(_kCardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            lot.unavailable ? null : () => _openParkingDirections(lot.address),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: ShuttlemareColors.cardBorder),
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kCardPadding,
            vertical: 14,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lot.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.2,
                  color: ShuttlemareColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lot.address,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: ShuttlemareColors.textMuted,
                ),
              ),
              if (lot.unavailable) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: ShuttlemareColors.unavailableRed,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Temporaneamente non disponibile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ShuttlemareColors.unavailableRed,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
              if (!lot.unavailable) ...[
                const SizedBox(height: 6),
                Text(
                  'Indicazioni stradali',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ShuttlemareColors.accent,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _onboardRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('I mezzi e le regole di bordo'),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kShuttlemareOnboardIntro, style: _bodyStyle(size: 13)),
              const SizedBox(height: _kBlockGap),
              for (final group in kShuttlemareOnboardRuleGroups) ...[
                Text(
                  group.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ShuttlemareColors.accentDark,
                  ),
                ),
                const SizedBox(height: 6),
                for (final bullet in group.bullets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: ShuttlemareColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(bullet, style: _bodyStyle(size: 13)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _myStartSection() {
    final ios =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('App My Start Romagna'),
        const SizedBox(height: _kBlockGap),
        _surfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    child: Image.asset(
                      kShuttlemareMyStartLogoAsset,
                      width: _kMyStartLogoSize,
                      height: _kMyStartLogoSize,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: _kBlockGap),
                  Expanded(
                    child: Text(
                      'L\'app ti aiuta a pianificare e monitorare il viaggio: prenotazione fino a 5 passeggeri, fermata più vicina, arrivo stimato e tracciamento in tempo reale.',
                      style: _bodyStyle(size: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _kBlockGap),
              Text(
                'Come prenotare',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ShuttlemareColors.accentDark,
                ),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < kShuttlemareBookingSteps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ShuttlemareColors.accent,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          kShuttlemareBookingSteps[i],
                          style: _bodyStyle(size: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: _kBlockGap),
              _framedAssetImage(
                kShuttlemareHowItWorksAsset,
                fit: BoxFit.fitWidth,
              ),
              const SizedBox(height: _kBlockGap),
              Text(
                'Prenotazioni anticipate, partenza e destinazione su mappa o indirizzo, monitoraggio del mezzo in avvicinamento.',
                style: _bodyStyle(size: 12, color: ShuttlemareColors.textMuted),
              ),
              const SizedBox(height: _kBlockGap),
              if (!ios)
                _storeButton(
                  label: 'Google Play Store',
                  icon: Icons.android_rounded,
                  onTap: () => _openMyStartAppOrStore(ios: false),
                ),
              if (!ios) const SizedBox(height: _kTightGap),
              _storeButton(
                label: 'Apple Store',
                icon: Icons.apple_rounded,
                onTap: () => _openMyStartAppOrStore(ios: true),
              ),
              if (ios) ...[
                const SizedBox(height: _kTightGap),
                _storeButton(
                  label: 'Google Play Store',
                  icon: Icons.android_rounded,
                  onTap: () => _openMyStartAppOrStore(ios: false),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _storeButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: ShuttlemareColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(double.infinity, 44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }

  Widget _helpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _sectionHeader('Serve aiuto?'),
        const SizedBox(height: 14),
        for (var i = 0; i < kShuttlemareHelpLinks.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _helpCard(kShuttlemareHelpLinks[i]),
        ],
      ],
    );
  }

  Widget _helpCard(ShuttlemareHelpLink link) {
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
                  color: ShuttlemareColors.accent,
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
                        color: ShuttlemareColors.accentDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      link.subtitle,
                      style: _bodyStyle(
                        size: 11.5,
                        color: ShuttlemareColors.text.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ShuttlemareColors.accent.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShuttlemareMonthGrid extends StatelessWidget {
  const _ShuttlemareMonthGrid({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final title = '${kShuttlemareMonthNames[month.month]} ${month.year}';
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingEmpty = firstWeekday - DateTime.monday;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final rowCount = shuttlemareCalendarRowCount(month);
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
            color: ShuttlemareColors.text,
          ),
        ),
        const SizedBox(height: _kBlockGap),
        Row(
          children: [
            for (final label in kShuttlemareWeekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ShuttlemareColors.textMuted,
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
    final active = shuttlemareIsActiveDay(date);
    final isToday = shuttlemareIsToday(date);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            Container(
              width: _kActiveDayCircle,
              height: _kActiveDayCircle,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: ShuttlemareColors.accent,
                shape: BoxShape.circle,
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
                    color: ShuttlemareColors.text,
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
              color: isToday ? ShuttlemareColors.todayRing : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

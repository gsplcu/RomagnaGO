/// Contenuti da [Navetta gratuita Milano Marittima 2026](https://www.startromagna.it/navetta-gratuita-milano-marittima-percorsi-e-orari-2026/).
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'navette_cesenatico_data.dart';
import 'start_content/navetta_content_sync.dart';
import 'start_content/start_content_id.dart';
import 'start_content/start_content_json.dart';

export 'navette_cesenatico_data.dart' show NavettaCesenaticoColors, boundsFromRoutePoints;

/// Alias palette verde (stesso tema Navetta Cesenatico).
typedef NavettaMiMaColors = NavettaCesenaticoColors;

const kNavettaMiMaOsmHotTileUrl = kNavettaCesenaticoOsmHotTileUrl;
const kNavettaMiMaOsmHotSubdomains = kNavettaCesenaticoOsmHotSubdomains;

const kNavettaMiMaHeaderAsset =
    'assets/MilanoMarittima-Bus-Navetta-gratuita-400x400-3.jpg';

const kNavettaMiMaGpxCongressiCorelli =
    'assets/data/GPX Navetta MiMa/MiMa Congressi - Corelli.gpx';
const kNavettaMiMaGpxCorelliCongressi =
    'assets/data/GPX Navetta MiMa/MiMa Corelli - Congressi.gpx';

const kNavettaMiMaWeekdayNames = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

const kNavettaMiMaWeekdayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

const kNavettaMiMaMonthNames = [
  '',
  'Gennaio',
  'Febbraio',
  'Marzo',
  'Aprile',
  'Maggio',
  'Giugno',
  'Luglio',
  'Agosto',
  'Settembre',
  'Ottobre',
  'Novembre',
  'Dicembre',
];

final kNavettaMiMaCalendarMonths = [
  DateTime(2026, 6),
  DateTime(2026, 7),
  DateTime(2026, 8),
  DateTime(2026, 9),
];

int navettaMiMaDateKey(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.year * 10000 + d.month * 100 + d.day;
}

String navettaMiMaFormatLongItalianDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${kNavettaMiMaWeekdayNames[d.weekday - 1]} '
      '${d.day} '
      '${kNavettaMiMaMonthNames[d.month].toLowerCase()} '
      '${d.year}';
}

Set<int> buildNavettaMiMaActiveDateKeys() {
  final keys = <int>{};
  void add(int year, int month, int day) {
    keys.add(navettaMiMaDateKey(DateTime(year, month, day)));
  }

  for (final day in [2, 6, 7, 13, 14, 20, 21, 27, 28]) {
    add(2026, 6, day);
  }
  for (final day in [4, 5, 11, 12, 18, 19, 25, 26]) {
    add(2026, 7, day);
  }
  for (final day in [
    1,
    2,
    8,
    9,
    14,
    15,
    16,
    22,
    23,
    29,
    30,
  ]) {
    add(2026, 8, day);
  }
  for (final day in [5, 6, 12, 13]) {
    add(2026, 9, day);
  }

  return keys;
}

final kNavettaMiMaActiveDateKeys = buildNavettaMiMaActiveDateKeys();

bool navettaMiMaIsActiveDay(DateTime date) {
  return kNavettaMiMaActiveDateKeys.contains(navettaMiMaDateKey(date));
}

bool navettaMiMaIsToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

int navettaMiMaCalendarRowCount(DateTime month) {
  final firstWeekday = DateTime(month.year, month.month, 1).weekday;
  final leadingEmpty = firstWeekday - DateTime.monday;
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  return ((leadingEmpty + daysInMonth) / 7).ceil();
}

/// Orari di riferimento per una data di servizio attivo (fonte Start Romagna 2026).
class NavettaMiMaDaySchedule {
  const NavettaMiMaDaySchedule({
    required this.serviceHoursLabel,
    required this.frequencyLabel,
  });

  final String serviceHoursLabel;
  final String frequencyLabel;
}

NavettaMiMaDaySchedule? navettaMiMaScheduleFor(DateTime date) {
  if (!navettaMiMaIsActiveDay(date)) return null;
  final isAugust = date.month == 8;
  final key = isAugust ? 'scheduleAugust' : 'scheduleDefault';
  final block = NavettaContentSync.scheduleBlock(
    StartContentId.navettaMilanoMarittima,
    key,
  );
  if (block != null && block.isNotEmpty) {
    return NavettaMiMaDaySchedule(
      serviceHoursLabel: scText(block, 'serviceHoursLabel'),
      frequencyLabel: scText(block, 'frequencyLabel'),
    );
  }
  return NavettaMiMaDaySchedule(
    serviceHoursLabel: isAugust ? '10:00 – 01:00' : '10:00 – 24:00',
    frequencyLabel:
        'Navetta ogni 15 minuti · ogni 20 minuti dalle 21:30',
  );
}

enum NavettaMiMaDirection { congressiToCorelli, corelliToCongressi }

class NavettaMiMaTerminal {
  const NavettaMiMaTerminal({
    required this.displayName,
    required this.point,
  });

  final String displayName;
  final LatLng point;
}

class NavettaMiMaRouteChoice {
  const NavettaMiMaRouteChoice({
    required this.direction,
    required this.label,
    required this.gpxAsset,
    required this.originName,
    required this.destinationName,
  });

  final NavettaMiMaDirection direction;
  final String label;
  final String gpxAsset;
  final String originName;
  final String destinationName;
}

NavettaMiMaRouteChoice navettaMiMaRouteChoice(NavettaMiMaDirection direction) {
  return switch (direction) {
    NavettaMiMaDirection.congressiToCorelli => const NavettaMiMaRouteChoice(
      direction: NavettaMiMaDirection.congressiToCorelli,
      label: 'Centro Congressi → Rotonda Corelli (II Giugno)',
      gpxAsset: kNavettaMiMaGpxCongressiCorelli,
      originName: 'Centro Congressi',
      destinationName: 'Rotonda Corelli (II Giugno)',
    ),
    NavettaMiMaDirection.corelliToCongressi => const NavettaMiMaRouteChoice(
      direction: NavettaMiMaDirection.corelliToCongressi,
      label: 'Rotonda Corelli (II Giugno) → Centro Congressi',
      gpxAsset: kNavettaMiMaGpxCorelliCongressi,
      originName: 'Rotonda Corelli (II Giugno)',
      destinationName: 'Centro Congressi',
    ),
  };
}

List<NavettaMiMaTerminal> navettaMiMaTerminalsFromRoutePoints(
  NavettaMiMaRouteChoice route,
  List<LatLng> points,
) {
  if (points.isEmpty) return const [];
  return [
    NavettaMiMaTerminal(
      displayName: route.originName,
      point: points.first,
    ),
    NavettaMiMaTerminal(
      displayName: route.destinationName,
      point: points.last,
    ),
  ];
}

class NavettaMiMaHelpLink {
  const NavettaMiMaHelpLink({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.uri,
    this.opensContattiPage = false,
  }) : assert(uri != null || opensContattiPage);

  final String title;
  final String subtitle;
  final IconData icon;
  final Uri? uri;
  final bool opensContattiPage;
}

final kNavettaMiMaHelpLinks = [
  NavettaMiMaHelpLink(
    title: 'Telefono',
    subtitle: '199.11.55.77',
    uri: Uri(scheme: 'tel', path: '199115577'),
    icon: Icons.phone_rounded,
  ),
  NavettaMiMaHelpLink(
    title: 'WhatsApp',
    subtitle: 'Chatta con noi',
    uri: Uri.parse('https://wa.me/393316566555'),
    icon: Icons.chat_rounded,
  ),
  NavettaMiMaHelpLink(
    title: 'Servizio Clienti',
    subtitle: 'Vai ai contatti',
    icon: Icons.support_agent_rounded,
    opensContattiPage: true,
  ),
];

DateTime navettaMiMaInitialSelectedDate() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  if (today.year == 2026 && today.month >= 6 && today.month <= 9) {
    return today;
  }
  return DateTime(2026, 6, 2);
}

int navettaMiMaInitialCalendarPage() {
  final focus = navettaMiMaInitialSelectedDate();
  for (var i = 0; i < kNavettaMiMaCalendarMonths.length; i++) {
    final m = kNavettaMiMaCalendarMonths[i];
    if (m.year == focus.year && m.month == focus.month) return i;
  }
  return 0;
}

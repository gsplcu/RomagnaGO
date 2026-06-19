/// Contenuti servizio [Shuttlemare 2026](https://www.startromagna.it/shuttlemare-2026/).
library;

import 'package:flutter/material.dart';

import 'start_content/navetta_content_sync.dart';
import 'start_content/start_content_id.dart';

/// Palette pagina Shuttlemare (tema chiaro, accento viola).
abstract final class ShuttlemareColors {
  static const accent = Color(0xFFC338DB);
  static const accentDark = Color(0xFF9E2DB0);
  static const surface = Color(0xFFF9EFFB);
  static const card = Colors.white;
  static const cardBorder = Color(0xFFE4C4EB);
  static const text = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const activeGreen = Color(0xFF16724F);
  static const inactiveGrey = Color(0xFF9CA3AF);
  static const unavailableRed = Color(0xFFDC2626);
  static const todayRing = Color(0xFFE53935);
}

const kShuttlemareServiceStartMinutes = 9 * 60;
const kShuttlemareServiceEndMinutes = 21 * 60;

const kShuttlemareMyStartLogoAsset = 'assets/mystart-logo.png';
const kShuttlemareHowItWorksAsset = 'assets/Shuttle-maps-1.jpg';
const kShuttlemareServiceMapAsset = 'assets/mappa-shuttle.webp';

const kShuttlemarePlayStoreId = 'it.infomobility.mystart';
const kShuttlemareAppStoreUrl =
    'https://apps.apple.com/it/app/my-start-romagna/id1571409384';
final kShuttlemareAppUri = Uri(scheme: 'it.infomobility.mystart');

const kShuttlemareWeekdayNames = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

/// Es. «sabato 30 maggio 2026».
String shuttlemareFormatLongItalianDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${kShuttlemareWeekdayNames[d.weekday - 1]} '
      '${d.day} '
      '${kShuttlemareMonthNames[d.month].toLowerCase()} '
      '${d.year}';
}

/// Chiave giorno locale `yyyyMMdd` per lookup calendario.
int shuttlemareDateKey(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.year * 10000 + d.month * 100 + d.day;
}

/// Giorni di servizio Shuttlemare — stagione 2026 (Aprile–Settembre).
Set<int> buildShuttlemareActiveDateKeys() {
  final keys = <int>{};
  void add(int year, int month, int day) {
    keys.add(shuttlemareDateKey(DateTime(year, month, day)));
  }

  add(2026, 4, 25);
  add(2026, 4, 26);

  for (final day in [1, 2, 3, 9, 10, 16, 17, 23, 24, 30, 31]) {
    add(2026, 5, day);
  }

  add(2026, 6, 1);
  add(2026, 6, 2);
  for (var day = 6; day <= 30; day++) {
    add(2026, 6, day);
  }

  for (var day = 1; day <= 31; day++) {
    add(2026, 7, day);
    add(2026, 8, day);
  }

  for (var day = 1; day <= 13; day++) {
    add(2026, 9, day);
  }

  return keys;
}

final kShuttlemareActiveDateKeys = buildShuttlemareActiveDateKeys();

bool shuttlemareIsActiveDay(DateTime date) {
  return kShuttlemareActiveDateKeys.contains(shuttlemareDateKey(date));
}

bool shuttlemareIsToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

bool shuttlemareIsWithinServiceHours(DateTime dateTime) {
  final minutes = dateTime.hour * 60 + dateTime.minute;
  return minutes >= kShuttlemareServiceStartMinutes &&
      minutes <= kShuttlemareServiceEndMinutes;
}

enum ShuttlemareTodayStatus {
  activeNow,
  activeDayOffHours,
  inactiveDay,
}

ShuttlemareTodayStatus shuttlemareTodayStatus(DateTime now) {
  if (!shuttlemareIsActiveDay(now)) {
    return ShuttlemareTodayStatus.inactiveDay;
  }
  if (shuttlemareIsWithinServiceHours(now)) {
    return ShuttlemareTodayStatus.activeNow;
  }
  return ShuttlemareTodayStatus.activeDayOffHours;
}

int shuttlemareCalendarRowCount(DateTime month) {
  final firstWeekday = DateTime(month.year, month.month, 1).weekday;
  final leadingEmpty = firstWeekday - DateTime.monday;
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  return ((leadingEmpty + daysInMonth) / 7).ceil();
}

/// Mesi mostrati nel calendario scorrevole (Aprile–Settembre 2026).
final kShuttlemareCalendarMonths = [
  DateTime(2026, 4),
  DateTime(2026, 5),
  DateTime(2026, 6),
  DateTime(2026, 7),
  DateTime(2026, 8),
  DateTime(2026, 9),
];

const kShuttlemareWeekdayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

const kShuttlemareMonthNames = [
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

class ShuttlemareOnboardRuleGroup {
  const ShuttlemareOnboardRuleGroup({
    required this.title,
    required this.bullets,
  });

  final String title;
  final List<String> bullets;
}

const _kShuttlemareOnboardIntroStatic =
    'Minibus fino a 18 passeggeri, riconoscibili dal logo Shuttlemare.';

String get kShuttlemareOnboardIntro => NavettaContentSync.text(
  StartContentId.navettaShuttlemare,
  'onboardIntro',
  fallback: _kShuttlemareOnboardIntroStatic,
);

const _kShuttlemareOnboardRuleGroupsStatic = [
  ShuttlemareOnboardRuleGroup(
    title: 'Accessibilità e comfort',
    bullets: [
      'Mezzi accessibili in sedia a rotelle selezionando l\'opzione in fase di prenotazione.',
      'Il passeggino deve essere chiuso e caricato nel bagagliaio.',
      'È necessario prenotare anche per il bambino.',
    ],
  ),
  ShuttlemareOnboardRuleGroup(
    title: 'Animali e condizioni di viaggio',
    bullets: [
      'Non è consentito trasportare animali, neppure di piccola taglia.',
      'Fanno eccezione i cani guida per non vedenti.',
      'Segui sempre le indicazioni fornite in app e dal personale di servizio.',
    ],
  ),
];

List<ShuttlemareOnboardRuleGroup> get kShuttlemareOnboardRuleGroups {
  final raw = NavettaContentSync.mapList(
    StartContentId.navettaShuttlemare,
    'onboardRuleGroups',
  );
  if (raw.isEmpty) return _kShuttlemareOnboardRuleGroupsStatic;
  return [
    for (final group in raw)
      ShuttlemareOnboardRuleGroup(
        title: '${group['title'] ?? ''}',
        bullets: [
          for (final b in group['bullets'] as List<dynamic>? ?? const [])
            '$b',
        ],
      ),
  ];
}

const _kShuttlemareBookingStepsStatic = [
  'Scarica l\'app My Start Romagna',
  'Scegli il punto di partenza e la destinazione (zona arancione ↔ zona azzurra)',
  'Seleziona il numero di passeggeri (max 5) e conferma',
  'Raggiungi la fermata del bus indicata nell\'app',
  'Sali su Shuttlemare e segui il mezzo sulla mappa',
];

List<String> get kShuttlemareBookingSteps => NavettaContentSync.strings(
  StartContentId.navettaShuttlemare,
  'bookingSteps',
  fallback: _kShuttlemareBookingStepsStatic,
);

class ShuttlemareParkingLot {
  const ShuttlemareParkingLot({
    required this.name,
    required this.address,
    this.unavailable = false,
  });

  final String name;
  final String address;
  final bool unavailable;
}

const _kShuttlemareParkingLotsStatic = [
  ShuttlemareParkingLot(
    name: 'Ponte di Tiberio',
    address: 'Viale Tiberio, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Caduti di Marzabotto',
    address: 'Via Caduti di Marzabotto 36, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Settebello',
    address: 'Via Roma 70, 47921 Rimini RN',
    unavailable: true,
  ),
  ShuttlemareParkingLot(
    name: 'Fantoni',
    address: 'Via Giovanni Fantoni, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Sindacati',
    address: 'Via Staccoli, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Clementini',
    address: 'Largo Martiri d\'Ungheria, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Chiabrera',
    address: 'Via Chiabrera, 47921 Rimini RN',
  ),
  ShuttlemareParkingLot(
    name: 'Palacongressi',
    address: 'Via della Fiera 23, 47923 Rimini RN',
  ),
];

List<ShuttlemareParkingLot> get kShuttlemareParkingLots {
  final raw = NavettaContentSync.mapList(
    StartContentId.navettaShuttlemare,
    'parkingLots',
  );
  if (raw.isEmpty) return _kShuttlemareParkingLotsStatic;
  return [
    for (final lot in raw)
      ShuttlemareParkingLot(
        name: '${lot['name'] ?? ''}',
        address: '${lot['address'] ?? ''}',
        unavailable: lot['unavailable'] == true,
      ),
  ];
}

class ShuttlemareHelpLink {
  const ShuttlemareHelpLink({
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

final kShuttlemareHelpLinks = [
  ShuttlemareHelpLink(
    title: 'Telefono',
    subtitle: '0541 300999',
    uri: Uri(scheme: 'tel', path: '0541300999'),
    icon: Icons.phone_rounded,
  ),
  ShuttlemareHelpLink(
    title: 'Email',
    subtitle: 'shuttlemare@startromagna.it',
    uri: Uri(
      scheme: 'mailto',
      path: 'shuttlemare@startromagna.it',
    ),
    icon: Icons.mail_outline_rounded,
  ),
  ShuttlemareHelpLink(
    title: 'Servizio Clienti',
    subtitle: 'Vai ai contatti',
    icon: Icons.support_agent_rounded,
    opensContattiPage: true,
  ),
];

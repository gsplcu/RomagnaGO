/// Contenuti servizio [Navetto Mare 2026](https://www.startromagna.it/navetto-mare-2026/).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'navette_cesenatico_data.dart';
import 'start_content/navetta_content_sync.dart';
import 'start_content/start_content_id.dart';

/// Palette pagina Navetto Mare (tema chiaro, accento azzurro ufficiale).
abstract final class NavettoMareColors {
  static const accent = Color(0xFF30B8F5);
  static const accentDark = Color(0xFF1689BE);
  static const surface = Colors.white;
  static const card = Colors.white;
  static const cardBorder = Color(0xFFB8E6FA);
  static const text = Color(0xFF1F2937);
  static const textMuted = Color(0xFF6B7280);
  static const todayRing = Color(0xFFE53935);
}

const kNavettoMareBannerAsset = 'assets/banner-navetto-mare.webp';
const kNavettoMareMapAsset = 'assets/mappa_navetto.webp';
const kNavettoMareOrariAsset = 'assets/data/navettomare_orari_2026.json';

const kNavettoMareOsmHotTileUrl = kNavettaCesenaticoOsmHotTileUrl;
const kNavettoMareOsmHotSubdomains = kNavettaCesenaticoOsmHotSubdomains;

const kNavettoMareWeekdayNames = [
  'lunedì',
  'martedì',
  'mercoledì',
  'giovedì',
  'venerdì',
  'sabato',
  'domenica',
];

const kNavettoMareWeekdayLabels = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

const kNavettoMareMonthNames = [
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

/// Mesi mostrati nel calendario scorrevole (Aprile–Settembre 2026).
final kNavettoMareCalendarMonths = [
  DateTime(2026, 4),
  DateTime(2026, 5),
  DateTime(2026, 6),
  DateTime(2026, 7),
  DateTime(2026, 8),
  DateTime(2026, 9),
];

int navettomareDateKey(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.year * 10000 + d.month * 100 + d.day;
}

String navettomareDateIso(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String navettomareFormatLongItalianDate(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return '${kNavettoMareWeekdayNames[d.weekday - 1]} '
      '${d.day} '
      '${kNavettoMareMonthNames[d.month].toLowerCase()} '
      '${d.year}';
}

/// Giorni di servizio Navetto Mare — calendario pubblicato 2026.
Set<int> buildNavettoMareActiveDateKeys() {
  final keys = <int>{};
  void add(int year, int month, int day) {
    keys.add(navettomareDateKey(DateTime(year, month, day)));
  }

  add(2026, 4, 25);
  add(2026, 4, 26);

  for (final day in [1, 2, 3, 9, 10, 16, 17, 23, 24, 30, 31]) {
    add(2026, 5, day);
  }

  for (final day in [
    1,
    2,
    5,
    6,
    7,
    9,
    10,
    11,
    12,
    13,
    14,
    19,
    20,
    21,
    26,
    27,
    28,
  ]) {
    add(2026, 6, day);
  }

  for (final day in [3, 4, 5, 10, 11, 12, 17, 18, 19, 22, 23, 24, 25, 26, 31]) {
    add(2026, 7, day);
  }

  for (final day in [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    28,
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

final kNavettoMareActiveDateKeys = buildNavettoMareActiveDateKeys();

bool navettomareIsActiveDay(DateTime date) {
  return kNavettoMareActiveDateKeys.contains(navettomareDateKey(date));
}

bool navettomareIsToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

int navettomareCalendarRowCount(DateTime month) {
  final firstWeekday = DateTime(month.year, month.month, 1).weekday;
  final leadingEmpty = firstWeekday - DateTime.monday;
  final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
  return ((leadingEmpty + daysInMonth) / 7).ceil();
}

enum NavettoMareLine { marina, punta }

extension NavettoMareLineX on NavettoMareLine {
  String get lineCode => switch (this) {
    NavettoMareLine.marina => '65',
    NavettoMareLine.punta => '66',
  };

  String get label => switch (this) {
    NavettoMareLine.marina => 'Marina di Ravenna (65)',
    NavettoMareLine.punta => 'Punta Marina (66)',
  };

  String get shortLabel => switch (this) {
    NavettoMareLine.marina => 'Linea 65',
    NavettoMareLine.punta => 'Linea 66',
  };
}

enum NavettoMareDirection { forward, reverse }

class NavettoMareRouteChoice {
  const NavettoMareRouteChoice({
    required this.line,
    required this.direction,
    required this.label,
    required this.gpxAsset,
    required this.origin,
    required this.destination,
  });

  final NavettoMareLine line;
  final NavettoMareDirection direction;
  final String label;
  final String gpxAsset;
  final NavettoMareTerminal origin;
  final NavettoMareTerminal destination;
}

class NavettoMareTerminal {
  const NavettoMareTerminal({
    required this.code,
    required this.displayName,
    required this.point,
  });

  final String code;
  final String displayName;
  final LatLng point;
}

const kNavettoMareTerminalParkTrieste = NavettoMareTerminal(
  code: 'M1',
  displayName: 'Park Trieste',
  point: LatLng(44.452168880724905, 12.281922609473716),
);

const kNavettoMareTerminalParkMarchesato = NavettoMareTerminal(
  code: 'M12',
  displayName: 'Park Marchesato',
  point: LatLng(44.47941535586309, 12.271423156573789),
);

const kNavettoMareTerminalLungomareColombo = NavettoMareTerminal(
  code: 'P10',
  displayName: 'Lungomare Colombo 40',
  point: LatLng(44.44433013539352, 12.294628873193995),
);

const kNavettoMareParkTriesteP1 = NavettoMareTerminal(
  code: 'P1',
  displayName: 'Park Trieste',
  point: LatLng(44.452168880724905, 12.281922609473716),
);

const kNavettoMareGpxMarinaM1M12 =
    'assets/data/GPX Navetto Mare/Navetto Mare Marina M1 _ M12 (65).gpx';
const kNavettoMareGpxMarinaM12M1 =
    'assets/data/GPX Navetto Mare/Navetto Mare Marina M12 - M1 (65).gpx';
const kNavettoMareGpxPuntaP1P10 =
    'assets/data/GPX Navetto Mare/Navetto Mare Punta P1 - P10 (66).gpx';
const kNavettoMareGpxPuntaP10P1 =
    'assets/data/GPX Navetto Mare/Navetto Mare Punta P10 - P1 (66).gpx';

NavettoMareRouteChoice navettomareRouteChoice({
  required NavettoMareLine line,
  required NavettoMareDirection direction,
}) {
  return switch (line) {
    NavettoMareLine.marina => switch (direction) {
      NavettoMareDirection.forward => const NavettoMareRouteChoice(
        line: NavettoMareLine.marina,
        direction: NavettoMareDirection.forward,
        label: 'M1 Park Trieste → M12 Park Marchesato',
        gpxAsset: kNavettoMareGpxMarinaM1M12,
        origin: kNavettoMareTerminalParkTrieste,
        destination: kNavettoMareTerminalParkMarchesato,
      ),
      NavettoMareDirection.reverse => const NavettoMareRouteChoice(
        line: NavettoMareLine.marina,
        direction: NavettoMareDirection.reverse,
        label: 'M12 Park Marchesato → M1 Park Trieste',
        gpxAsset: kNavettoMareGpxMarinaM12M1,
        origin: kNavettoMareTerminalParkMarchesato,
        destination: kNavettoMareTerminalParkTrieste,
      ),
    },
    NavettoMareLine.punta => switch (direction) {
      NavettoMareDirection.forward => const NavettoMareRouteChoice(
        line: NavettoMareLine.punta,
        direction: NavettoMareDirection.forward,
        label: 'P1 Park Trieste → P10 Lungomare Colombo 40',
        gpxAsset: kNavettoMareGpxPuntaP1P10,
        origin: kNavettoMareParkTriesteP1,
        destination: kNavettoMareTerminalLungomareColombo,
      ),
      NavettoMareDirection.reverse => const NavettoMareRouteChoice(
        line: NavettoMareLine.punta,
        direction: NavettoMareDirection.reverse,
        label: 'P10 Lungomare Colombo 40 → P1 Park Trieste',
        gpxAsset: kNavettoMareGpxPuntaP10P1,
        origin: kNavettoMareTerminalLungomareColombo,
        destination: kNavettoMareParkTriesteP1,
      ),
    },
  };
}

List<NavettoMareTerminal> navettomareTerminalsForRoute(
  NavettoMareRouteChoice route,
) {
  return [route.origin, route.destination];
}

class NavettoMareHelpLink {
  const NavettoMareHelpLink({
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

final kNavettoMareHelpLinks = [
  NavettoMareHelpLink(
    title: 'Telefono',
    subtitle: '199.11.55.77',
    uri: Uri(scheme: 'tel', path: '199115577'),
    icon: Icons.phone_rounded,
  ),
  NavettoMareHelpLink(
    title: 'WhatsApp',
    subtitle: 'Chatta con noi',
    uri: Uri.parse('https://wa.me/393316566555'),
    icon: Icons.chat_rounded,
  ),
  NavettoMareHelpLink(
    title: 'Servizio Clienti',
    subtitle: 'Vai ai contatti',
    icon: Icons.support_agent_rounded,
    opensContattiPage: true,
  ),
];

typedef NavettoMareScheduleData = Map<String, Map<String, List<String>>>;

Future<NavettoMareScheduleData> loadNavettoMareSchedules() async {
  final raw = await rootBundle.loadString(kNavettoMareOrariAsset);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final out = <String, Map<String, List<String>>>{};
  for (final entry in decoded.entries) {
    final dayMap = entry.value as Map<String, dynamic>;
    out[entry.key] = {
      for (final lineEntry in dayMap.entries)
        lineEntry.key: List<String>.from(lineEntry.value as List<dynamic>),
    };
  }
  return out;
}

List<String> navettomareTimesFor({
  required NavettoMareScheduleData schedules,
  required DateTime date,
  required NavettoMareLine line,
}) {
  final serviceDay = DateTime(date.year, date.month, date.day);
  final currentKey = navettomareDateIso(serviceDay);
  final nextKey = navettomareDateIso(
    serviceDay.add(const Duration(days: 1)),
  );

  final rawCurrent = schedules[currentKey]?[line.lineCode] ?? const [];
  final rawNext = schedules[nextKey]?[line.lineCode] ?? const [];

  final diurni =
      rawCurrent.where((t) => !navettomareIsNightServiceTime(t)).toList();
  final notturni =
      rawNext.where(navettomareIsNightServiceTime).toList();

  final merged = [...diurni, ...notturni]
    ..sort(
      (a, b) => navettomareDisplaySortKey(a).compareTo(
        navettomareDisplaySortKey(b),
      ),
    );
  return merged;
}

/// Orario compreso nella fascia notturna di servizio (00:00–05:00).
bool navettomareIsNightServiceTime(String hm) {
  final minutes = navettomareTimeSortKey(hm);
  return minutes >= 0 && minutes <= 5 * 60;
}

/// Chiave di ordinamento in UI: le corse 00:00–05:00 seguono quelle serali.
int navettomareDisplaySortKey(String hm) {
  final minutes = navettomareTimeSortKey(hm);
  if (navettomareIsNightServiceTime(hm)) {
    return minutes + 24 * 60;
  }
  return minutes;
}

/// Giorno di servizio «attivo» in base all’ora corrente (flessione fino alle 05:00).
DateTime navettomareActiveServiceDay([DateTime? now]) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  if (n.hour < 5) {
    return today.subtract(const Duration(days: 1));
  }
  return today;
}

/// Corse ancora da effettuarsi nel giorno di servizio attivo.
List<String> navettomareUpcomingTimesFor({
  required NavettoMareScheduleData schedules,
  required NavettoMareLine line,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final serviceDay = navettomareActiveServiceDay(n);
  final all = navettomareTimesFor(
    schedules: schedules,
    date: serviceDay,
    line: line,
  );
  if (all.isEmpty) return const [];

  var compareNow = n.hour * 60 + n.minute;
  if (n.hour < 5) {
    compareNow += 24 * 60;
  }

  return all
      .where((t) => navettomareDisplaySortKey(t) >= compareNow)
      .toList(growable: false);
}

({List<String> daytime, List<String> night}) navettomarePartitionDisplayTimes(
  List<String> times,
) {
  final daytime = <String>[];
  final night = <String>[];
  for (final time in times) {
    if (navettomareIsNightServiceTime(time)) {
      night.add(time);
    } else {
      daytime.add(time);
    }
  }
  return (daytime: daytime, night: night);
}

int navettomareTimeSortKey(String hm) {
  final parts = hm.split(':');
  if (parts.length != 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

const _kNavettoMareHeroSubtitleStatic =
    'Parcheggi, mare e collegamenti gratuiti tra i parcheggi scambiatori e il litorale di Ravenna.';

const _kNavettoMareHeroServiceNoteStatic =
    'Servizio gratuito finanziato dal Comune di Ravenna, attivo dal 25 aprile al 13 settembre 2026 sulle linee 65 e 66.';

const _kNavettoMareHeroChipsStatic = ['Gratis', 'Linee 65 e 66', '25 apr – 13 set'];

String get kNavettoMareHeroTitle => NavettaContentSync.text(
  StartContentId.navettaNavettomare,
  'heroTitle',
  fallback: 'Navetto Mare',
);

String get kNavettoMareHeroSubtitle => NavettaContentSync.text(
  StartContentId.navettaNavettomare,
  'heroSubtitle',
  fallback: _kNavettoMareHeroSubtitleStatic,
);

String get kNavettoMareHeroServiceNote => NavettaContentSync.text(
  StartContentId.navettaNavettomare,
  'heroServiceNote',
  fallback: _kNavettoMareHeroServiceNoteStatic,
);

List<String> get kNavettoMareHeroChips => NavettaContentSync.strings(
  StartContentId.navettaNavettomare,
  'heroChips',
  fallback: _kNavettoMareHeroChipsStatic,
);
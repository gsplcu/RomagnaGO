// Calendario esplicito Start Romagna: `Open Data/*/services.json` → assets/data/service_calendars.json
// (service_id → elenco date YYYYMMDD in cui la variante di servizio è attiva).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ServiceCalendarIndex {
  ServiceCalendarIndex._(this._byBasin, this.loadFailed);

  /// Bacino (FC, RA, RN) → service_id → date valide.
  final Map<String, Map<String, Set<String>>> _byBasin;
  final bool loadFailed;

  factory ServiceCalendarIndex.empty({bool failed = false}) =>
      ServiceCalendarIndex._({}, failed);

  static ServiceCalendarIndex? _cached;
  static Future<ServiceCalendarIndex>? _loading;

  static Future<ServiceCalendarIndex> load() {
    final cached = _cached;
    if (cached != null) return Future.value(cached);
    return _loading ??= _loadInternal().then((idx) {
      _cached = idx;
      return idx;
    });
  }

  static Future<ServiceCalendarIndex> _loadInternal() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/service_calendars.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final byBasin = <String, Map<String, Set<String>>>{};
      for (final basin in const ['FC', 'RA', 'RN']) {
        final dyn = decoded[basin];
        if (dyn is! Map<String, dynamic>) continue;
        final inner = <String, Set<String>>{};
        for (final e in dyn.entries) {
          final sid = e.key.trim();
          final list = e.value;
          if (sid.isEmpty || list is! List) continue;
          final set = <String>{};
          for (final x in list) {
            if (x is String && RegExp(r'^\d{8}$').hasMatch(x)) set.add(x);
          }
          if (set.isNotEmpty) inner[sid] = set;
        }
        byBasin[basin] = inner;
      }
      return ServiceCalendarIndex._(byBasin, false);
    } catch (e, st) {
      debugPrint('ServiceCalendarIndex.load: $e\n$st');
      return ServiceCalendarIndex.empty(failed: true);
    }
  }

  /// File presente e parsato (anche se un bacino manca).
  bool get isUsable => !loadFailed && _byBasin.isNotEmpty;

  static String yyyymmddLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  /// True se almeno un servizio è definito per questa data (calendario «copre» il giorno).
  bool calendarCoversLocalDay(DateTime localDay) {
    if (!isUsable) return false;
    final ymd = yyyymmddLocal(localDay);
    for (final m in _byBasin.values) {
      for (final dates in m.values) {
        if (dates.contains(ymd)) return true;
      }
    }
    return false;
  }

  /// Corsa attiva in [localDay] (solo giorno, orario ignorato) per bacino + service_id GTFS.
  bool serviceRunsOn(String basinUpper, String serviceId, DateTime localDay) {
    final ymd = yyyymmddLocal(localDay);
    final map = _byBasin[basinUpper.trim().toUpperCase()];
    if (map == null) return false;
    final dates = map[serviceId.trim()];
    if (dates == null) return false;
    return dates.contains(ymd);
  }

  /// Euristica su ~12 settimane: utile solo per etichette UI (profili feriale vs fine settimana vs misto).
  TransitServiceProfile guessServiceProfile(
    String basinUpper,
    String serviceId,
    DateTime fromLocalDay,
  ) {
    if (!isUsable ||
        basinUpper.trim().isEmpty ||
        serviceId.trim().isEmpty) {
      return TransitServiceProfile.dailyOrMixed;
    }
    final basin = basinUpper.trim().toUpperCase();
    final sid = serviceId.trim();
    var weekdays = 0;
    var weekend = 0;
    final origin = DateTime(
      fromLocalDay.year,
      fromLocalDay.month,
      fromLocalDay.day,
    );
    const horizon = 84;
    for (var i = 0; i < horizon; i++) {
      final d = origin.add(Duration(days: i));
      if (!serviceRunsOn(basin, sid, d)) continue;
      final wd = d.weekday;
      if (wd == DateTime.saturday || wd == DateTime.sunday) {
        weekend++;
      } else {
        weekdays++;
      }
    }
    if (weekdays == 0 && weekend == 0) {
      return TransitServiceProfile.dailyOrMixed;
    }
    // Soglia alta: i profili «quasi bilanciati» restano «misto», meno confusione in UI.
    const ratio = 1.45;
    if (weekend >= weekdays * ratio) return TransitServiceProfile.mostlyWeekend;
    if (weekdays >= weekend * ratio) return TransitServiceProfile.mostlyWeekday;
    return TransitServiceProfile.dailyOrMixed;
  }
}

/// Profilo approssimativo della variante [service_id] (per sezioni nel foglio orari «Pianificazione»).
enum TransitServiceProfile {
  mostlyWeekday,
  mostlyWeekend,
  dailyOrMixed,
}

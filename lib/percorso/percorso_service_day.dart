/// Giornata di servizio TPL Romagna (convenzione operativa locale).
///
/// Le corse tra le **00:00** e le **04:00** (escluse le 04:00) appartengono
/// al calendario GTFS del **giorno precedente** e usano orari GTFS con ore ≥ 24
/// quando necessario.
abstract final class PercorsoServiceDay {
  /// Fine fascia notturna (esclusiva): `hour < nightServiceEndHour`.
  static const int nightServiceEndHour = 4;

  /// Calendario GTFS su cui verificare `service_id` e trip index.
  static DateTime plannerServiceDay(DateTime departAtLocal) {
    final civil = DateTime(
      departAtLocal.year,
      departAtLocal.month,
      departAtLocal.day,
    );
    if (departAtLocal.hour < nightServiceEndHour) {
      return civil.subtract(const Duration(days: 1));
    }
    return civil;
  }

  /// Secondi dall'inizio della giornata di servizio per RAPTOR / trip index.
  static int departureSecondsSinceServiceMidnight(DateTime departAtLocal) {
    final h = departAtLocal.hour;
    final m = departAtLocal.minute;
    final s = departAtLocal.second;
    if (h < nightServiceEndHour) {
      return (24 + h) * 3600 + m * 60 + s;
    }
    return h * 3600 + m * 60 + s;
  }

  /// Mezzanotte locale della giornata di servizio (anchor per etichette).
  static DateTime serviceMidnightLocal(DateTime departAtLocal) {
    final day = plannerServiceDay(departAtLocal);
    return DateTime(day.year, day.month, day.day);
  }

  /// `true` se l'utente ha scelto un orario nella fascia 00:00–03:59.
  static bool isNightServiceDeparture(DateTime departAtLocal) =>
      departAtLocal.hour < nightServiceEndHour;
}

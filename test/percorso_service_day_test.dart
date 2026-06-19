import 'package:RomagnaGO/percorso/percorso_service_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PercorsoServiceDay', () {
    test('02:30 appartiene al giorno di servizio precedente', () {
      final depart = DateTime(2026, 5, 28, 2, 30);
      final day = PercorsoServiceDay.plannerServiceDay(depart);
      expect(day, DateTime(2026, 5, 27));
      expect(
        PercorsoServiceDay.departureSecondsSinceServiceMidnight(depart),
        (26 * 3600) + (30 * 60),
      );
    });

    test('04:00 è già sul giorno civile corrente', () {
      final depart = DateTime(2026, 5, 28, 4, 0);
      expect(
        PercorsoServiceDay.plannerServiceDay(depart),
        DateTime(2026, 5, 28),
      );
      expect(
        PercorsoServiceDay.departureSecondsSinceServiceMidnight(depart),
        4 * 3600,
      );
    });
  });
}

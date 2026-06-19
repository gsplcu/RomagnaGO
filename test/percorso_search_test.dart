import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PercorsoSearchService', () {
    late PercorsoSearchService? svc;

    setUpAll(() async {
      svc = await PercorsoSearchService.load();
    });

    test('loads planner index', () {
      expect(svc, isNotNull);
      expect(svc!.planner.loadFailed, isFalse);
    });

    test('Cesenatico admin → Cesena admin martedì 11:00 trova S094', () async {
      final s = svc!;
      const cesenatico = LatLng(44.1999283, 12.3969692);
      const cesena = LatLng(44.1363520, 12.2422442);

      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'Cesenatico',
          point: cesenatico,
        ),
        to: const PercorsoEndpoint(label: 'Cesena', point: cesena),
        departAt: DateTime(2026, 6, 15, 11, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(result.hasTransit, isTrue, reason: result.userHint);
      final ride = result.itineraries.first.legs
          .where((l) => l.kind == PercorsoLegKind.ride)
          .toList();
      expect(ride, isNotEmpty);
      expect(
        ride.any((l) => l.lineLabel?.contains('94') == true),
        isTrue,
        reason: 'Expected linea 94/S094, got ${ride.map((l) => l.lineLabel)}',
      );
      expect(
        result.itineraries.length,
        lessThanOrEqualTo(2),
        reason: 'Evita alternative inutili oltre al percorso migliore',
      );
    });

    test('V.le Roma Cesenatico → Montefiore Cesena con cambio', () async {
      final s = svc!;
      const vleRoma = LatLng(44.1999833410837, 12.4035066567523);
      const montefiore = LatLng(44.1438199933212, 12.2606218216868);

      final result = await s.planDetailed(
        from: PercorsoEndpoint(
          label: 'Cesenatico V.le Roma',
          point: vleRoma,
          stopId: '10732',
        ),
        to: const PercorsoEndpoint(
          label: 'Montefiore, Cesena',
          point: montefiore,
        ),
        departAt: DateTime(2026, 6, 15, 11, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(result.hasTransit, isTrue, reason: result.userHint);
      final best = result.itineraries.first;
      expect(best.walkMeters, lessThan(2200));
      expect(result.itineraries.length, lessThanOrEqualTo(3));
    });

    test('Cesenatico → Forlì trova combinazione 94+92', () async {
      final s = svc!;
      const cesenatico = LatLng(44.1999283, 12.3969692);
      const forli = LatLng(44.2227, 12.0407);

      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'Cesenatico',
          point: cesenatico,
        ),
        to: const PercorsoEndpoint(label: 'Forlì', point: forli),
        departAt: DateTime(2026, 6, 15, 8, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(result.hasTransit, isTrue, reason: result.userHint);

      // At least one itinerary must contain BOTH line 94 AND line 92 legs.
      final combo = result.itineraries.where((it) {
        final rideLabels = it.legs
            .where((l) => l.kind == PercorsoLegKind.ride)
            .map((l) => l.lineLabel ?? '')
            .toList();
        return rideLabels.any((l) => l.contains('94')) &&
            rideLabels.any((l) => l.contains('92'));
      }).toList();
      expect(combo, isNotEmpty,
          reason: 'Expected a single itinerary with both lines 94 and 92');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Cesenatico → Rimini mattina può usare 94+4 via S.Mauro Mare', () async {
      final s = svc!;
      const cesenatico = LatLng(44.1999283, 12.3969692);
      const rimini = LatLng(44.0594, 12.5683);

      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'Cesenatico',
          point: cesenatico,
        ),
        to: const PercorsoEndpoint(label: 'Rimini', point: rimini),
        departAt: DateTime(2026, 6, 15, 8, 30),
        profile: PercorsoProfile.fastest,
      );

      expect(result.hasTransit, isTrue, reason: result.userHint);
      final combo = result.itineraries.where((it) {
        final rides = it.legs
            .where((l) => l.kind == PercorsoLegKind.ride)
            .map((l) => l.lineLabel ?? '')
            .toList();
        return rides.any((l) => l.contains('94')) &&
            rides.any((l) => RegExp(r'Linea\s+4\b').hasMatch(l));
      });
      expect(
        combo,
        isNotEmpty,
        reason:
            'Atteso almeno un itinerario 94+4; opzioni: '
            '${result.itineraries.map((it) => it.legs.where((l) => l.kind == PercorsoLegKind.ride).map((l) => l.lineLabel).toList())}',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Cesenatico → Savignano: no micro-cambio 166 inutile', () async {
      final s = svc!;
      const cesenatico = LatLng(44.1999283, 12.3969692);
      const savignanoFs = LatLng(44.0952289060715, 12.4038916729027);

      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'Cesenatico',
          point: cesenatico,
        ),
        to: const PercorsoEndpoint(
          label: 'Savignano Fs',
          point: savignanoFs,
        ),
        departAt: DateTime(2026, 6, 15, 11, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(result.hasTransit, isTrue, reason: result.userHint);
      final best = result.itineraries.first;
      final rides = best.legs
          .where((l) => l.kind == PercorsoLegKind.ride)
          .map((l) => l.lineLabel ?? '')
          .toList();
      expect(
        rides.join(' > '),
        isNot(contains('166')),
        reason: 'Evita cambio micro su 166: $rides',
      );
    });

    test('Cesenatico → Savignano: diagnostica linea 165', () async {
      final s = svc!;
      const cesenaticoStop = '10732';
      const savignanoFsStop = '11393';
      final departAt = DateTime(2026, 6, 15, 11, 0);
      const cesenatico = LatLng(44.1999283, 12.3969692);
      const savignanoFs = LatLng(44.0952289060715, 12.4038916729027);

      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'Cesenatico',
          point: cesenatico,
          stopId: cesenaticoStop,
        ),
        to: const PercorsoEndpoint(
          label: 'Savignano Fs',
          point: savignanoFs,
          stopId: savignanoFsStop,
        ),
        departAt: departAt,
        profile: PercorsoProfile.fastest,
      );

      final has165Option = result.itineraries.any(
        (it) => it.legs.any(
          (l) =>
              l.kind == PercorsoLegKind.ride &&
              (l.lineLabel?.contains('165') ?? false),
        ),
      );

      var f165DirectTrips = 0;
      for (final tid in s.planner.tripIdsAtStop(cesenaticoStop)) {
        final trip = s.planner.trips[tid];
        if (trip == null || trip.routeKey != 'FC|F165') continue;
        final board = trip.stopById(cesenaticoStop);
        final alight = trip.stopById(savignanoFsStop);
        if (board == null || alight == null) continue;
        if (alight.sequence <= board.sequence) continue;
        if (board.depSec < 11 * 3600 || board.depSec >= 13 * 3600) continue;
        f165DirectTrips++;
      }

      expect(
        s.planner.trips.values.any((t) => t.routeKey == 'FC|F165'),
        isTrue,
        reason: 'FC|F165 presente nel trip_index',
      );

      if (f165DirectTrips == 0) {
        expect(
          has165Option,
          isFalse,
          reason:
              'Nessuna corsa F165 11–13 da Cesenatico a Savignano Fs: '
              'normale che il planner non proponga la 165',
        );
      } else {
        expect(
          has165Option,
          isTrue,
          reason:
              'Esistono $f165DirectTrips corse F165 dirette nell\'orario: '
              'dovrebbero comparire tra le opzioni',
        );
      }
    });

    test('fallback a piedi se nessun TPL', () async {
      final s = svc!;
      final result = await s.planDetailed(
        from: const PercorsoEndpoint(
          label: 'A',
          point: LatLng(44.2, 12.4),
        ),
        to: const PercorsoEndpoint(
          label: 'B',
          point: LatLng(44.14, 12.24),
        ),
        departAt: DateTime(2099, 1, 1, 8, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(result.itineraries, isNotEmpty);
      expect(result.userHint, isNotNull);
    });
  });
}

import 'package:RomagnaGO/percorso/percorso_index.dart';
import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PercorsoSearchService svc;

  setUpAll(() async {
    final loaded = await PercorsoSearchService.load();
    expect(loaded, isNotNull);
    svc = loaded!;
  });

  const leoneIds = {'13721', '13722'};
  const pleTrentoIds = {'10821', '10822'};

  bool isImpossibleLeoneToPleTrento(PercorsoLeg leg) {
    if (leg.kind != PercorsoLegKind.ride) return false;
    if (leg.routeKey != 'FC|1-2CO') return false;
    final board = leg.boardStopId;
    final alight = leg.alightStopId;
    if (board == null || alight == null) return false;
    if (!leoneIds.contains(board) || !pleTrentoIds.contains(alight)) {
      return false;
    }
    final trip = leg.tripId == null ? null : svc.planner.trips[leg.tripId];
    if (trip == null) return true;
    return !tripServesRideSegment(
      trip,
      boardStopId: board,
      alightStopId: alight,
      boardSeq: leg.boardSeq,
      alightSeq: leg.alightSeq,
    );
  }

  bool allRideLegsValidOnTrip(PercorsoItinerary it) {
    for (final leg in it.legs) {
      if (leg.kind != PercorsoLegKind.ride) continue;
      final tid = leg.tripId;
      final board = leg.boardStopId;
      final alight = leg.alightStopId;
      if (tid == null || board == null || alight == null) return false;
      final trip = svc.planner.trips[tid];
      if (trip == null) return false;
      if (!tripServesRideSegment(
        trip,
        boardStopId: board,
        alightStopId: alight,
        boardSeq: leg.boardSeq,
        alightSeq: leg.alightSeq,
      )) {
        return false;
      }
    }
    return true;
  }

  test(
    'Gatteo Mare → Cesenatico venerdì 09:00: nessun mix Leone → P.le Trento su linea 4',
    () async {
      const gatteoMare = LatLng(44.1730044004041, 12.4352937073703);
      // Zona Bar Pasticceria Gasperoni / centro Cesenatico.
      const cesenatico = LatLng(44.1986, 12.3992);

      final r = await svc.planDetailed(
        from: const PercorsoEndpoint(label: 'Gatteo a Mare', point: gatteoMare),
        to: const PercorsoEndpoint(
          label: 'Bar Pasticceria Gasperoni, Cesenatico',
          point: cesenatico,
        ),
        departAt: DateTime(2026, 6, 19, 9, 0),
        profile: PercorsoProfile.fastest,
      );

      expect(r.hasTransit, isTrue, reason: r.userHint);

      for (final it in r.itineraries) {
        expect(
          allRideLegsValidOnTrip(it),
          isTrue,
          reason: 'Itinerario con segmenti non serviti dal tripId indicato',
        );
        for (final leg in it.legs) {
          expect(
            isImpossibleLeoneToPleTrento(leg),
            isFalse,
            reason:
                'Mix varianti 1-2CO: ${leg.lineLabel} '
                '${leg.boardStopId}→${leg.alightStopId} trip=${leg.tripId}',
          );
        }
      }

      final best = r.itineraries.first;
      final line4 = best.legs
          .where(
            (l) =>
                l.kind == PercorsoLegKind.ride &&
                l.routeKey == 'FC|1-2CO',
          )
          .toList();
      if (line4.isNotEmpty) {
        final leg = line4.first;
        final alight = leg.alightStopId;
        if (alight != null && pleTrentoIds.contains(alight)) {
          final board = leg.boardStopId;
          expect(
            board == null || !leoneIds.contains(board),
            isTrue,
            reason:
                'Se la linea 4 arriva a P.le Trento non può partire da Leone '
                '(variante feriale diversa)',
          );
        }
      }
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

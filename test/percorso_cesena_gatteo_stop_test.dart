import 'package:RomagnaGO/percorso/percorso_models.dart';
import 'package:RomagnaGO/percorso/percorso_search.dart';
import 'package:RomagnaGO/percorso/percorso_walk.dart';
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

  // Destinazione = fermata richiesta (Gatteo Mare 11800/11801). Il sistema deve
  // far scendere l'utente esattamente alla fermata target quando la corsa vi
  // transita, senza dirottarlo su una fermata più lontana (es. Leone).
  test('Cesena (indirizzo) -> fermata Gatteo Mare alights at target stop',
      () async {
    const cesena = LatLng(44.1391, 12.2431);
    const gatteoMare = LatLng(44.1730044004041, 12.4352937073703);

    final r = await svc.planDetailed(
      from: const PercorsoEndpoint(label: 'Cesena', point: cesena),
      to: const PercorsoEndpoint(
        label: 'Gatteo Mare',
        point: gatteoMare,
        stopId: '11800',
        stopName: 'Gatteo Mare',
        stopClusterIds: ['11800', '11801'],
      ),
      departAt: DateTime(2026, 6, 16, 9, 0),
      profile: PercorsoProfile.fastest,
    );

    // ignore: avoid_print
    print('\n=== Cesena -> Gatteo Mare ===');
    // ignore: avoid_print
    print('quality=${r.quality} hint=${r.userHint} n=${r.itineraries.length}');
    for (final it in r.itineraries) {
      // ignore: avoid_print
      print(
        '--- dur=${it.totalDuration.inMinutes}m walk=${it.walkMeters.toStringAsFixed(0)}m transfers=${it.transfers}',
      );
      for (final l in it.legs) {
        if (l.kind == PercorsoLegKind.ride) {
          // ignore: avoid_print
          print('  RIDE ${l.lineLabel} ${l.boardStopId}→${l.alightStopId}');
        } else if (l.kind == PercorsoLegKind.walk &&
            l.from != null &&
            l.to != null) {
          // ignore: avoid_print
          print(
            '  WALK "${l.title}" ${percorsoWalkEstimate(l.from!, l.to!).meters.toStringAsFixed(0)}m',
          );
        } else {
          // ignore: avoid_print
          print('  ${l.kind} "${l.title}" ${l.subtitle}');
        }
      }
    }

    expect(r.hasTransit, isTrue, reason: r.userHint);

    final it = r.itineraries.first;
    final lastRide =
        it.legs.where((l) => l.kind == PercorsoLegKind.ride).last;

    // L'ultima corsa deve scendere alla fermata richiesta (o palina gemella).
    expect(
      lastRide.alightStopId == '11800' || lastRide.alightStopId == '11801',
      isTrue,
      reason: 'alight=${lastRide.alightStopId}',
    );

    // Nessun lungo tragitto a piedi finale "di ritorno" verso la fermata.
    var egress = 0.0;
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.from != null &&
          l.to != null &&
          !l.title.contains('Cambio') &&
          l.subtitle.contains('Verso destinazione')) {
        egress += percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    expect(egress, lessThan(150), reason: 'egress=$egress');

    // Deve trovare l'ottimo «94 + linea 1/2» (1CO/2CO), come Google Maps, e
    // NON ripiegare su 146 diretta / 95+R con attese di ore.
    final rides = it.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.lineLabel ?? '')
        .toList();
    expect(rides.any((l) => l.contains('94')), isTrue, reason: '$rides');
    expect(
      rides.any((l) => l.contains('2') || l.contains('1')),
      isTrue,
      reason: '$rides',
    );
    expect(it.transfers, equals(1), reason: 'transfers=${it.transfers}');
    expect(
      it.totalDuration.inMinutes,
      lessThan(120),
      reason: 'dur=${it.totalDuration.inMinutes}m',
    );
  });
}

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

  void dump(String name, PercorsoPlanResult r) {
    // ignore: avoid_print
    print('\n=== $name ===');
    // ignore: avoid_print
    print('quality=${r.quality} hint=${r.userHint}');
    if (r.itineraries.isEmpty) return;
    final it = r.itineraries.first;
    // ignore: avoid_print
    print(
      'dur=${it.totalDuration.inMinutes}m walk=${it.walkMeters.toStringAsFixed(0)}m transfers=${it.transfers}',
    );
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.ride) {
        // ignore: avoid_print
        print(
          '  RIDE ${l.lineLabel} ${l.alightStopId}→${l.boardStopId}',
        );
      }
      if (l.kind == PercorsoLegKind.walk &&
          l.title.contains('Cambio') &&
          l.from != null &&
          l.to != null) {
        // ignore: avoid_print
        print(
          '  WALK cambio ${percorsoWalkEstimate(l.from!, l.to!).meters.toStringAsFixed(0)}m',
        );
      }
    }
  }

  test('TEST1 Cesenatico P.le Trento -> Santa Sofia 29/05 9:00', () async {
    const from = LatLng(44.1944465362708, 12.4018502577375);
    const to = LatLng(43.9476125586956, 11.9082208395099);
    final r = await svc.planDetailed(
      from: const PercorsoEndpoint(label: 'Cesenatico', point: from),
      to: const PercorsoEndpoint(label: 'Santa Sofia', point: to),
      departAt: DateTime(2026, 6, 16, 9, 0),
      profile: PercorsoProfile.fastest,
    );
    dump('TEST1', r);
    expect(r.hasTransit, isTrue, reason: r.userHint);
    final rides = r.itineraries.first.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.lineLabel ?? '')
        .join(',');
    expect(rides.contains('94'), isTrue, reason: 'rides: $rides');
    expect(rides.contains('92'), isTrue, reason: 'rides: $rides');
    expect(rides.contains('93'), isFalse, reason: 'rides: $rides');
    expect(rides.contains('133'), isFalse, reason: 'rides: $rides');
    expect(rides.contains('132'), isTrue, reason: 'rides: $rides');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('TEST2 Zadina -> Dovadola 29/05 14:00', () async {
    const zadina = LatLng(44.2210475341269, 12.380355066799);
    const dovadola = LatLng(44.1216594423061, 11.8880468330911);
    final r = await svc.planDetailed(
      from: const PercorsoEndpoint(label: 'Zadina', point: zadina),
      to: const PercorsoEndpoint(label: 'Dovadola', point: dovadola),
      departAt: DateTime(2026, 6, 16, 14, 0),
      profile: PercorsoProfile.fastest,
    );
    dump('TEST2', r);
    expect(r.hasTransit, isTrue, reason: r.userHint);
    final rides = r.itineraries.first.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.lineLabel ?? '')
        .join(',');
    expect(rides.contains('127'), isTrue, reason: 'rides: $rides');
    expect(r.itineraries.first.walkMeters, lessThan(2500));
    final f126 = r.itineraries.first.legs
        .where((l) => l.routeKey == 'FC|F126')
        .lastOrNull;
    expect(f126, isNotNull);
    final hubWalk = f126!.alightStopId == '1660'
        ? 0.0
        : percorsoWalkEstimate(f126.from!, f126.to!).meters;
    expect(hubWalk, lessThan(1200), reason: 'F126 alight ${f126.alightStopId}');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('TEST3 Cesenatico -> Rimini 28/05 12:00', () async {
    const cesenatico = LatLng(44.1999, 12.3970);
    const rimini = LatLng(44.0594, 12.5683);
    final r = await svc.planDetailed(
      from: const PercorsoEndpoint(label: 'Cesenatico', point: cesenatico),
      to: const PercorsoEndpoint(label: 'Rimini', point: rimini),
      departAt: DateTime(2026, 6, 15, 12, 0),
      profile: PercorsoProfile.fastest,
    );
    dump('TEST3', r);
    expect(r.hasTransit, isTrue, reason: r.userHint);
    final it = r.itineraries.first;
    final rideLabels = it.legs
        .where((l) => l.kind == PercorsoLegKind.ride)
        .map((l) => l.lineLabel ?? '')
        .toList();
    final hasCoastalBus = rideLabels.any(
      (l) =>
          l.contains('165') ||
          l.contains('168') ||
          l.contains('126') ||
          l.contains('2CO') ||
          l.contains('1CO'),
    );
    final has94And4 = rideLabels.any((l) => l.contains('94')) &&
        rideLabels.any((l) => RegExp(r'Linea\s+4\b').hasMatch(l));
    expect(
      hasCoastalBus || has94And4,
      isTrue,
      reason: 'Atteso corridoio costa o 94+4, trovato: $rideLabels',
    );
    var transferWalk = 0.0;
    for (final l in it.legs) {
      if (l.kind == PercorsoLegKind.walk &&
          l.title.contains('Cambio') &&
          l.from != null &&
          l.to != null) {
        transferWalk = percorsoWalkEstimate(l.from!, l.to!).meters;
      }
    }
    expect(transferWalk, lessThan(2000), reason: 'cambio ${transferWalk}m');
  }, timeout: const Timeout(Duration(seconds: 45)));
}

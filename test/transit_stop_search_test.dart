import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:RomagnaGO/photon_romagna.dart';
import 'package:RomagnaGO/transit_stops.dart';

TransitStopPin _pin({required String id, required String name}) {
  return TransitStopPin(
    stopId: id,
    stopName: name,
    point: const LatLng(44.0, 12.0),
  );
}

void main() {
  final pins = [
    _pin(id: 'TRC026', name: 'Fiabilandia'),
    _pin(id: 'TRC012', name: 'Kennedy (Metromare)'),
    _pin(id: '401-402', name: 'Kennedy (Forlì)'),
    _pin(id: '10832', name: 'Cesenatico (V.Le Trento)'),
  ];

  test('tokenizza query combinate', () {
    expect(transitStopSearchTokens('Fiabilandia TRC026'), ['fiabilandia', 'trc026']);
    expect(transitStopSearchTokens('Kennedy TRC'), ['kennedy', 'trc']);
    expect(transitStopSearchTokens('TRC026'), ['trc026']);
    expect(transitStopSearchTokens('fermata Fiabilandia'), ['fiabilandia']);
  });

  test('nome + ID insieme disambiguano omonimi', () {
    final kennedyTrc = filterAndRankTransitStops(pins, 'Kennedy TRC');
    expect(kennedyTrc, isNotEmpty);
    expect(kennedyTrc.first.stopId, 'TRC012');

    final kennedyForli = filterAndRankTransitStops(pins, 'Kennedy 401');
    expect(kennedyForli, isNotEmpty);
    expect(kennedyForli.first.stopId, '401-402');
  });

  test('ricerca per nome o solo ID', () {
    final byName = filterAndRankTransitStops(pins, 'Fiabilandia');
    expect(byName.first.stopId, 'TRC026');

    final byId = filterAndRankTransitStops(pins, 'TRC026');
    expect(byId.first.stopId, 'TRC026');
  });

  test('nome e ID entrambi richiesti se presenti in query', () {
    final both = filterAndRankTransitStops(pins, 'Fiabilandia TRC026');
    expect(both, hasLength(1));
    expect(both.first.stopId, 'TRC026');

    final wrong = filterAndRankTransitStops(pins, 'Fiabilandia TRC012');
    expect(wrong, isEmpty);
  });

  test('parola chiave Metromare limita a ID TRC', () {
    final parsed = parseTransitStopSearchQuery('  Kennedy   METROMARE  ');
    expect(parsed.metromareOnly, isTrue);
    expect(parsed.matchTokens, ['kennedy']);

    final hits = filterAndRankTransitStops(pins, 'Kennedy Metromare');
    expect(hits, hasLength(1));
    expect(hits.first.stopId, 'TRC012');

    final noForli = filterAndRankTransitStops(pins, 'Kennedy Metromare');
    expect(noForli.any((p) => p.stopId == '401-402'), isFalse);
  });

  test('parola chiave traghetto limita ai traghetti RA', () {
    final ferries = [
      FerryStopPin(
        stopName: 'Marina di Ravenna',
        comune: 'Ravenna',
        provincia: 'RA',
        point: const LatLng(44.49, 12.28),
      ),
      FerryStopPin(
        stopName: 'Porto Corsini',
        comune: 'Ravenna',
        provincia: 'RA',
        point: const LatLng(44.50, 12.30),
      ),
    ];

    final marina = busStopHitsForMapSearch(
      'Marina di Ravenna traghetto',
      const [],
      ferryStops: ferries,
    );
    expect(marina, hasLength(1));
    expect(marina.first.isFerryStop, isTrue);
    expect(marina.first.transitStopName, 'Marina di Ravenna');

    final porto = busStopHitsForMapSearch(
      'Porto Corsini TRAGHETTO',
      const [],
      ferryStops: ferries,
    );
    expect(porto, hasLength(1));
    expect(porto.first.transitStopName, 'Porto Corsini');

    final busExcluded = busStopHitsForMapSearch(
      'Kennedy traghetto',
      pins,
      ferryStops: ferries,
    );
    expect(busExcluded.every((h) => h.isFerryStop), isTrue);
  });
}

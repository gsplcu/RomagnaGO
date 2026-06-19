import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'quick_address_nearby_stops.dart';
import 'transit_stops.dart';

/// Categoria POI per icona/colore in autocomplete (da tag OSM Photon).
enum RomagnaSearchPoiCategory {
  beach,
  iceCream,
  cafeBar,
  restaurant,
  foodOther,
  monument,
  shop,
  genericPoi,
  street,
  cityOrTown,
  villageOrHamlet,
  addressBuilding,
  other,
}

/// Tipo di luogo per iconografia nella lista risultati (Photon / fermata).
enum RomagnaSearchPlaceKind {
  busStop,
  street,
  cityOrTown,
  villageOrHamlet,
  placeOfInterest,
  addressBuilding,
  other,
}

/// Risultato geocoding (mappa / ricerca). [isBusStop] per risultati fermata TPL.
///
/// Provider: **Photon** (Komoot, dati OSM, gratuito senza API key).
class RomagnaAddressHit {
  const RomagnaAddressHit({
    required this.label,
    required this.point,
    this.isSearchMessage = false,
    this.isBusStop = false,
    this.isFerryStop = false,
    this.isMetromareStop = false,
    this.placeKind = RomagnaSearchPlaceKind.other,
    this.poiCategory = RomagnaSearchPoiCategory.other,
    this.transitStopCode,
    this.transitStopName,
    this.transitStopClusterIds = const [],
  });

  final String label;
  final LatLng point;
  final bool isSearchMessage;
  final bool isBusStop;
  final bool isFerryStop;
  final bool isMetromareStop;
  final RomagnaSearchPlaceKind placeKind;
  final RomagnaSearchPoiCategory poiCategory;

  /// Codice fermata TPL (solo hit da [busStopHitsForMapSearch]).
  final String? transitStopCode;

  /// Nome fermata senza suffissi (per UI accanto a [transitStopCode]).
  final String? transitStopName;

  /// Piattaforma gemella (es. stop_id 10821+10822 accorpati in ricerca Percorso).
  final List<String> transitStopClusterIds;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'label': label,
    'lat': point.latitude,
    'lon': point.longitude,
    'isSearchMessage': isSearchMessage,
    'isBusStop': isBusStop,
    'isFerryStop': isFerryStop,
    'isMetromareStop': isMetromareStop,
    'placeKind': placeKind.index,
    'poiCategory': poiCategory.index,
    if (transitStopCode != null) 'transitStopCode': transitStopCode,
    if (transitStopName != null) 'transitStopName': transitStopName,
    if (transitStopClusterIds.isNotEmpty)
      'transitStopClusterIds': transitStopClusterIds,
  };

  factory RomagnaAddressHit.fromJson(Map<String, dynamic> m) {
    final pk = (m['placeKind'] as int?) ?? 0;
    final kinds = RomagnaSearchPlaceKind.values;
    final kind =
        pk < 0 || pk >= kinds.length ? RomagnaSearchPlaceKind.other : kinds[pk];
    final pc = (m['poiCategory'] as int?) ?? 0;
    final poiCats = RomagnaSearchPoiCategory.values;
    final poi =
        pc < 0 || pc >= poiCats.length
            ? RomagnaSearchPoiCategory.other
            : poiCats[pc];
    return RomagnaAddressHit(
      label: m['label'] as String? ?? '',
      point: LatLng(
        (m['lat'] as num?)?.toDouble() ?? 0,
        (m['lon'] as num?)?.toDouble() ?? 0,
      ),
      isSearchMessage: m['isSearchMessage'] as bool? ?? false,
      isBusStop: m['isBusStop'] as bool? ?? false,
      isFerryStop: m['isFerryStop'] as bool? ?? false,
      isMetromareStop: m['isMetromareStop'] as bool? ?? false,
      placeKind: kind,
      poiCategory: poi,
      transitStopCode: m['transitStopCode'] as String?,
      transitStopName: m['transitStopName'] as String?,
      transitStopClusterIds:
          (m['transitStopClusterIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  RomagnaAddressHit copyWith({
    String? label,
    LatLng? point,
    bool? isSearchMessage,
    bool? isBusStop,
    bool? isFerryStop,
    bool? isMetromareStop,
    RomagnaSearchPlaceKind? placeKind,
    RomagnaSearchPoiCategory? poiCategory,
    String? transitStopCode,
    String? transitStopName,
    List<String>? transitStopClusterIds,
    bool clearTransitStopCode = false,
    bool clearTransitStopName = false,
    bool clearTransitStopClusterIds = false,
  }) {
    return RomagnaAddressHit(
      label: label ?? this.label,
      point: point ?? this.point,
      isSearchMessage: isSearchMessage ?? this.isSearchMessage,
      isBusStop: isBusStop ?? this.isBusStop,
      isFerryStop: isFerryStop ?? this.isFerryStop,
      isMetromareStop: isMetromareStop ?? this.isMetromareStop,
      placeKind: placeKind ?? this.placeKind,
      poiCategory: poiCategory ?? this.poiCategory,
      transitStopCode:
          clearTransitStopCode
              ? null
              : (transitStopCode ?? this.transitStopCode),
      transitStopName:
          clearTransitStopName
              ? null
              : (transitStopName ?? this.transitStopName),
      transitStopClusterIds:
          clearTransitStopClusterIds
              ? const []
              : (transitStopClusterIds ?? this.transitStopClusterIds),
    );
  }
}

const RomagnaAddressHit kRomagnaNoSearchResultHit = RomagnaAddressHit(
  label: 'Nessun risultato, prova a modificare la ricerca',
  point: LatLng(44.22, 12.24),
  isSearchMessage: true,
  placeKind: RomagnaSearchPlaceKind.other,
);

/// Testo compatto per barra di ricerca / Casa-Lavoro (include codice fermata se noto).
String romagnaHitDisplayLine(RomagnaAddressHit hit) {
  final c = hit.transitStopCode;
  final n = hit.transitStopName;
  if (hit.isBusStop && n != null && n.isNotEmpty) {
    final nameUi = transitStopNameForDisplay(n);
    if (hit.isFerryStop) return '$nameUi · traghetto';
    if (hit.isMetromareStop) return '$nameUi · metromare';
    if (c != null && c.isNotEmpty) {
      return '$c · $nameUi';
    }
    return '$nameUi · fermata';
  }
  return hit.label;
}

/// Bbox Photon Romagna: `minLon,minLat,maxLon,maxLat`.
const String kRomagnaPhotonBbox = '11.90,43.90,12.70,44.50';

/// Centro Romagna per priorità locale nelle query Photon.
const String kRomagnaPhotonCenterLat = '44.20';
const String kRomagnaPhotonCenterLon = '12.39';

/// Photon blocca richieste senza User-Agent (403). Obbligatorio su mobile/desktop.
const Map<String, String> kPhotonHttpHeaders = <String, String>{
  'User-Agent': 'RomagnaGO/1.0 (Flutter; address-search)',
  'Accept': 'application/json',
};

/// Debounce minimo consigliato per barre di ricerca (ms).
const int kRomagnaSearchDebounceMs = 300;

/// Prefissi toponomastici (ordine: più lunghi prima) per normalizzare Via/Viale/…
const List<String> _kRomagnaStreetPrefixes = <String>[
  'località ',
  'localita ',
  'p.zza. ',
  'p.zza ',
  'p.za ',
  'v.le. ',
  'v.le ',
  'c.so. ',
  'c.so ',
  'corso ',
  'viale ',
  'strada ',
  'piazza ',
  'vicolo ',
  'largo ',
  'via ',
];

/// Pulisce l’input per fallback di ricerca: minuscolo, rimuove prefissi strada,
/// spazi ripetuti e trim.
String romagnaSearchPreprocessInput(String input) {
  var s = input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  while (s.isNotEmpty) {
    var stripped = false;
    for (final p in _kRomagnaStreetPrefixes) {
      if (s.startsWith(p)) {
        s = s.substring(p.length).trimLeft();
        stripped = true;
        break;
      }
    }
    if (!stripped) break;
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Seconda query se la prima non dà risultati: toglie numero civico finale e token solo numerici.
String romagnaSearchKeywordFallbackQuery(String cleaned) {
  var s = cleaned.trim();
  s = s.replaceAll(RegExp(r'\s+\d{1,6}[a-z]?\s*$', caseSensitive: false), '').trim();
  final parts =
      s
          .split(RegExp(r'\s+'))
          .where((w) {
            if (w.isEmpty) return false;
            if (RegExp(r'^[\d./-]+$').hasMatch(w)) return false;
            return true;
          })
          .join(' ')
          .trim();
  return parts.replaceAll(RegExp(r'\s+'), ' ').trim();
}

RomagnaSearchPoiCategory romagnaPoiCategoryFromOsm({
  String? osmKey,
  String? osmValue,
  String label = '',
}) {
  final k = (osmKey ?? '').toLowerCase();
  final v = (osmValue ?? '').toLowerCase();
  final l = label.toLowerCase();

  if (k == 'highway') return RomagnaSearchPoiCategory.street;
  if (k == 'place') {
    if (v == 'city' || v == 'town' || v == 'municipality') {
      return RomagnaSearchPoiCategory.cityOrTown;
    }
    if (v == 'village' ||
        v == 'hamlet' ||
        v == 'suburb' ||
        v == 'neighbourhood' ||
        v == 'locality') {
      return RomagnaSearchPoiCategory.villageOrHamlet;
    }
  }
  if (k == 'building' || k == 'addr') {
    return RomagnaSearchPoiCategory.addressBuilding;
  }

  const beachValues = {
    'beach_resort',
    'beach',
    'bathers',
    'summer_camp',
  };
  if (k == 'leisure' && beachValues.contains(v)) {
    return RomagnaSearchPoiCategory.beach;
  }
  if (k == 'natural' && v == 'beach') return RomagnaSearchPoiCategory.beach;
  if (k == 'tourism' &&
      (v == 'beach_resort' ||
          (v == 'hotel' && l.contains('stabilimento')))) {
    return RomagnaSearchPoiCategory.beach;
  }
  if (l.contains('stabilimento') ||
      l.contains('bagno ') ||
      l.contains('bagni ') ||
      l.contains('lido ')) {
    return RomagnaSearchPoiCategory.beach;
  }

  if (v == 'ice_cream' || l.contains('gelater') || l.contains('gelato')) {
    return RomagnaSearchPoiCategory.iceCream;
  }
  if (v == 'cafe' ||
      v == 'bar' ||
      v == 'pub' ||
      v == 'biergarten' ||
      l.contains(' bar ') ||
      l.startsWith('bar ')) {
    return RomagnaSearchPoiCategory.cafeBar;
  }
  if (v == 'restaurant' ||
      v == 'fast_food' ||
      v == 'food_court' ||
      l.contains('ristorant') ||
      l.contains('trattoria') ||
      l.contains('osteria') ||
      l.contains('pizzer')) {
    return RomagnaSearchPoiCategory.restaurant;
  }
  const foodAmenities = {
    'bakery',
    'biergarten',
    'canteen',
    'food_court',
    'ice_cream',
  };
  if (k == 'amenity' && foodAmenities.contains(v)) {
    return v == 'ice_cream'
        ? RomagnaSearchPoiCategory.iceCream
        : RomagnaSearchPoiCategory.foodOther;
  }
  if (k == 'shop' &&
      (v == 'bakery' || v == 'confectionery' || v == 'pastry')) {
    return RomagnaSearchPoiCategory.foodOther;
  }

  if (k == 'historic' ||
      v == 'monument' ||
      v == 'memorial' ||
      v == 'castle' ||
      v == 'archaeological_site') {
    return RomagnaSearchPoiCategory.monument;
  }
  if (k == 'tourism' &&
      (v == 'museum' ||
          v == 'gallery' ||
          v == 'attraction' ||
          v == 'viewpoint' ||
          v == 'artwork')) {
    return RomagnaSearchPoiCategory.monument;
  }
  if (k == 'shop') return RomagnaSearchPoiCategory.shop;
  if (k == 'amenity' ||
      k == 'tourism' ||
      k == 'leisure' ||
      k == 'railway' ||
      k == 'public_transport') {
    return RomagnaSearchPoiCategory.genericPoi;
  }
  return RomagnaSearchPoiCategory.other;
}

RomagnaSearchPlaceKind _placeKindFromPhotonOsm(String? osmKey, String? osmValue) {
  final k = (osmKey ?? '').toLowerCase();
  final v = (osmValue ?? '').toLowerCase();
  if (k == 'highway') return RomagnaSearchPlaceKind.street;
  if (k == 'place') {
    if (v == 'city' || v == 'town' || v == 'municipality') {
      return RomagnaSearchPlaceKind.cityOrTown;
    }
    if (v == 'village' ||
        v == 'hamlet' ||
        v == 'suburb' ||
        v == 'neighbourhood' ||
        v == 'locality') {
      return RomagnaSearchPlaceKind.villageOrHamlet;
    }
  }
  if (k == 'building' || k == 'addr') {
    return RomagnaSearchPlaceKind.addressBuilding;
  }
  if (k == 'amenity' ||
      k == 'shop' ||
      k == 'tourism' ||
      k == 'historic' ||
      k == 'leisure' ||
      k == 'railway' ||
      k == 'public_transport') {
    return RomagnaSearchPlaceKind.placeOfInterest;
  }
  return RomagnaSearchPlaceKind.other;
}

const LatLng kRomagnaSearchFallbackOrigin = LatLng(44.22, 12.24);
const double kRomagnaDistanceFallbackKm = 120;

/// Confini operativi RomagnaGO (FC / RA / RN): esclude Bologna, Milano, estero, ecc.
bool isWithinRomagnaBounds(LatLng p) {
  return p.latitude >= 43.62 &&
      p.latitude <= 44.48 &&
      p.longitude >= 11.70 &&
      p.longitude <= 12.75;
}

List<RomagnaAddressHit> _onlyRomagnaHits(List<RomagnaAddressHit> hits) {
  if (hits.isEmpty) return hits;
  return hits
      .where((h) => isWithinRomagnaBounds(h.point))
      .toList(growable: false);
}

String _photonPropString(Map<String, dynamic> props, String key) {
  final v = props[key];
  return v is String ? v.trim() : '';
}

String? _photonCityFromProps(Map<String, dynamic> props) {
  final city = _photonPropString(props, 'city');
  if (city.isNotEmpty) return city;
  for (final key in ['town', 'village', 'municipality', 'county']) {
    final v = _photonPropString(props, key);
    if (v.isNotEmpty) return v;
  }
  return null;
}

String _photonLabelFromProps(Map<String, dynamic> props, {String fallback = ''}) {
  final name = _photonPropString(props, 'name');
  final street = _photonPropString(props, 'street');
  final housenumber = _photonPropString(props, 'housenumber');
  final city = _photonCityFromProps(props) ?? '';
  final state = _photonPropString(props, 'state');

  final title =
      name.isNotEmpty
          ? name
          : (street.isNotEmpty
              ? (housenumber.isNotEmpty ? '$street $housenumber' : street)
              : '');

  final parts = <String>[
    if (title.isNotEmpty) title,
    if (city.isNotEmpty) city,
    if (state.isNotEmpty) state,
    'Italia',
  ];
  final label = parts.where((e) => e.isNotEmpty).join(', ');
  if (label.isNotEmpty) return label;
  return fallback;
}

RomagnaAddressHit? _hitFromPhotonFeature(
  Map<String, dynamic> feature, {
  required String fallbackLabel,
}) {
  final geom = feature['geometry'];
  if (geom is! Map) return null;
  final coords = geom['coordinates'];
  if (coords is! List || coords.length < 2) return null;
  final lon = (coords[0] as num?)?.toDouble();
  final lat = (coords[1] as num?)?.toDouble();
  if (lon == null || lat == null) return null;
  if (!lat.isFinite || !lon.isFinite) return null;
  if (lat.abs() > 90 || lon.abs() > 180) return null;
  final pt = LatLng(lat, lon);
  if (!isWithinRomagnaBounds(pt)) return null;

  final props = feature['properties'];
  if (props is! Map) return null;
  final propsMap = Map<String, dynamic>.from(props);

  final label = _photonLabelFromProps(propsMap, fallback: fallbackLabel);
  final osmKey = propsMap['osm_key'] as String?;
  final osmValue = propsMap['osm_value'] as String?;
  final kind = _placeKindFromPhotonOsm(osmKey, osmValue);
  final poi = romagnaPoiCategoryFromOsm(
    osmKey: osmKey,
    osmValue: osmValue,
    label: label,
  );

  return RomagnaAddressHit(
    label: label,
    point: pt,
    isBusStop: false,
    placeKind: kind,
    poiCategory: poi,
  );
}

List<RomagnaAddressHit> _parsePhotonFeatureCollection(
  Object? decoded, {
  required String fallbackLabel,
}) {
  if (decoded is! Map<String, dynamic>) return const [];
  final features = decoded['features'];
  if (features is! List) return const [];

  final out = <RomagnaAddressHit>[];
  for (final f in features) {
    if (f is! Map<String, dynamic>) continue;
    final hit = _hitFromPhotonFeature(f, fallbackLabel: fallbackLabel);
    if (hit != null) out.add(hit);
  }
  return out;
}

Uri _photonSearchUri(String query) {
  // Photon pubblico non accetta lang=it (solo default/de/en/fr); i tag OSM in
  // Romagna restano in italiano senza parametro lingua.
  return Uri.https('photon.komoot.io', '/api/', <String, String>{
    'q': query.trim(),
    'lat': kRomagnaPhotonCenterLat,
    'lon': kRomagnaPhotonCenterLon,
    'bbox': kRomagnaPhotonBbox,
    'limit': '12',
  });
}

String _cityKeyFromLabel(String label) {
  final parts = label
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (parts.length >= 2) return parts[1];
  if (parts.isNotEmpty) return parts.first;
  return '';
}

/// Photon (Komoot, OSM): geocoding in bbox Romagna con priorità locale.
Future<List<RomagnaAddressHit>> _photonSearchRomagna(
  String rawQuery, {
  LatLng? priorityOrigin,
}) async {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];

  try {
    final response = await http.get(
      _photonSearchUri(q),
      headers: kPhotonHttpHeaders,
    );
    if (response.statusCode != 200) return const [];

    final out = _parsePhotonFeatureCollection(
      jsonDecode(response.body),
      fallbackLabel: q,
    );
    if (out.length <= 1) return out;

    final origin = _resolveSearchOrigin(priorityOrigin, out);
    final distance = const Distance();
    final nearest = out.reduce((a, b) {
      final da = distance.as(LengthUnit.Kilometer, origin, a.point);
      final db = distance.as(LengthUnit.Kilometer, origin, b.point);
      return da <= db ? a : b;
    });
    final nearestCityKey = _cityKeyFromLabel(nearest.label);
    out.sort((a, b) {
      if (nearestCityKey.isNotEmpty) {
        final aSameCity = _cityKeyFromLabel(a.label) == nearestCityKey;
        final bSameCity = _cityKeyFromLabel(b.label) == nearestCityKey;
        if (aSameCity != bSameCity) return aSameCity ? -1 : 1;
      }
      final da = distance.as(LengthUnit.Kilometer, origin, a.point);
      final db = distance.as(LengthUnit.Kilometer, origin, b.point);
      return da.compareTo(db);
    });
    return out;
  } catch (_) {
    return const [];
  }
}

List<RomagnaAddressHit> _dropHitsNearStops(
  List<RomagnaAddressHit> remote,
  List<RomagnaAddressHit> stopHits, {
  double meters = 52,
}) {
  if (stopHits.isEmpty || remote.isEmpty) return remote;
  final distance = const Distance();
  return remote
      .where(
        (h) => !stopHits.any(
          (s) => distance.as(LengthUnit.Meter, s.point, h.point) < meters,
        ),
      )
      .toList(growable: false);
}

List<RomagnaAddressHit> _mergeAddressAndStopResults({
  required List<RomagnaAddressHit> addressHits,
  required List<RomagnaAddressHit> stopHits,
  int maxTotal = 6,
  int maxAddressHits = 4,
  int maxStopHitsWhenAddressFound = 2,
}) {
  if (addressHits.isEmpty && stopHits.isEmpty) {
    return const [kRomagnaNoSearchResultHit];
  }
  if (addressHits.isEmpty) {
    return stopHits.take(maxTotal).toList(growable: false);
  }
  final merged = <RomagnaAddressHit>[
    ...addressHits.take(maxAddressHits),
    ...stopHits.take(maxStopHitsWhenAddressFound),
  ];
  return merged.take(maxTotal).toList(growable: false);
}

List<TransitStopPin> _sortPinsByDistanceIfNeeded(
  List<TransitStopPin> pins,
  LatLng? origin,
  bool enabled,
) {
  if (!enabled || origin == null || pins.length < 2) return pins;
  final distance = const Distance();
  final scored = pins
      .map(
        (p) => (
          pin: p,
          m: distance.as(LengthUnit.Meter, origin, p.point),
        ),
      )
      .toList(growable: false);
  scored.sort((a, b) => a.m.compareTo(b.m));
  return scored.map((e) => e.pin).toList(growable: false);
}

/// Solo fermate (per query 2…minChars-1 caratteri nella barra mappa).
List<RomagnaAddressHit> busStopHitsForMapSearch(
  String rawQuery,
  List<TransitStopPin> transitStops, {
  List<FerryStopPin> ferryStops = const [],
  LatLng? priorityOrigin,
  bool sortStopsByDistance = false,
}) {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];
  final parsed = parseTransitStopSearchQuery(q);

  var rankedPins = filterAndRankTransitStops(transitStops, q);
  rankedPins = _sortPinsByDistanceIfNeeded(
    rankedPins,
    priorityOrigin,
    sortStopsByDistance,
  );
  final busHits =
      parsed.traghettoOnly
          ? const <RomagnaAddressHit>[]
          : rankedPins
              .take(18)
              .map(
                (p) => RomagnaAddressHit(
                  label: '${transitStopNameForDisplay(p.stopName)} · fermata',
                  point: p.point,
                  isBusStop: true,
                  isMetromareStop: p.stopId.trim().toUpperCase().startsWith(
                    'TRC',
                  ),
                  placeKind: RomagnaSearchPlaceKind.busStop,
                  transitStopCode: p.stopId.isEmpty ? null : p.stopId,
                  transitStopName: p.stopName,
                ),
              )
              .toList(growable: false);

  final ferryHits =
      parsed.metromareOnly
          ? const <RomagnaAddressHit>[]
          : ferryStops
              .where((f) {
                if (!parsed.traghettoOnly) return false;
                final hay =
                    '${f.stopName.toLowerCase()} ${f.comune.toLowerCase()}';
                if (parsed.matchTokens.isEmpty) return true;
                return parsed.matchTokens.every((t) => hay.contains(t));
              })
              .map(
                (f) => RomagnaAddressHit(
                  label:
                      '${transitStopNameForDisplay(f.stopName)} · traghetto',
                  point: f.point,
                  isBusStop: true,
                  isFerryStop: true,
                  placeKind: RomagnaSearchPlaceKind.busStop,
                  transitStopName: f.stopName,
                ),
              )
              .toList(growable: false);

  return [...ferryHits, ...busHits].take(18).toList(growable: false);
}

/// Fermate TPL per tab Percorso: un risultato per nome/piattaforma (no duplicati).
List<RomagnaAddressHit> busStopHitsForPercorsoSearch(
  String rawQuery,
  List<TransitStopPin> transitStops, {
  LatLng? priorityOrigin,
  int maxMergedStops = 6,
}) {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];
  var ranked = filterAndRankTransitStops(transitStops, q);
  ranked = _sortPinsByDistanceIfNeeded(
    ranked,
    priorityOrigin,
    priorityOrigin != null,
  );
  final groups = mergedStopGroupsFromRanked(
    ranked,
    origin: priorityOrigin,
    maxGroups: maxMergedStops,
  );
  return groups
      .map(
        (g) => RomagnaAddressHit(
          label: '${transitStopNameForDisplay(g.rep.stopName)} · fermata',
          point: g.rep.point,
          isBusStop: true,
          isMetromareStop: g.rep.stopId.trim().toUpperCase().startsWith('TRC'),
          placeKind: RomagnaSearchPlaceKind.busStop,
          transitStopCode: g.rep.stopId,
          transitStopName: g.rep.stopName,
          transitStopClusterIds: g.stopIds,
        ),
      )
      .toList(growable: false);
}

/// Barra ricerca mappa: al massimo 3 fermate + 2 luoghi da geocoder (default).
const int kMapSearchBarMaxTransitStops = 6;
const int kMapSearchBarMaxRemotePlaces = 2;

/// Ricerca mappa: fermate in cima (max [maxTransitStops]), poi indirizzi/toponimi
/// Photon (max [maxRemotePlaces], lontani dalle fermate duplicate).
Future<List<RomagnaAddressHit>> searchRomagnaMapWithTransit(
  String rawQuery, {
  required List<TransitStopPin> transitStops,
  List<FerryStopPin> ferryStops = const [],
  LatLng? priorityOrigin,
  int minCharsRemote = 3,
  int maxTransitStops = kMapSearchBarMaxTransitStops,
  int maxRemotePlaces = kMapSearchBarMaxRemotePlaces,
  bool sortStopsByDistance = false,
}) async {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];
  final allStopHits = busStopHitsForMapSearch(
    q,
    transitStops,
    ferryStops: ferryStops,
    priorityOrigin: priorityOrigin,
    sortStopsByDistance: sortStopsByDistance,
  );
  final stopLimit = maxTransitStops.clamp(1, 6);
  final stopHits = allStopHits.take(stopLimit).toList(growable: false);
  if (q.length < minCharsRemote) {
    return stopHits.isEmpty ? const [kRomagnaNoSearchResultHit] : stopHits;
  }

  final remote = _onlyRomagnaHits(
    await searchRomagnaAddresses(q, priorityOrigin: priorityOrigin),
  );
  final trimmed = _dropHitsNearStops(remote, allStopHits);
  final placeHits = trimmed
      .where((h) => !h.isBusStop)
      .take(maxRemotePlaces)
      .toList(growable: false);
  return _mergeAddressAndStopResults(
    addressHits: placeHits,
    stopHits: stopHits,
  );
}

/// Ricerca punti A/B tab Percorso: fermate accorpate (max [maxMergedStops]),
/// poi indirizzi generici (max [maxRemotePlaces]).
Future<List<RomagnaAddressHit>> searchRomagnaPercorso(
  String rawQuery, {
  required List<TransitStopPin> transitStops,
  List<FerryStopPin> ferryStops = const [],
  LatLng? priorityOrigin,
  int minCharsRemote = 3,
  int maxMergedStops = 6,
  int maxRemotePlaces = 10,
}) async {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];
  final stopHits = busStopHitsForPercorsoSearch(
    q,
    transitStops,
    priorityOrigin: priorityOrigin,
    maxMergedStops: maxMergedStops,
  );
  if (q.length < minCharsRemote) {
    return stopHits.isEmpty ? const [kRomagnaNoSearchResultHit] : stopHits;
  }

  final remote = _onlyRomagnaHits(
    await searchRomagnaAddresses(q, priorityOrigin: priorityOrigin),
  );
  final trimmed = _dropHitsNearStops(remote, stopHits);
  final placeHits = trimmed
      .where((h) => !h.isBusStop)
      .take(maxRemotePlaces)
      .toList(growable: false);
  return _mergeAddressAndStopResults(
    addressHits: placeHits,
    stopHits: stopHits,
  );
}

bool _looksLikeTransitStopQuery(String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return false;
  if (q.startsWith('fermata ')) return true;
  if (RegExp(r'^(stop|id)\s*[:#-]?\s*\d{3,}$').hasMatch(q)) return true;
  if (RegExp(r'^\d{4,}$').hasMatch(q)) return true;
  return false;
}

/// Ricerca dedicata alla selezione "Indirizzi rapidi":
/// - prioritizza gli indirizzi/toponimi;
/// - mantiene supporto fermate per nome/stop_id;
/// - se la query sembra una fermata, inverte la priorità.
Future<List<RomagnaAddressHit>> searchRomagnaQuickAddresses(
  String rawQuery, {
  required List<TransitStopPin> transitStops,
  List<FerryStopPin> ferryStops = const [],
  LatLng? priorityOrigin,
  int minCharsRemote = 3,
  int maxTransitStops = 10,
  int maxRemotePlaces = 18,
}) async {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];

  final allStopHits = busStopHitsForMapSearch(
    q,
    transitStops,
    ferryStops: ferryStops,
  );
  final stopHits =
      allStopHits.take(maxTransitStops).toList(growable: false);

  List<RomagnaAddressHit> placeHits = const [];
  if (q.length >= minCharsRemote) {
    final remote = _onlyRomagnaHits(
      await searchRomagnaAddresses(q, priorityOrigin: priorityOrigin),
    );
    final trimmed = _dropHitsNearStops(remote, allStopHits);
    placeHits = trimmed
        .where((h) => !h.isBusStop)
        .take(maxRemotePlaces)
        .toList(growable: false);
  }

  if (_looksLikeTransitStopQuery(q)) return [...stopHits, ...placeHits];
  return [...placeHits, ...stopHits];
}

RomagnaAddressHit _pickBestManualHit(
  List<RomagnaAddressHit> hits, {
  required String via,
  required String civico,
  required String comune,
}) {
  if (hits.length == 1) return hits.first;
  final city = comune.trim().toLowerCase();
  final civ = civico.trim().toLowerCase();
  final viaL = via.trim().toLowerCase();
  final tokens =
      viaL
          .split(RegExp(r'\s+'))
          .where((t) => t.length > 2)
          .toList(growable: false);

  var best = hits.first;
  var bestScore = -1;
  for (final h in hits) {
    final l = h.label.toLowerCase();
    var s = 0;
    if (city.isNotEmpty && l.contains(city)) s += 5;
    if (civ.isNotEmpty && l.contains(civ)) s += 3;
    for (final t in tokens) {
      if (l.contains(t)) s += 2;
    }
    if (viaL.isNotEmpty && l.contains(viaL)) s += 4;
    if (s > bestScore) {
      bestScore = s;
      best = h;
    }
  }
  return best;
}

/// Cerca indirizzi e toponimi tramite Photon: testo utente, bbox Romagna,
/// fallback su input normalizzato e parole chiave se la prima query è vuota.
Future<List<RomagnaAddressHit>> searchRomagnaAddresses(
  String rawQuery, {
  LatLng? priorityOrigin,
}) async {
  final q = rawQuery.trim();
  if (q.length < 2) return const [];

  var hits = await _photonSearchRomagna(q, priorityOrigin: priorityOrigin);

  if (hits.isEmpty) {
    final cleaned = romagnaSearchPreprocessInput(rawQuery);
    if (cleaned.length >= 2 && cleaned != q) {
      hits = await _photonSearchRomagna(cleaned, priorityOrigin: priorityOrigin);
    }
  }

  if (hits.isEmpty) {
    final base = romagnaSearchPreprocessInput(rawQuery);
    final fb = romagnaSearchKeywordFallbackQuery(base.isNotEmpty ? base : q);
    if (fb.length >= 2 && fb != q) {
      hits = await _photonSearchRomagna(fb, priorityOrigin: priorityOrigin);
    }
  }

  return _onlyRomagnaHits(hits);
}

/// Geocodifica da campi manuali (via, civico, comune) con Photon e scelta del
/// risultato più coerente con via/comune.
Future<RomagnaAddressHit?> geocodeManualRomagnaAddress({
  required String viaPiazza,
  required String numeroCivico,
  String? interno,
  required String cap,
  required String comune,
  String? siglaProvincia,
  LatLng? priorityOrigin,
}) async {
  final v = viaPiazza.trim();
  final civ = numeroCivico.trim();
  final c = comune.trim();
  final zip = cap.trim();
  final intl = interno?.trim();
  final prov = siglaProvincia?.trim().toUpperCase();

  if (v.isEmpty || civ.isEmpty || c.isEmpty) return null;

  final streetLine =
      '$v $civ${intl != null && intl.isNotEmpty ? ', int. $intl' : ''}';
  final qFull = [
    streetLine,
    if (zip.isNotEmpty) zip,
    c,
    if (prov != null && prov.isNotEmpty) prov,
    'Italia',
  ].join(', ');

  final queries = <String>[
    qFull,
    [streetLine, c, 'Italia'].join(', '),
    '$v $civ, $c',
    '$c, Emilia-Romagna, Italia',
  ];

  for (final query in queries) {
    final list = _onlyRomagnaHits(
      await _photonSearchRomagna(query, priorityOrigin: priorityOrigin),
    );
    if (list.isEmpty) continue;
    if (query == queries.last) {
      return RomagnaAddressHit(
        label: '$c (centro comune — verifica sulla mappa)',
        point: list.first.point,
        isBusStop: false,
        placeKind: RomagnaSearchPlaceKind.cityOrTown,
      );
    }
    return _pickBestManualHit(list, via: v, civico: civ, comune: c);
  }

  return null;
}

LatLng _resolveSearchOrigin(LatLng? userOrigin, List<RomagnaAddressHit> hits) {
  if (userOrigin == null) return kRomagnaSearchFallbackOrigin;
  if (!userOrigin.latitude.isFinite || !userOrigin.longitude.isFinite) {
    return kRomagnaSearchFallbackOrigin;
  }
  if (userOrigin.latitude.abs() > 90 || userOrigin.longitude.abs() > 180) {
    return kRomagnaSearchFallbackOrigin;
  }

  final distance = const Distance();
  final minDistanceKm = hits
      .map((h) => distance.as(LengthUnit.Kilometer, userOrigin, h.point))
      .fold<double>(double.infinity, (prev, next) => next < prev ? next : prev);

  if (minDistanceKm > kRomagnaDistanceFallbackKm) {
    return kRomagnaSearchFallbackOrigin;
  }
  return userOrigin;
}

/// Etichetta comune + sigla provincia (es. `Cesenatico (FC)`) da reverse Photon.
class RomagnaReversePlaceLabel {
  const RomagnaReversePlaceLabel({
    required this.municipality,
    required this.provinceCode,
  });

  final String municipality;
  final String provinceCode;

  String get formatted => '$municipality ($provinceCode)';
}

String? _provinceFromCounty(String county) {
  final n = county.toLowerCase();
  const pairs = <String, String>{
    'forlì-cesena': 'FC',
    'forli-cesena': 'FC',
    'rimini': 'RN',
    'ravenna': 'RA',
    'bologna': 'BO',
    'ferrara': 'FE',
    'modena': 'MO',
    'reggio nell': 'RE',
    'reggio emilia': 'RE',
    'parma': 'PR',
    'piacenza': 'PC',
    'pesaro': 'PU',
    'urbino': 'PU',
    'ancona': 'AN',
    'macerata': 'MC',
    'fermo': 'FM',
    'ascoli': 'AP',
    'perugia': 'PG',
    'terni': 'TR',
  };
  for (final e in pairs.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}

String? _provinceCodeFromPhotonProps(Map<String, dynamic> props) {
  final county = _photonPropString(props, 'county');
  if (county.isNotEmpty) {
    final fromCounty = _provinceFromCounty(county);
    if (fromCounty != null) return fromCounty;
  }
  final state = _photonPropString(props, 'state');
  if (state.isNotEmpty) {
    final fromState = _provinceFromCounty(state);
    if (fromState != null) return fromState;
  }
  return null;
}

Map<String, dynamic>? _firstPhotonFeature(Object? decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  final features = decoded['features'];
  if (features is List && features.isNotEmpty) {
    final f = features.first;
    if (f is Map<String, dynamic>) return f;
  }
  if (decoded['type'] == 'Feature' && decoded['geometry'] != null) {
    return decoded;
  }
  return null;
}

Future<Map<String, dynamic>?> _photonReverseProps(LatLng point) async {
  if (!point.latitude.isFinite || !point.longitude.isFinite) return null;
  if (point.latitude.abs() > 90 || point.longitude.abs() > 180) return null;

  final uri = Uri.https('photon.komoot.io', '/reverse', <String, String>{
    'lat': '${point.latitude}',
    'lon': '${point.longitude}',
  });

  try {
    final response = await http.get(uri, headers: kPhotonHttpHeaders);
    if (response.statusCode != 200) return null;
    final feature = _firstPhotonFeature(jsonDecode(response.body));
    if (feature == null) return null;
    final props = feature['properties'];
    return props is Map ? Map<String, dynamic>.from(props) : null;
  } catch (_) {
    return null;
  }
}

/// Reverse geocoding (Photon): comune + sigla provincia. Uso sporadico (es. tap fermata).
Future<RomagnaReversePlaceLabel?> reverseRomagnaPlace(LatLng point) async {
  final props = await _photonReverseProps(point);
  if (props == null) return null;

  final comune = _photonCityFromProps(props);
  if (comune == null || comune.isEmpty) return null;

  final prov = _provinceCodeFromPhotonProps(props) ?? '—';

  return RomagnaReversePlaceLabel(
    municipality: comune,
    provinceCode: prov,
  );
}

/// Via e numero civico da reverse Photon (senza comune/regione).
Future<String?> reverseRomagnaStreetLine(LatLng point) async {
  final props = await _photonReverseProps(point);
  if (props == null) return null;

  final street = _photonPropString(props, 'street');
  final housenumber = _photonPropString(props, 'housenumber');
  if (street.isNotEmpty) {
    return housenumber.isNotEmpty ? '$street, $housenumber' : street;
  }

  final name = _photonPropString(props, 'name');
  return name.isNotEmpty ? name : null;
}
